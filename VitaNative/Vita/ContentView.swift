import SwiftUI

struct ContentView: View {
    @StateObject private var health = HealthKitManager()
    @State private var showingPulseScan = false
    @State private var selectedDetail: VitaDetail?

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    readinessCard
                    signalsSection
                    cameraCard
                    recommendations
                    disclaimer
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 36)
            }
            .background(Color.vitaPaper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task { await health.requestAccessAndLoad() }
            .sheet(isPresented: $showingPulseScan) {
                PulseScanView { bpm in
                    health.recordCameraPulse(bpm)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedDetail) { detail in
                VitaDetailView(detail: detail, snapshot: health.snapshot)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.caption2.weight(.bold))
                    .tracking(1.3)
                    .foregroundStyle(Color.vitaMuted)
                    .textCase(.uppercase)
                Text("\(greeting), Anish")
                    .font(.system(size: 35, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.vitaInk)
                Text("A little check-in can make a big difference.")
                    .font(.subheadline)
                    .foregroundStyle(Color.vitaMuted)
            }
            Spacer()
            ZStack {
                Circle().fill(Color.vitaSage.opacity(0.45))
                Text("A").font(.subheadline.weight(.bold)).foregroundStyle(Color.vitaForest)
            }
            .frame(width: 40, height: 40)
        }
    }

    private var readinessCard: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Label("TODAY'S READINESS", systemImage: "circle.fill")
                    .font(.caption2.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(Color.vitaSage)
                Text(health.snapshot.heartRate == nil ? "Build your baseline" : "Pulse captured")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                Text(health.snapshot.heartRate == nil ? "Complete a pulse check to start your personal trend." : "Keep checking at similar times to learn your pattern.")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
                Button("See insights  →") {
                    selectedDetail = .insights
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.vitaCoral)
            }
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.13), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: health.snapshot.heartRate == nil ? 0.08 : 0.72)
                    .stroke(Color.vitaPeach, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(health.snapshot.heartRate == nil ? "—" : "✓")
                        .font(.title2.weight(.semibold))
                    Text(health.snapshot.heartRate == nil ? "today" : "live")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.58))
                }
            }
            .frame(width: 98, height: 98)
        }
        .padding(24)
        .background(Color.vitaNavy)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var signalsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionTitle(eyebrow: "YOUR SIGNALS", title: "Body at a glance")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(title: "Heart rate", value: health.snapshot.heartRate.map { String(format: "%.0f", $0) } ?? "—", unit: health.snapshot.heartRate == nil ? "scan to estimate" : health.snapshot.heartRateSource == "Camera estimate" ? "estimated bpm" : "bpm", detail: health.snapshot.heartRateSource, icon: "heart.fill", color: .vitaSage) {
                    selectedDetail = .measurement(.heartRate)
                }
                MetricCard(title: "Oxygen", value: oxygenValue, unit: health.snapshot.oxygenSaturation == nil ? "validated device" : "% SpO₂", detail: "Apple Health", icon: "lungs.fill", color: .vitaLavender) {
                    selectedDetail = .measurement(.oxygen)
                }
                MetricCard(title: "Blood pressure", value: bloodPressureValue, unit: health.snapshot.systolic == nil ? "validated device" : "mmHg", detail: "Apple Health", icon: "arrow.up.arrow.down", color: .vitaBlush) {
                    selectedDetail = .measurement(.bloodPressure)
                }
                MetricCard(title: "VO₂ max", value: health.snapshot.vo2Max.map { String(format: "%.1f", $0) } ?? "—", unit: health.snapshot.vo2Max == nil ? "Apple Watch" : "mL/kg·min", detail: "Apple Health", icon: "figure.run", color: .vitaSand) {
                    selectedDetail = .measurement(.vo2Max)
                }
                MetricCard(title: "Restfulness", value: health.snapshot.sleepHours.map { String(format: "%.1f", $0) } ?? "—", unit: health.snapshot.sleepHours == nil ? "connect sleep data" : "hours asleep", detail: "Apple Health", icon: "moon.fill", color: .vitaBlueGray) {
                    selectedDetail = .measurement(.sleep)
                }
                MetricCard(title: "Energy", value: energyValue, unit: energyValue == "—" ? "needs sleep data" : "derived score", detail: "Sleep + pulse", icon: "bolt.fill", color: .vitaGold) {
                    selectedDetail = .measurement(.energy)
                }
            }
        }
    }

    private var cameraCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("60-SECOND CHECK-IN", systemImage: "camera.fill")
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(Color.vitaCoral)
            Text("See how you're doing\nright now.")
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(Color.vitaInk)
            Text("Use the rear camera and cover the lens with your fingertip. Vita will estimate your pulse from the live signal.")
                .font(.caption)
                .foregroundStyle(Color.vitaMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                showingPulseScan = true
            } label: {
                Label("Start pulse check", systemImage: "waveform.path.ecg")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(Color.vitaCoral)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.vitaBlush.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var recommendations: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(eyebrow: "JUST FOR YOU", title: "Small steps, better days")
            RecommendationRow(icon: "drop.fill", title: "Drink a glass of water", subtitle: "Hydration supports energy and focus.", color: .vitaSage) {
                selectedDetail = .recommendation(.water)
            }
            RecommendationRow(icon: "sun.max.fill", title: "Take a mindful pause", subtitle: "Try five minutes of slow breathing before bed.", color: .vitaGold) {
                selectedDetail = .recommendation(.pause)
            }
        }
    }

    private var disclaimer: some View {
        Text("Vita provides wellness insights, not medical advice. Camera pulse is an estimate. Use validated devices for blood pressure and oxygen saturation.")
            .font(.caption2)
            .foregroundStyle(Color.vitaMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    private var oxygenValue: String {
        guard let oxygen = health.snapshot.oxygenSaturation else { return "—" }
        return String(format: "%.0f", oxygen <= 1 ? oxygen * 100 : oxygen)
    }

    private var bloodPressureValue: String {
        guard let systolic = health.snapshot.systolic, let diastolic = health.snapshot.diastolic else { return "—/—" }
        return "\(String(format: "%.0f", systolic))/\(String(format: "%.0f", diastolic))"
    }

    private var energyValue: String {
        guard let sleep = health.snapshot.sleepHours else { return "—" }
        let sleepScore = min(100, max(0, Int((sleep / 8.0) * 80)))
        let pulseAdjustment: Int
        if let heartRate = health.snapshot.heartRate {
            pulseAdjustment = heartRate > 90 ? -10 : heartRate < 55 ? -4 : 8
        } else {
            pulseAdjustment = 0
        }
        return "\(min(100, max(0, sleepScore + pulseAdjustment)))"
    }

    private func sectionTitle(eyebrow: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow).font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(Color.vitaMuted)
            Text(title).font(.title3.weight(.semibold)).foregroundStyle(Color.vitaInk)
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let detail: String
    let icon: String
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Image(systemName: icon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.vitaInk.opacity(0.72))
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.58))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Spacer()
                    Text(detail)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.vitaInk.opacity(0.48))
                        .lineLimit(1)
                }
                Text(title).font(.caption).foregroundStyle(Color.vitaInk.opacity(0.62))
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value).font(.title3.weight(.semibold)).foregroundStyle(Color.vitaInk)
                    Text(unit).font(.system(size: 9)).foregroundStyle(Color.vitaInk.opacity(0.52)).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .padding(15)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct RecommendationRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .foregroundStyle(Color.vitaInk.opacity(0.68))
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.caption.weight(.semibold)).foregroundStyle(Color.vitaInk)
                    Text(subtitle).font(.caption2).foregroundStyle(Color.vitaMuted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Color.vitaMuted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.52))
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private enum VitaMetric {
    case heartRate, oxygen, bloodPressure, vo2Max, sleep, energy
}

