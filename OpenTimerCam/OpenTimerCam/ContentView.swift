import SwiftUI

struct ContentView: View {
    @State private var didContinue = false
    @AppStorage("setup.selectedCorner") private var selectedCornerRawValue = TimerOverlayCorner.topTrailing.rawValue
    @AppStorage("setup.timerMinutes") private var timerMinutes = 0
    @AppStorage("setup.countdownSeconds") private var countdownSeconds = 10
    @AppStorage("setup.burnInTimer") private var burnInTimer = true

    private var selectedCornerBinding: Binding<TimerOverlayCorner> {
        Binding(
            get: { TimerOverlayCorner(rawValue: selectedCornerRawValue) ?? .topTrailing },
            set: { selectedCornerRawValue = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            if didContinue {
                CameraScreenView(
                    corner: selectedCornerBinding.wrappedValue,
                    countdownDuration: TimeInterval(timerMinutes * 60),
                    prestartCountdownSeconds: countdownSeconds,
                    shouldBurnInTimer: burnInTimer,
                    onBackToSetup: { didContinue = false }
                )
            } else {
                SetupView(
                    selectedCorner: selectedCornerBinding,
                    timerMinutes: $timerMinutes,
                    countdownSeconds: $countdownSeconds,
                    burnInTimer: $burnInTimer
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
