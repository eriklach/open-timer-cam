import SwiftUI

struct ContentView: View {
    @State private var didContinue = false
    @State private var selectedCorner: TimerOverlayCorner = .topTrailing
    @State private var timerMinutes = 0
    @State private var timerSeconds = 30

    var body: some View {
        NavigationStack {
            if didContinue {
                CameraScreenView(
                    corner: selectedCorner,
                    countdownDuration: TimeInterval((timerMinutes * 60) + timerSeconds)
                )
            } else {
                SetupView(
                    selectedCorner: $selectedCorner,
                    timerMinutes: $timerMinutes,
                    timerSeconds: $timerSeconds
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
