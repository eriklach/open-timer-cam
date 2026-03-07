import AVFoundation
import CoreImage
import ImageIO
import UIKit

struct VideoBurnInExporter {
    // Timer burn-in/compositing happens here. Each exported frame receives a rendered
    // timer badge image so the timer is permanently part of the final video pixels.
    func exportVideoWithTimer(
        inputURL: URL,
        timerStartOffset: TimeInterval?,
        timerDuration: TimeInterval,
        recordedOrientation: AVCaptureVideoOrientation?,
        corner: TimerOverlayCorner
    ) async throws -> URL {
        let asset = AVURLAsset(url: inputURL)
        let composition = AVMutableComposition()

        guard let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ExportError.missingVideoTrack
        }

        let videoDuration = try await asset.load(.duration)
        let loadedTransform = try await sourceVideoTrack.load(.preferredTransform)
        let sourceNaturalSize = try await sourceVideoTrack.load(.naturalSize)
        let effectiveOrientation = resolvedOrientation(
            loadedTransform: loadedTransform,
            naturalSize: sourceNaturalSize,
            recordedOrientation: recordedOrientation
        )
        let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        try videoTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: videoDuration), of: sourceVideoTrack, at: .zero)
        videoTrack?.preferredTransform = .identity

        if let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
            let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            try audioTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: videoDuration), of: sourceAudioTrack, at: .zero)
        }

        let renderer = TimerOverlayRenderer(corner: corner)
        let safeTimerOffset = timerStartOffset ?? .greatestFiniteMagnitude
        let renderSize = renderSize(for: sourceNaturalSize, orientation: effectiveOrientation)
        let videoBounds = CGRect(origin: .zero, size: renderSize)
        let exifOrientation = cgOrientation(for: effectiveOrientation)

        let videoComposition = AVMutableVideoComposition(asset: composition) { request in
            let rotatedImage = request.sourceImage.oriented(exifOrientation)
            let sourceImage = rotatedImage
                .transformed(by: .init(translationX: -rotatedImage.extent.minX, y: -rotatedImage.extent.minY))
                .cropped(to: videoBounds)
            let elapsed = max(0, CMTimeGetSeconds(request.compositionTime) - safeTimerOffset)
            let text = TimerManager.formatCountUp(elapsed: elapsed, duration: timerDuration)

            let badge = renderer.makeOverlayImage(text: text, canvasSize: renderSize)
            let result = badge.composited(over: sourceImage).cropped(to: videoBounds)
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

    private func resolvedOrientation(
        loadedTransform: CGAffineTransform,
        naturalSize: CGSize,
        recordedOrientation: AVCaptureVideoOrientation?
    ) -> AVCaptureVideoOrientation {
        let transformedOrientation = inferredOrientation(from: loadedTransform)

        if let recordedOrientation,
           let transformedOrientation,
           isPortrait(recordedOrientation),
           isPortrait(transformedOrientation),
           recordedOrientation != transformedOrientation {
            return recordedOrientation
        }

        if let transformedOrientation {
            return transformedOrientation
        }

        if let recordedOrientation {
            return recordedOrientation
        }

        if naturalSize.height > naturalSize.width {
            return .portrait
        }

        return .landscapeRight
    }

    private func renderSize(for naturalSize: CGSize, orientation: AVCaptureVideoOrientation) -> CGSize {
        if isPortrait(orientation) {
            return CGSize(width: naturalSize.height, height: naturalSize.width)
        }

        return naturalSize
    }

    private func cgOrientation(for orientation: AVCaptureVideoOrientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .portrait:
            return .right
        case .portraitUpsideDown:
            return .left
        case .landscapeLeft:
            return .down
        case .landscapeRight:
            return .up
        @unknown default:
            return .up
        }
    }

    private func isPortrait(_ orientation: AVCaptureVideoOrientation) -> Bool {
        orientation == .portrait || orientation == .portraitUpsideDown
    }

    private func inferredOrientation(from transform: CGAffineTransform) -> AVCaptureVideoOrientation? {
        let a = Int(round(transform.a))
        let b = Int(round(transform.b))
        let c = Int(round(transform.c))
        let d = Int(round(transform.d))

        switch (a, b, c, d) {
        case (0, 1, -1, 0):
            return .portrait
        case (0, -1, 1, 0):
            return .portraitUpsideDown
        case (1, 0, 0, 1):
            return .landscapeRight
        case (-1, 0, 0, -1):
            return .landscapeLeft
        default:
            return nil
        }
    }
}

enum ExportError: Error {
    case missingVideoTrack
    case unableToCreateSession
}

final class TimerOverlayRenderer {
    private struct BadgeStyle: Hashable {
        let width: Int
        let height: Int
        let cornerRadius: Int
        let fontSize: Int
        let textYOffset: Int

        var size: CGSize {
            CGSize(width: width, height: height)
        }

        static func `for`(canvasSize: CGSize) -> BadgeStyle {
            let width = max(110, min(230, Int(canvasSize.width * 0.19)))
            let height = max(46, min(86, Int(Double(width) * 0.44)))
            let cornerRadius = max(10, Int(Double(height) * 0.24))
            let fontSize = max(24, Int(Double(height) * 0.56))
            let textYOffset = max(5, Int(Double(height) * 0.18))

            return BadgeStyle(
                width: width,
                height: height,
                cornerRadius: cornerRadius,
                fontSize: fontSize,
                textYOffset: textYOffset
            )
        }
    }

    private let corner: TimerOverlayCorner
    private var cache: [String: CIImage] = [:]

    init(corner: TimerOverlayCorner) {
        self.corner = corner
    }

    func makeOverlayImage(text: String, canvasSize: CGSize) -> CIImage {
        let style = BadgeStyle.for(canvasSize: canvasSize)
        let badge = cachedBadge(text: text, style: style)
        let position = corner.position(badgeSize: badge.extent.size, canvasSize: canvasSize)
        return badge.transformed(by: .init(translationX: position.x, y: position.y))
    }

    private func cachedBadge(text: String, style: BadgeStyle) -> CIImage {
        let cacheKey = "\(style.width)x\(style.height)-\(style.fontSize)-\(text)"

        if let cached = cache[cacheKey] {
            return cached
        }

        let badgeSize = style.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let image = UIGraphicsImageRenderer(size: badgeSize, format: format).image { _ in
            let backgroundRect = CGRect(origin: .zero, size: badgeSize)
            UIBezierPath(roundedRect: backgroundRect, cornerRadius: CGFloat(style.cornerRadius)).addClip()
            UIColor.black.withAlphaComponent(0.65).setFill()
            UIRectFill(backgroundRect)

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: CGFloat(style.fontSize), weight: .semibold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph,
            ]

            let textRect = CGRect(
                x: 0,
                y: CGFloat(style.textYOffset),
                width: badgeSize.width,
                height: badgeSize.height - CGFloat(style.textYOffset + 4)
            )
            (text as NSString).draw(in: textRect, withAttributes: attributes)
        }

        guard let cgImage = image.cgImage else {
            return CIImage(color: .clear).cropped(to: CGRect(origin: .zero, size: badgeSize))
        }

        let ci = CIImage(cgImage: cgImage)
        cache[cacheKey] = ci
        return ci
    }
}
