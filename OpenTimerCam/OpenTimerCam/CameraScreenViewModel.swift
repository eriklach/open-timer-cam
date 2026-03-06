import AVFoundation
import Photos
import SwiftUI

@MainActor
final class CameraScreenViewModel: ObservableObject {
    @Published var statusMessage = ""
    @Published var permissionDeniedMessage: String?

    let recorder = CameraRecorder()
    let timerManager = TimerManager()

    private let exporter = VideoBurnInExporter()
    private let corner: TimerOverlayCorner

    init(corner: TimerOverlayCorner) {
        self.corner = corner
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
                corner: corner
            )
            try await recorder.saveToPhotos(finalURL)
            statusMessage = "Saved to Photos"
        } catch {
            statusMessage = error.localizedDescription
        }
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
