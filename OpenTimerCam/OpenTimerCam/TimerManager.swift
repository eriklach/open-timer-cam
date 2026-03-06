import Foundation

@MainActor
final class TimerManager: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var elapsedSeconds: TimeInterval = 0

    private var timer: Timer?
    private var startedAt: Date?

    var timerStartOffsetFromRecording: TimeInterval?

    var displayString: String {
        Self.formatTime(elapsedSeconds)
    }

    func startTimer(recordingStartedAt: Date?) {
        guard !isRunning else { return }
        isRunning = true
        startedAt = Date()

        if let recordingStartedAt {
            timerStartOffsetFromRecording = max(0, Date().timeIntervalSince(recordingStartedAt))
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshElapsed()
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        refreshElapsed()
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        elapsedSeconds = 0
        startedAt = nil
        timerStartOffsetFromRecording = nil
    }

    private func refreshElapsed() {
        guard let startedAt else {
            elapsedSeconds = 0
            return
        }

        elapsedSeconds = max(0, Date().timeIntervalSince(startedAt))
    }

    static func formatTime(_ seconds: TimeInterval) -> String {
        let value = Int(seconds)
        let minutes = value / 60
        let secs = value % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
