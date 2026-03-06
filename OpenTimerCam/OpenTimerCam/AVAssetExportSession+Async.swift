import Foundation
import AVFoundation

extension AVAssetExportSession {
    func export() async throws {
        try await withCheckedThrowingContinuation { continuation in
            exportAsynchronously {
                switch self.status {
                case .completed:
                    continuation.resume()
                case .failed:
                    continuation.resume(throwing: self.error ?? NSError(domain: "Export", code: -1))
                case .cancelled:
                    continuation.resume(throwing: NSError(domain: "Export", code: -2))
                default:
                    continuation.resume(throwing: NSError(domain: "Export", code: -3))
                }
            }
        }
    }
}