private enum VitaRecommendation {
    case water, pause
}

private enum VitaDetail: Identifiable {
    case insights
    case measurement(VitaMetric)
    case recommendation(VitaRecommendation)

    var id: String {
        switch self {
        case .insights: return "insights"
        case .measurement(let metric): return "measurement-\(String(describing: metric))"
        case .recommendation(let recommendation): return "recommendation-\(String(describing: recommendation))"
        }
    }
}

private struct VitaDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let detail: VitaDetail
    let snapshot: HealthSnapshot

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch detail {
                    case .insights:
                        insights
                    case .measurement(let metric):
                        measurement(metric)
                    case .recommendation(let recommendation):
                        recommendationView(recommendation)
                    }
                }
                .padding(24)
            }
            .background(Color.vitaPaper.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var insights: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Today’s insights").font(.title2.weight(.semibold)).foregroundStyle(Color.vitaInk)
            insightRow(icon: "heart.fill", title: snapshot.heartRate == nil ? "Heart rate needed" : "Heart rate available", body: snapshot.heartRate == nil ? "Use the pulse check or connect a HealthKit source such as Apple Watch." : "Use the same device and resting conditions when comparing readings.")
            insightRow(icon: "moon.fill", title: snapshot.sleepHours == nil ? "Sleep data needed" : "Sleep trend available", body: snapshot.sleepHours == nil ? "Allow Vita to read Sleep in Apple Health after wearing a sleep-tracking device." : "A regular sleep schedule is a useful foundation for energy and restfulness.")
            insightRow(icon: "waveform.path.ecg", title: "Use validated devices", body: "Blood pressure and oxygen saturation should come from a cuff or validated sensor, not the iPhone camera.")
        }
    }

    @ViewBuilder
    private func measurement(_ metric: VitaMetric) -> some View {
        switch metric {
        case .heartRate:
            detailCard(title: "Heart rate", value: snapshot.heartRate.map { String(format: "%.0f bpm", $0) } ?? "Not available", body: snapshot.heartRateSource == "Camera estimate" ? "This is an optical camera estimate, not a medical measurement. For a trusted value, compare it with Apple Watch or a validated monitor." : "This value came from Apple Health.")
        case .oxygen:
            detailCard(title: "Oxygen saturation", value: snapshot.oxygenSaturation.map { String(format: "%.0f%%", $0 <= 1 ? $0 * 100 : $0) } ?? "Not available", body: "Vita reads this from Apple Health. An iPhone camera does not directly measure SpO₂.")
        case .bloodPressure:
            detailCard(title: "Blood pressure", value: bloodPressureValue, body: "Enter or sync readings from a validated upper-arm cuff through Apple Health.")
        case .vo2Max:
            detailCard(title: "VO₂ max", value: snapshot.vo2Max.map { String(format: "%.1f mL/kg·min", $0) } ?? "Not available", body: "VO₂ max is supplied by compatible Apple Health sources, commonly Apple Watch during qualifying workouts.")
        case .sleep:
            detailCard(title: "Restfulness", value: snapshot.sleepHours.map { String(format: "%.1f hours asleep", $0) } ?? "Not available", body: "Vita totals recent asleep stages recorded in Apple Health. It needs a sleep-tracking source to show a value.")
        case .energy:
            detailCard(title: "Energy", value: energyValue, body: "This is a simple wellness score derived from recent sleep and pulse data. It is not a clinical measurement.")
        }
    }

    @ViewBuilder
    private func recommendationView(_ recommendation: VitaRecommendation) -> some View {
        switch recommendation {
        case .water:
            detailCard(title: "Hydration reset", value: "1 glass", body: "Drink a glass of water now, then notice whether your energy or focus changes over the next 20–30 minutes.")
        case .pause:
            detailCard(title: "Mindful pause", value: "5 minutes", body: "Inhale gently for 4 seconds and exhale for 6 seconds. Repeat for five minutes before bed or during a stressful moment.")
        }
    }

    private var energyValue: String {
        guard let sleep = snapshot.sleepHours else { return "Not available" }
        let sleepScore = min(100, max(0, Int((sleep / 8.0) * 80)))
        let pulseAdjustment = snapshot.heartRate.map { $0 > 90 ? -10 : $0 < 55 ? -4 : 8 } ?? 0
        return "\(min(100, max(0, sleepScore + pulseAdjustment)))/100"
    }

    private var bloodPressureValue: String {
        guard let systolic = snapshot.systolic, let diastolic = snapshot.diastolic else { return "Not available" }
        return "\(String(format: "%.0f", systolic))/\(String(format: "%.0f", diastolic)) mmHg"
    }

    private func insightRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(Color.vitaCoral).frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.vitaInk)
                Text(body).font(.caption).foregroundStyle(Color.vitaMuted)
            }
        }
    }

    private func detailCard(title: String, value: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.weight(.semibold)).foregroundStyle(Color.vitaInk)
            Text(value).font(.title3.weight(.bold)).foregroundStyle(Color.vitaForest)
            Text(body).font(.subheadline).foregroundStyle(Color.vitaMuted)
        }
    }
}

extension Color {
    static let vitaPaper = Color(red: 0.96, green: 0.95, blue: 0.92)
    static let vitaInk = Color(red: 0.10, green: 0.13, blue: 0.13)
    static let vitaMuted = Color(red: 0.48, green: 0.51, blue: 0.49)
    static let vitaNavy = Color(red: 0.12, green: 0.19, blue: 0.22)
    static let vitaSage = Color(red: 0.56, green: 0.67, blue: 0.61)
    static let vitaForest = Color(red: 0.22, green: 0.32, blue: 0.28)
    static let vitaCoral = Color(red: 1.0, green: 0.39, blue: 0.31)
    static let vitaPeach = Color(red: 0.95, green: 0.70, blue: 0.62)
    static let vitaLavender = Color(red: 0.85, green: 0.82, blue: 0.91)
    static let vitaBlush = Color(red: 0.91, green: 0.79, blue: 0.74)
    static let vitaSand = Color(red: 0.88, green: 0.81, blue: 0.70)
    static let vitaBlueGray = Color(red: 0.77, green: 0.83, blue: 0.86)
    static let vitaGold = Color(red: 0.90, green: 0.77, blue: 0.55)
}
