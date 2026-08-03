import Foundation
import HealthKit

@MainActor
final class HealthKitManager: ObservableObject {
    @Published private(set) var snapshot = HealthSnapshot.empty
    @Published private(set) var isLoading = false
    @Published private(set) var isAuthorized = false
    @Published var errorMessage: String?

    private let store = HKHealthStore()

    func requestAccessAndLoad() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "Apple Health is not available on this device."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes())
            isAuthorized = true
            await loadSnapshot()
        } catch {
            errorMessage = "Vita could not access Apple Health. You can try again from Settings."
        }

        isLoading = false
    }

    func recordCameraPulse(_ bpm: Double) {
        snapshot.heartRate = bpm
        snapshot.heartRateSource = "Camera estimate"
        snapshot.updatedAt = Date()
    }

    private func readTypes() -> Set<HKObjectType> {
        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .oxygenSaturation,
            .bloodPressureSystolic,
            .bloodPressureDiastolic,
            .vo2Max
        ]

        var types = Set<HKObjectType>()
        for identifier in quantityIdentifiers {
            if let type = HKObjectType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
        }
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }
        return types
    }

    private func loadSnapshot() async {
        async let heartRate = latestQuantity(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()))
        async let oxygen = latestQuantity(.oxygenSaturation, unit: .percent())
        async let systolic = latestQuantity(.bloodPressureSystolic, unit: .millimeterOfMercury())
        async let diastolic = latestQuantity(.bloodPressureDiastolic, unit: .millimeterOfMercury())
        async let vo2Max = latestQuantity(.vo2Max, unit: HKUnit.literUnit(with: .milli).unitDivided(by: .gramUnit(with: .kilo)).unitDivided(by: .minute()))
        async let sleep = recentSleepHours()

        snapshot.heartRate = await heartRate
        snapshot.oxygenSaturation = await oxygen
        snapshot.systolic = await systolic
        snapshot.diastolic = await diastolic
        snapshot.vo2Max = await vo2Max
        snapshot.sleepHours = await sleep
        snapshot.heartRateSource = "Apple Health"
        snapshot.updatedAt = Date()
    }

    private func latestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func recentSleepHours() async -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let startDate = Calendar.current.date(byAdding: .hour, value: -36, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil)
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let totalSeconds = (samples as? [HKCategorySample] ?? [])
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: totalSeconds > 0 ? totalSeconds / 3600 : nil)
            }
            store.execute(query)
        }
    }
}
