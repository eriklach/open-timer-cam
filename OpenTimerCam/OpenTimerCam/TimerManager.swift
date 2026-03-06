import Foundation
import Combine

@MainActor
final class TimerManager: ObservableObject {
    enum State {
        case idle
        case prestartCountdown
        case running
    }

    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var configuredDuration: TimeInterval = 0
    @Published private(set) var prestartRemainingSeconds: TimeInterval = 10
    @Published private(set) var state: State = .idle

    private var timer: Timer?
    private var startedAt: Date?
    private var prestartStartedAt: Date?

    var timerStartOffsetFromRecording: TimeInterval?

    var isRunning: Bool {
        state == .running
    }

    var isInPrestartCountdown: Bool {
        state == .prestartCountdown
    }

    var displayString: String {
        switch state {
        case .idle:
            return Self.formatTime(0)
        case .prestartCountdown:
            return Self.formatTime(max(0, prestartRemainingSeconds))
        case .running:
            return Self.formatTime(elapsedSeconds)
        }
    }

    func configureDuration(_ duration: TimeInterval) {
        configuredDuration = max(0, duration)
        reset()
    }

    func startPrestartCountdown(recordingStartedAt: Date?) {
        guard state == .idle else { return }
        state = .prestartCountdown
        prestartStartedAt = Date()
        prestartRemainingSeconds = 10

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPrestartCountdown(recordingStartedAt: recordingStartedAt)
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        if state != .idle {
            state = .idle
        }
        refreshElapsed()
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        state = .idle
        elapsedSeconds = 0
        prestartRemainingSeconds = 10
        startedAt = nil
        prestartStartedAt = nil
        timerStartOffsetFromRecording = nil
    }

    private func beginRunningTimer(recordingStartedAt: Date?) {
        state = .running
        startedAt = Date()
        prestartStartedAt = nil
        prestartRemainingSeconds = 0

        if let recordingStartedAt {
            timerStartOffsetFromRecording = max(0, Date().timeIntervalSince(recordingStartedAt))
        }

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshElapsed()
            }
        }
    }

    private func refreshPrestartCountdown(recordingStartedAt: Date?) {
        guard let prestartStartedAt else {
            prestartRemainingSeconds = 10
            return
        }

        let elapsed = max(0, Date().timeIntervalSince(prestartStartedAt))
        prestartRemainingSeconds = max(0, 10 - elapsed)

        if elapsed >= 10 {
            beginRunningTimer(recordingStartedAt: recordingStartedAt)
        }
    }

    private func refreshElapsed() {
        guard let startedAt else {
            elapsedSeconds = 0
            return
        }

        elapsedSeconds = max(0, Date().timeIntervalSince(startedAt))

        if configuredDuration > 0, elapsedSeconds >= configuredDuration {
            elapsedSeconds = configuredDuration
            timer?.invalidate()
            timer = nil
            state = .idle
        }
    }

    nonisolated static func formatTime(_ seconds: TimeInterval) -> String {
        let value = Int(seconds)
        let minutes = value / 60
        let secs = value % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    nonisolated static func formatCountUp(elapsed: TimeInterval, duration: TimeInterval) -> String {
        if duration > 0 {
            return formatTime(min(max(0, elapsed), duration))
        }

        return formatTime(max(0, elapsed))
    }
}
