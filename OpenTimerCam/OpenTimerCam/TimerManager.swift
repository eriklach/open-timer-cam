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
    @Published private(set) var prestartRemainingSeconds: TimeInterval = 0
    @Published private(set) var prestartCountdownSeconds: Int = 10
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
            return Self.formatTime(0, includeMilliseconds: true)
        case .prestartCountdown:
            return Self.formatTime(max(0, prestartRemainingSeconds), includeMilliseconds: true)
        case .running:
            return Self.formatTime(elapsedSeconds, includeMilliseconds: true)
        }
    }

    func configureDuration(_ duration: TimeInterval) {
        configuredDuration = max(0, duration)
        reset()
    }

    func configurePrestartCountdownSeconds(_ seconds: Int) {
        prestartCountdownSeconds = max(0, seconds)
        if state == .idle {
            prestartRemainingSeconds = TimeInterval(prestartCountdownSeconds)
        }
    }

    func startPrestartCountdown(recordingStartedAt: Date?) {
        guard state == .idle else { return }

        if prestartCountdownSeconds == 0 {
            beginRunningTimer(recordingStartedAt: recordingStartedAt)
            return
        }

        state = .prestartCountdown
        prestartStartedAt = Date()
        prestartRemainingSeconds = TimeInterval(prestartCountdownSeconds)

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
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
        prestartRemainingSeconds = TimeInterval(prestartCountdownSeconds)
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
        timer = Timer.scheduledTimer(withTimeInterval: (1.0 / 30.0), repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshElapsed()
            }
        }
    }

    private func refreshPrestartCountdown(recordingStartedAt: Date?) {
        guard let prestartStartedAt else {
            prestartRemainingSeconds = TimeInterval(prestartCountdownSeconds)
            return
        }

        let elapsed = max(0, Date().timeIntervalSince(prestartStartedAt))
        prestartRemainingSeconds = max(0, TimeInterval(prestartCountdownSeconds) - elapsed)

        if elapsed >= TimeInterval(prestartCountdownSeconds) {
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

    nonisolated static func formatTime(_ seconds: TimeInterval, includeMilliseconds: Bool = true) -> String {
        let clampedSeconds = max(0, seconds)
        let minutes = Int(clampedSeconds) / 60
        let secs = Int(clampedSeconds) % 60

        if includeMilliseconds {
            let millis = Int((clampedSeconds * 1000).truncatingRemainder(dividingBy: 1000))
            return String(format: "%d:%02d.%03d", minutes, secs, millis)
        }

        return String(format: "%d:%02d", minutes, secs)
    }

    nonisolated static func formatCountUp(elapsed: TimeInterval, duration: TimeInterval) -> String {
        let value: TimeInterval
        if duration > 0 {
            value = min(max(0, elapsed), duration)
        } else {
            value = max(0, elapsed)
        }

        return formatTime(value, includeMilliseconds: true)
    }
}
