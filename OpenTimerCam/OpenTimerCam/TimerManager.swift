import Foundation
import Combine

@MainActor
final class TimerManager: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var remainingSeconds: TimeInterval = 0

    private var timer: Timer?
    private var startedAt: Date?

    var timerStartOffsetFromRecording: TimeInterval?
    var timerDuration: TimeInterval = 60

    var displayString: String {
        Self.formatTime(remainingSeconds)
    }

    func startTimer(recordingStartedAt: Date?) {
        guard !isRunning else { return }
        isRunning = true
        startedAt = Date()

        if let recordingStartedAt {
            timerStartOffsetFromRecording = max(0, Date().timeIntervalSince(recordingStartedAt))
        }

        refreshElapsed()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
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
        remainingSeconds = timerDuration
        startedAt = nil
        timerStartOffsetFromRecording = nil
    }

    private func refreshElapsed() {
        guard let startedAt else {
            elapsedSeconds = 0
            remainingSeconds = timerDuration
            return
        }

        elapsedSeconds = max(0, Date().timeIntervalSince(startedAt))
        remainingSeconds = max(0, timerDuration - elapsedSeconds)

        if remainingSeconds <= 0, isRunning {
            stopTimer()
        }
    }



    init(timerDuration: TimeInterval = 60) {
        self.timerDuration = timerDuration
        self.remainingSeconds = timerDuration
    }
    nonisolated static func formatTime(_ seconds: TimeInterval) -> String {
        let value = Int(seconds)
        let minutes = value / 60
        let secs = value % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
