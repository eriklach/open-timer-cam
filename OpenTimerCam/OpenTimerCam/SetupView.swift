import SwiftUI

struct SetupView: View {
    @Binding var selectedCorner: TimerOverlayCorner
    @Binding var timerMinutes: Int
    @Binding var timerSeconds: Int
    let onContinue: () -> Void

    var body: some View {
        Form {
            Section("Timer Setup") {
                HStack {
                    Picker("Minutes", selection: $timerMinutes) {
                        ForEach(0...59, id: \.self) { minute in
                            Text("\(minute) min").tag(minute)
                        }
                    }

                    Picker("Seconds", selection: $timerSeconds) {
                        ForEach(0...59, id: \.self) { second in
                            Text(String(format: "%02d sec", second)).tag(second)
                        }
                    }
                }

                Picker("Overlay Corner", selection: $selectedCorner) {
                    ForEach(TimerOverlayCorner.allCases) { corner in
                        Text(corner.label).tag(corner)
                    }
                }

                Text("Timer format: mm:ss countdown")
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
