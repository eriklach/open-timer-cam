import SwiftUI

private enum SetupTheme {
    static let neonPrimary = Color(red: 0.58, green: 1.0, blue: 0.35)
    static let neonMuted = Color(red: 0.50, green: 0.82, blue: 0.44)
    static let darkBackground = Color(red: 0.04, green: 0.08, blue: 0.06)

    static let frameStroke = StrokeStyle(lineWidth: 1.5)
}

private struct NeonGlow: ViewModifier {
    var color: Color = SetupTheme.neonPrimary

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.45), radius: 3, x: 0, y: 0)
            .shadow(color: color.opacity(0.25), radius: 8, x: 0, y: 0)
    }
}

private struct NeonCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(SetupTheme.darkBackground.opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(SetupTheme.neonMuted, style: SetupTheme.frameStroke)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .modifier(NeonGlow(color: SetupTheme.neonMuted))
    }
}

private extension View {
    func neonGlow(color: Color = SetupTheme.neonPrimary) -> some View {
        modifier(NeonGlow(color: color))
    }

    func neonCard() -> some View {
        modifier(NeonCard())
    }
}

struct SetupView: View {
    @Binding var selectedCorner: TimerOverlayCorner
    @Binding var timerMinutes: Int
    @Binding var countdownSeconds: Int
    @Binding var burnInTimer: Bool
    let onContinue: () -> Void

    private let countdownOptions = [0, 3, 5, 10]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                pickerCard(title: "Timer Duration") {
                    Picker("Minutes", selection: $timerMinutes) {
                        ForEach(0...59, id: \.self) { minute in
                            Text("\(minute) min").tag(minute)
                        }
                    }
                    .pickerStyle(.menu)
                }

                pickerCard(title: "Starting Countdown") {
                    Picker("Starting Countdown", selection: $countdownSeconds) {
                        ForEach(countdownOptions, id: \.self) { seconds in
                            Text(seconds == 0 ? "Off" : "\(seconds) sec").tag(seconds)
                        }
                    }
                    .pickerStyle(.menu)
                }

                pickerCard(title: "Overlay Corner") {
                    Picker("Overlay Corner", selection: $selectedCorner) {
                        ForEach(TimerOverlayCorner.allCases) { corner in
                            Text(corner.label).tag(corner)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Burn timer into exported video", isOn: $burnInTimer)
                        .tint(SetupTheme.neonPrimary)

                    Text("Timer format: m:ss.SSS count up")
                        .font(.footnote)
                        .foregroundStyle(SetupTheme.neonMuted.opacity(0.9))
                }
                .neonCard()

                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(SetupTheme.darkBackground)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(SetupTheme.neonPrimary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(SetupTheme.neonPrimary.opacity(0.95), style: SetupTheme.frameStroke)
                        )
                        .neonGlow()
                }
                .buttonStyle(.plain)
                .neonCard()
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .background(SetupTheme.darkBackground.ignoresSafeArea())
        .navigationTitle("Open Timer Cam")
    }

    @ViewBuilder
    private func pickerCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SetupTheme.neonMuted)

            content()
                .tint(SetupTheme.neonPrimary)
                .foregroundStyle(.white)
        }
        .neonCard()
    }
}
