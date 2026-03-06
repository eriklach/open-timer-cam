import AVFoundation
import UIKit
import Photos
import Combine

@MainActor
final class CameraRecorder: NSObject, ObservableObject {
    enum RecorderError: LocalizedError {
        case cameraUnavailable
        case noMovieFile
        case photoSaveFailed

        var errorDescription: String? {
            switch self {
            case .cameraUnavailable:
                "Camera is unavailable on this device."
            case .noMovieFile:
                "No recording file was produced."
            case .photoSaveFailed:
                "Failed to save video to Photos library."
            }
        }
    }

    @Published private(set) var isSessionRunning = false
    @Published private(set) var isRecording = false

    nonisolated(unsafe) let session = AVCaptureSession()

    nonisolated(unsafe) private let movieOutput = AVCaptureMovieFileOutput()
    nonisolated(unsafe) private let sessionQueue = DispatchQueue(label: "OpenTimerCam.session.queue")
    nonisolated(unsafe) private var videoInput: AVCaptureDeviceInput?
    nonisolated(unsafe) private var audioInput: AVCaptureDeviceInput?

    private var continuation: CheckedContinuation<URL, Error>?
    private(set) var recordingStartedAt: Date?
    private(set) var lastRecordingOrientation: AVCaptureVideoOrientation?

    func configureSession() async throws {
        try await withCheckedThrowingContinuation { cont in
            sessionQueue.async {
                do {
                    self.session.beginConfiguration()
                    self.session.sessionPreset = .high

                    guard
                        let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                    else {
                        throw RecorderError.cameraUnavailable
                    }

                    let videoInput = try AVCaptureDeviceInput(device: camera)
                    let audioDevice = AVCaptureDevice.default(for: .audio)
                    guard let audioDevice else { throw RecorderError.cameraUnavailable }
                    let audioInput = try AVCaptureDeviceInput(device: audioDevice)

                    if self.session.canAddInput(videoInput) {
                        self.session.addInput(videoInput)
                        self.videoInput = videoInput
                    }

                    if self.session.canAddInput(audioInput) {
                        self.session.addInput(audioInput)
                        self.audioInput = audioInput
                    }

                    if self.session.canAddOutput(self.movieOutput) {
                        self.session.addOutput(self.movieOutput)
                    }

                    self.session.commitConfiguration()
                    cont.resume()
                } catch {
                    self.session.commitConfiguration()
                    cont.resume(throwing: error)
                }
            }
        }
    }

    func startSession() {
        sessionQueue.async {
            guard !self.session.isRunning else { return }
            self.session.startRunning()
            Task { @MainActor in
                self.isSessionRunning = self.session.isRunning
            }
        }
    }

    func stopSession() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            Task { @MainActor in
                self.isSessionRunning = self.session.isRunning
            }
        }
    }

    func startRecording() {
        guard !isRecording else { return }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("raw-\(UUID().uuidString).mov")

        lastRecordingOrientation = updateVideoOrientation()
        recordingStartedAt = Date()
        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecording = true
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func stopRecording() async throws -> URL {
        guard movieOutput.isRecording else {
            throw RecorderError.noMovieFile
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            movieOutput.stopRecording()
        }
    }

    func saveToPhotos(_ fileURL: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: RecorderError.photoSaveFailed)
                }
            }
        }
    }

    private func updateVideoOrientation() -> AVCaptureVideoOrientation {
        guard let connection = movieOutput.connection(with: .video) else {
            return .portrait
        }

        let targetOrientation = currentVideoOrientation()

        if connection.isVideoOrientationSupported {
            connection.videoOrientation = targetOrientation
            return targetOrientation
        }

        if #available(iOS 17.0, *) {
            let angle = rotationAngle(for: targetOrientation)
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }

        return targetOrientation
    }

    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        if let interfaceOrientation = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })?
            .interfaceOrientation {
            return videoOrientation(from: interfaceOrientation)
        }

        return videoOrientation(from: UIDevice.current.orientation)
    }

    private func videoOrientation(from interfaceOrientation: UIInterfaceOrientation) -> AVCaptureVideoOrientation {
        switch interfaceOrientation {
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        case .portraitUpsideDown:
            return .portraitUpsideDown
        default:
            return .portrait
        }
    }

    private func videoOrientation(from deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation {
        switch deviceOrientation {
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        case .portraitUpsideDown:
            return .portraitUpsideDown
        default:
            return .portrait
        }
    }

    @available(iOS 17.0, *)
    private func rotationAngle(for orientation: AVCaptureVideoOrientation) -> CGFloat {
        switch orientation {
        case .portrait:
            return 0
        case .landscapeRight:
            return 90
        case .portraitUpsideDown:
            return 180
        case .landscapeLeft:
            return 270
        @unknown default:
            return 0
        }
    }
}

extension CameraRecorder: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            UIApplication.shared.isIdleTimerDisabled = false
            self.isRecording = false

            if let error {
                self.continuation?.resume(throwing: error)
            } else {
                self.continuation?.resume(returning: outputFileURL)
            }

            self.continuation = nil
        }
    }
}
