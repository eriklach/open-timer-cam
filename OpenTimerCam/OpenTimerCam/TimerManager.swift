import Foundation
import Combine

@MainActor
final class TimerManager: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var configuredDuration: TimeInterval = 0

    private var timer: Timer?
    private var startedAt: Date?

    var timerStartOffsetFromRecording: TimeInterval?

    var displayString: String {
        let remaining = max(0, configuredDuration - elapsedSeconds)
        return Self.formatTime(remaining)
    }

    func configureDuration(_ duration: TimeInterval) {
        configuredDuration = max(0, duration)
        elapsedSeconds = 0
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

        if elapsedSeconds >= configuredDuration {
            elapsedSeconds = configuredDuration
            timer?.invalidate()
            timer = nil
            isRunning = false
        }
    }

    nonisolated static func formatTime(_ seconds: TimeInterval) -> String {
        let value = Int(seconds)
        let minutes = value / 60
        let secs = value % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    nonisolated static func formatCountdown(elapsed: TimeInterval, duration: TimeInterval) -> String {
        formatTime(max(0, duration - elapsed))
    }
}
