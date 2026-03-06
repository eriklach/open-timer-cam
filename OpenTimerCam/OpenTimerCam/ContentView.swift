import SwiftUI

struct ContentView: View {
    @State private var didContinue = false
    @State private var selectedCorner: TimerOverlayCorner = .topTrailing
    @State private var timerMinutes = 0

    var body: some View {
        NavigationStack {
            if didContinue {
                CameraScreenView(
                    corner: selectedCorner,
                    countdownDuration: TimeInterval(timerMinutes * 60),
                    onBackToSetup: { didContinue = false }
                )
            } else {
                SetupView(
                    selectedCorner: $selectedCorner,
                    timerMinutes: $timerMinutes
                ) {
                    didContinue = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
