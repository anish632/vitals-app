import Foundation

struct HealthSnapshot {
    var heartRate: Double?
    var oxygenSaturation: Double?
    var systolic: Double?
    var diastolic: Double?
    var vo2Max: Double?
    var sleepHours: Double?
    var heartRateSource: String = "Apple Health"
    var updatedAt: Date?

    static let empty = HealthSnapshot(
        heartRate: nil,
        oxygenSaturation: nil,
        systolic: nil,
        diastolic: nil,
        vo2Max: nil,
        sleepHours: nil
    )
}
