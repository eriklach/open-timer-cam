import SwiftUI

struct SetupView: View {
    @Binding var selectedCorner: TimerOverlayCorner
    let onContinue: () -> Void

    var body: some View {
        Form {
            Section("Timer Setup") {
                Picker("Overlay Corner", selection: $selectedCorner) {
                    ForEach(TimerOverlayCorner.allCases) { corner in
                        Text(corner.label).tag(corner)
                    }
                }

                Text("Timer format: mm:ss (counts up from 00:00)")
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
