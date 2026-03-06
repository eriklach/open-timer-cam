import AVFoundation
import CoreImage
import UIKit

struct VideoBurnInExporter {
    // Timer burn-in/compositing happens here. Each exported frame receives a rendered
    // timer badge image so the timer is permanently part of the final video pixels.
    func exportVideoWithTimer(
        inputURL: URL,
        timerStartOffset: TimeInterval?,
        corner: TimerOverlayCorner
    ) async throws -> URL {
        let asset = AVURLAsset(url: inputURL)
        let composition = AVMutableComposition()

        guard let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ExportError.missingVideoTrack
        }

        let videoDuration = try await asset.load(.duration)
        let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        try videoTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: videoDuration), of: sourceVideoTrack, at: .zero)
        videoTrack?.preferredTransform = try await sourceVideoTrack.load(.preferredTransform)

        if let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
            let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            try audioTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: videoDuration), of: sourceAudioTrack, at: .zero)
        }

        let renderer = TimerOverlayRenderer(corner: corner)
        let safeTimerOffset = timerStartOffset ?? .greatestFiniteMagnitude
        let renderSize = normalizedRenderSize(
            naturalSize: try await sourceVideoTrack.load(.naturalSize),
            transform: try await sourceVideoTrack.load(.preferredTransform)
        )

        let videoComposition = AVMutableVideoComposition(asset: composition) { request in            let sourceImage = request.sourceImage.clampedToExtent()
            let elapsed = max(0, CMTimeGetSeconds(request.compositionTime) - safeTimerOffset)
            let text = TimerManager.formatTime(elapsed)

            let badge = renderer.makeOverlayImage(text: text, canvasSize: renderSize)
            let result = badge.composited(over: sourceImage).cropped(to: request.sourceImage.extent)
            request.finish(with: result, context: nil)
        }

        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.renderSize = renderSize

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw ExportError.unableToCreateSession
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("final-\(UUID().uuidString).mov")

        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = false

        if #available(iOS 18.0, *) {
            try await exportSession.export(to: outputURL, as: .mov)
        } else {
            exportSession.outputFileType = .mov
            exportSession.outputURL = outputURL
            try await exportSession.exportCompat()

            if let error = exportSession.error {
                throw error
            }
        }

        return outputURL
    }

    private func normalizedRenderSize(naturalSize: CGSize, transform: CGAffineTransform) -> CGSize {
        let rect = CGRect(origin: .zero, size: naturalSize).applying(transform)
        return CGSize(width: abs(rect.width), height: abs(rect.height))
    }
}

enum ExportError: Error {
    case missingVideoTrack
    case unableToCreateSession
}

final class TimerOverlayRenderer {
    private let corner: TimerOverlayCorner
    private var cache: [String: CIImage] = [:]

    init(corner: TimerOverlayCorner) {
        self.corner = corner
    }

    func makeOverlayImage(text: String, canvasSize: CGSize) -> CIImage {
        let badge = cachedBadge(text: text)
        let position = corner.position(badgeSize: badge.extent.size, canvasSize: canvasSize)
        return badge.transformed(by: .init(translationX: position.x, y: position.y))
    }

    private func cachedBadge(text: String) -> CIImage {
        if let cached = cache[text] {
            return cached
        }

        let badgeSize = CGSize(width: 88, height: 36)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let image = UIGraphicsImageRenderer(size: badgeSize, format: format).image { _ in
            let backgroundRect = CGRect(origin: .zero, size: badgeSize)
            UIBezierPath(roundedRect: backgroundRect, cornerRadius: 8).addClip()
            UIColor.black.withAlphaComponent(0.65).setFill()
            UIRectFill(backgroundRect)

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .semibold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph,
            ]

            let textRect = CGRect(x: 0, y: 7, width: badgeSize.width, height: badgeSize.height - 8)
            (text as NSString).draw(in: textRect, withAttributes: attributes)
        }

        guard let cgImage = image.cgImage else {
            return CIImage(color: .clear).cropped(to: CGRect(origin: .zero, size: badgeSize))
        }

        let ci = CIImage(cgImage: cgImage)
        cache[text] = ci
        return ci
    }
}
