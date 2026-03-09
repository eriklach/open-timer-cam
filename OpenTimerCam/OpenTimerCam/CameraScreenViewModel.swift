import AVFoundation
import Photos
import SwiftUI
import Combine

@MainActor
final class CameraScreenViewModel: ObservableObject {
    @Published var statusMessage = ""
    @Published var permissionDeniedMessage: String?
    @Published var timerDisplayString = "0:00.000"
    @Published var prestartCountdownDisplay: Int?
    @Published var pendingExportURL: URL?
    @Published var shouldPresentSaveDialog = false
    @Published var isStoppingRecording = false

    let recorder = CameraRecorder()
    let timerManager = TimerManager()

    private let exporter = VideoBurnInExporter()
    private let corner: TimerOverlayCorner
    private let shouldBurnInTimer: Bool
    private var cancellables = Set<AnyCancellable>()

    init(corner: TimerOverlayCorner, countdownDuration: TimeInterval, prestartCountdownSeconds: Int, shouldBurnInTimer: Bool) {
        self.corner = corner
        self.shouldBurnInTimer = shouldBurnInTimer
        timerManager.configureDuration(countdownDuration)
        timerManager.configurePrestartCountdownSeconds(prestartCountdownSeconds)
        timerDisplayString = timerManager.displayString

        Publishers.CombineLatest3(timerManager.$elapsedSeconds, timerManager.$prestartRemainingSeconds, timerManager.$state)
            .sink { [weak self] elapsed, prestartRemaining, state in
                guard let self else { return }

                switch state {
                case .idle:
                    self.timerDisplayString = TimerManager.formatTime(0, includeMilliseconds: true)
                    self.prestartCountdownDisplay = nil
                case .prestartCountdown:
                    self.timerDisplayString = TimerManager.formatTime(0, includeMilliseconds: true)
                    self.prestartCountdownDisplay = Int(ceil(prestartRemaining))
                case .running:
                    self.prestartCountdownDisplay = nil
                    self.timerDisplayString = TimerManager.formatCountUp(
                        elapsed: elapsed,
                        duration: self.timerManager.configuredDuration
                    )
                }
            }
            .store(in: &cancellables)
    }

    func setup() async {
        do {
            let granted = await requestPermissions()
            guard granted else {
                permissionDeniedMessage = "Please enable Camera, Microphone, and Photos permissions in Settings."
                return
            }

            try await recorder.configureSession()
            recorder.startSession()
            statusMessage = "Ready"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func startRecording() {
        guard !isStoppingRecording else { return }
        timerManager.reset()
        timerDisplayString = timerManager.displayString
        prestartCountdownDisplay = nil
        recorder.startRecording()
        statusMessage = "Recording..."
    }

    func toggleRecording() {
        if recorder.isRecording {
            Task { await stopRecording() }
        } else {
            startRecording()
        }
    }

    func startTimer() {
        timerManager.startPrestartCountdown(recordingStartedAt: recorder.recordingStartedAt)
        statusMessage = ""
    }

    func toggleTimer() {
        startTimer()
    }

    func cancelPrestartCountdown() {
        guard timerManager.isInPrestartCountdown else { return }
        timerManager.stopTimer()
        statusMessage = "Countdown canceled"
    }

    func stopRecording() async {
        guard recorder.isRecording, pendingExportURL == nil, !isStoppingRecording else { return }
        isStoppingRecording = true

        defer {
            isStoppingRecording = false
        }

        do {
            if timerManager.isInPrestartCountdown || timerManager.isRunning {
                timerManager.stopTimer()
            }

            let rawURL = try await recorder.stopRecording()
            if shouldBurnInTimer {
                statusMessage = "Burning timer into video..."
                let finalURL = try await exporter.exportVideoWithTimer(
                    inputURL: rawURL,
                    timerStartOffset: timerManager.timerStartOffsetFromRecording,
                    timerDuration: timerManager.configuredDuration,
                    recordedOrientation: recorder.lastRecordingOrientation,
                    corner: corner
                )
                try? FileManager.default.removeItem(at: rawURL)
                pendingExportURL = finalURL
                statusMessage = "Recording ready"
            } else {
                pendingExportURL = rawURL
                statusMessage = "Recording ready (no burn-in)"
            }

            shouldPresentSaveDialog = true
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func abandonActiveRecordingAndSession() async {
        guard recorder.isRecording, !isStoppingRecording else { return }
        isStoppingRecording = true

        defer {
            isStoppingRecording = false
        }

        if timerManager.isInPrestartCountdown || timerManager.isRunning {
            timerManager.stopTimer()
        }

        do {
            let rawURL = try await recorder.stopRecording()
            try? FileManager.default.removeItem(at: rawURL)
            statusMessage = "Recording discarded"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func savePendingRecording() async {
        guard let pendingExportURL else { return }

        do {
            try await recorder.saveToPhotos(pendingExportURL)
            try? FileManager.default.removeItem(at: pendingExportURL)
            self.pendingExportURL = nil
            shouldPresentSaveDialog = false
            statusMessage = "Saved to Photos"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func discardPendingRecording() {
        guard let pendingExportURL else { return }
        try? FileManager.default.removeItem(at: pendingExportURL)
        self.pendingExportURL = nil
        shouldPresentSaveDialog = false
        statusMessage = "Recording discarded"
    }

    func cleanupOnNavigation() async {
        while isStoppingRecording {
            try? await Task.sleep(for: .milliseconds(50))
        }

        if recorder.isRecording {
            await abandonActiveRecordingAndSession()
        }

        if let pendingExportURL {
            try? FileManager.default.removeItem(at: pendingExportURL)
            self.pendingExportURL = nil
            shouldPresentSaveDialog = false
        }

        recorder.stopSession()
    }

    private func requestPermissions() async -> Bool {
        let camera = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }

        let mic = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }

        let photoStatus = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }

        let photo = photoStatus == .authorized || photoStatus == .limited
        return camera && mic && photo
    }
}
