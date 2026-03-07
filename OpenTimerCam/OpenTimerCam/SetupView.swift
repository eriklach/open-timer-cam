import SwiftUI

struct SetupView: View {
    @Binding var selectedCorner: TimerOverlayCorner
    @Binding var timerMinutes: Int
    @Binding var countdownSeconds: Int
    @Binding var burnInTimer: Bool
    let onContinue: () -> Void

    private let countdownOptions = [0, 3, 5, 10]

    var body: some View {
        Form {
            Section("Timer Setup") {
                Picker("Minutes", selection: $timerMinutes) {
                    ForEach(0...59, id: \.self) { minute in
                        Text("\(minute) min").tag(minute)
                    }
                }

                Picker("Starting Countdown", selection: $countdownSeconds) {
                    ForEach(countdownOptions, id: \.self) { seconds in
                        Text(seconds == 0 ? "Off" : "\(seconds) sec").tag(seconds)
                    }
                }

                Picker("Overlay Corner", selection: $selectedCorner) {
                    ForEach(TimerOverlayCorner.allCases) { corner in
                        Text(corner.label).tag(corner)
                    }
                }

                Toggle("Burn timer into exported video", isOn: $burnInTimer)

                Text("Timer format: m:ss.SSS count up")
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
}
