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

    let session = AVCaptureSession()

    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "OpenTimerCam.session.queue")
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?

    private var continuation: CheckedContinuation<URL, Error>?
    private(set) var recordingStartedAt: Date?

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
            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
            }
        }
    }

    func stopSession() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
            }
        }
    }

    func startRecording() {
        guard !isRecording else { return }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("raw-\(UUID().uuidString).mov")

        updateVideoOrientation()
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
        try await withCheckedThrowingContinuation { continuation in
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

    private func updateVideoOrientation() {
        guard let connection = movieOutput.connection(with: .video), connection.isVideoOrientationSupported else {
            return
        }

        connection.videoOrientation = switch UIDevice.current.orientation {
        case .landscapeLeft: .landscapeRight
        case .landscapeRight: .landscapeLeft
        case .portraitUpsideDown: .portraitUpsideDown
        default: .portrait
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
