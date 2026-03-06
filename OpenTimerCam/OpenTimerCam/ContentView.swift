import SwiftUI

struct ContentView: View {
    @State private var didContinue = false
    @State private var selectedCorner: TimerOverlayCorner = .topTrailing
    @State private var selectedDuration: TimeInterval = 60

    var body: some View {
        NavigationStack {
            if didContinue {
                CameraScreenView(corner: selectedCorner, timerDuration: selectedDuration)
            } else {
                SetupView(selectedCorner: $selectedCorner, selectedDuration: $selectedDuration) {
                    didContinue = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
