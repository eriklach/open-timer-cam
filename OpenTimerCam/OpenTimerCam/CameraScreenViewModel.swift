import AVFoundation
import Photos
import SwiftUI
import Combine

@MainActor
final class CameraScreenViewModel: ObservableObject {
    @Published var statusMessage = ""
    @Published var permissionDeniedMessage: String?
    @Published var timerDisplayString = "00:00"
    @Published var pendingExportURL: URL?
    @Published var shouldPresentSaveDialog = false

    let recorder = CameraRecorder()
    let timerManager = TimerManager()

    private let exporter = VideoBurnInExporter()
    private let corner: TimerOverlayCorner
    private var cancellables = Set<AnyCancellable>()

    init(corner: TimerOverlayCorner, countdownDuration: TimeInterval) {
        self.corner = corner
        timerManager.configureDuration(countdownDuration)
        timerDisplayString = timerManager.displayString

        Publishers.CombineLatest(timerManager.$elapsedSeconds, timerManager.$configuredDuration)
            .sink { [weak self] elapsed, duration in
                self?.timerDisplayString = TimerManager.formatCountdown(elapsed: elapsed, duration: duration)
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
        timerManager.reset()
        timerDisplayString = timerManager.displayString
        recorder.startRecording()
        statusMessage = "Recording..."
    }

    func startTimer() {
        timerManager.startTimer(recordingStartedAt: recorder.recordingStartedAt)
        statusMessage = "Timer running"
    }

    func stopRecording() async {
        do {
            if timerManager.isRunning {
                timerManager.stopTimer()
            }

            let rawURL = try await recorder.stopRecording()
            statusMessage = "Burning timer into video..."
            let finalURL = try await exporter.exportVideoWithTimer(
                inputURL: rawURL,
                timerStartOffset: timerManager.timerStartOffsetFromRecording,
                timerDuration: timerManager.configuredDuration,
<<<<<<< codex/fix-timer-setup-and-playback-issues-mmfsib
                recordedOrientation: recorder.lastRecordingOrientation,
=======
>>>>>>> firstUpdates
                corner: corner
            )
            try? FileManager.default.removeItem(at: rawURL)
            pendingExportURL = finalURL
            shouldPresentSaveDialog = true
            statusMessage = "Recording ready"
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
