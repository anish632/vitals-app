import SwiftUI

struct ContentView: View {
    @StateObject private var health = HealthKitManager()
    @State private var showingPulseScan = false

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
                    // The scroll view already presents the relevant data below.
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
                MetricCard(title: "Heart rate", value: health.snapshot.heartRate.map { String(format: "%.0f", $0) } ?? "—", unit: health.snapshot.heartRate == nil ? "scan to estimate" : health.snapshot.heartRateSource == "Camera estimate" ? "estimated bpm" : "bpm", detail: health.snapshot.heartRateSource, icon: "heart.fill", color: .vitaSage)
                MetricCard(title: "Oxygen", value: oxygenValue, unit: health.snapshot.oxygenSaturation == nil ? "validated device" : "% SpO₂", detail: "Apple Health", icon: "lungs.fill", color: .vitaLavender)
                MetricCard(title: "Blood pressure", value: bloodPressureValue, unit: health.snapshot.systolic == nil ? "validated device" : "mmHg", detail: "Apple Health", icon: "arrow.up.arrow.down", color: .vitaBlush)
                MetricCard(title: "VO₂ max", value: health.snapshot.vo2Max.map { String(format: "%.1f", $0) } ?? "—", unit: health.snapshot.vo2Max == nil ? "Apple Watch" : "mL/kg·min", detail: "Apple Health", icon: "figure.run", color: .vitaSand)
                MetricCard(title: "Restfulness", value: health.snapshot.sleepHours.map { String(format: "%.1f", $0) } ?? "—", unit: health.snapshot.sleepHours == nil ? "connect sleep data" : "hours asleep", detail: "Apple Health", icon: "moon.fill", color: .vitaBlueGray)
                MetricCard(title: "Energy", value: energyValue, unit: "needs history", detail: "Derived after setup", icon: "bolt.fill", color: .vitaGold)
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
            RecommendationRow(icon: "drop.fill", title: "Drink a glass of water", subtitle: "Hydration supports energy and focus.", color: .vitaSage)
            RecommendationRow(icon: "sun.max.fill", title: "Take a mindful pause", subtitle: "Try five minutes of slow breathing before bed.", color: .vitaGold)
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
        health.snapshot.heartRate == nil && health.snapshot.sleepHours == nil ? "—" : "—"
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

    var body: some View {
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
}

private struct RecommendationRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
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
        .background(Color.white.opacity(0.52))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
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
