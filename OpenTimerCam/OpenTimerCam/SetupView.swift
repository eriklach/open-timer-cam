import SwiftUI

struct SetupView: View {
    @Binding var selectedCorner: TimerOverlayCorner
    @Binding var timerMinutes: Int
    let onContinue: () -> Void

    var body: some View {
        Form {
            Section("Timer Setup") {
                Picker("Minutes", selection: $timerMinutes) {
                    ForEach(0...59, id: \.self) { minute in
                        Text("\(minute) min").tag(minute)
                    }
                }

                Picker("Overlay Corner", selection: $selectedCorner) {
                    ForEach(TimerOverlayCorner.allCases) { corner in
                        Text(corner.label).tag(corner)
                    }
                }

                Text("Timer format: m:ss count up")
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
