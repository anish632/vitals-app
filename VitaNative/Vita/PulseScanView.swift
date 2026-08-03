import SwiftUI

struct PulseScanView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var progress = 0.0
    @State private var status = "Getting ready…"
    @State private var finished = false
    @State private var canRetry = false
    @State private var attempt = 0

    let onComplete: (Double) -> Void

    var body: some View {
        ZStack {
            Color.vitaNavy.ignoresSafeArea()
            VStack(spacing: 22) {
                HStack {
                    Label("LIVE PULSE CHECK", systemImage: "waveform.path.ecg")
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(Color.vitaPeach)
                    Spacer()
                    Button("Close") { dismiss() }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .padding(.horizontal, 24)

                Spacer()

                Text(finished ? "Pulse captured." : "Keep your finger\nsteady.")
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                Text("Cover the rear camera and flash with your fingertip. Stay still while Vita samples the optical pulse signal.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.62))
                    .padding(.horizontal, 36)

                ZStack {
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 2)
                    Circle().trim(from: 0, to: max(0.03, progress))
                        .stroke(Color.vitaPeach, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: finished ? "checkmark" : "waveform.path.ecg")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(Color.vitaCoral)
                }
                .frame(width: 220, height: 220)

                Text(status)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .frame(height: 18)

                if finished {
                    Button("Done") { dismiss() }
                        .buttonStyle(VitaPrimaryButtonStyle())
                } else if canRetry {
                    Button("Try again") {
                        canRetry = false
                        status = "Getting ready…"
                        attempt += 1
                    }
                    .buttonStyle(VitaPrimaryButtonStyle())
                } else {
                    Text("This is a personal wellness estimate, not a medical measurement.")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.white.opacity(0.42))
                        .padding(.horizontal, 32)
                }

                CameraPulseView(
                    onProgress: { progress, message in
                        self.progress = progress
                        self.status = message
                    },
                    onResult: { result in
                        switch result {
                        case .success(let bpm):
                            self.progress = 1
                            self.status = "Camera pulse estimate · \(String(format: "%.0f", bpm)) bpm"
                            self.finished = true
                            onComplete(bpm)
                        case .failure(let error):
                            self.status = error.localizedDescription
                            self.progress = 0
                            self.canRetry = true
                        }
                    }
                )
                .id(attempt)
                .frame(width: 1, height: 1)
                .opacity(0.01)
            }
            .padding(.top, 18)
            .padding(.bottom, 26)
        }
    }
}

private struct VitaPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 13)
            .background(Color.vitaCoral.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}
