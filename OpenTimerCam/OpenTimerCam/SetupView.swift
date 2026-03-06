import SwiftUI

struct SetupView: View {
    @Binding var selectedCorner: TimerOverlayCorner
    @Binding var selectedDuration: TimeInterval
    let onContinue: () -> Void

    private let durationOptions: [TimeInterval] = [15, 30, 45, 60, 90, 120, 180, 300, 600]

    var body: some View {
        Form {
            Section("Timer Setup") {
                Picker("Overlay Corner", selection: $selectedCorner) {
                    ForEach(TimerOverlayCorner.allCases) { corner in
                        Text(corner.label).tag(corner)
                    }
                }

                Picker("Timer Duration", selection: $selectedDuration) {
                    ForEach(durationOptions, id: \.self) { duration in
                        Text(durationLabel(duration)).tag(duration)
                    }
                }

                Text("Timer format: mm:ss (countdown)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Continue", action: onContinue)
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Open Timer Cam")
    }

    private func durationLabel(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
