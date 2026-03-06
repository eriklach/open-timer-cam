import SwiftUI

struct ContentView: View {
    @State private var didContinue = false
    @State private var selectedCorner: TimerOverlayCorner = .topTrailing

    var body: some View {
        NavigationStack {
            if didContinue {
                CameraScreenView(corner: selectedCorner)
            } else {
                SetupView(selectedCorner: $selectedCorner) {
                    didContinue = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
