import CoreGraphics
import SwiftUI

enum TimerOverlayCorner: String, CaseIterable, Identifiable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    var id: String { rawValue }

    var label: String {
        switch self {
        case .topLeading: "Top Left"
        case .topTrailing: "Top Right"
        case .bottomLeading: "Bottom Left"
        case .bottomTrailing: "Bottom Right"
        }
    }



    var alignment: Alignment {
        switch self {
        case .topLeading: .topLeading
        case .topTrailing: .topTrailing
        case .bottomLeading: .bottomLeading
        case .bottomTrailing: .bottomTrailing
        }
    }

    func position(badgeSize: CGSize, canvasSize: CGSize) -> CGPoint {
        let padding: CGFloat = 16
        let x: CGFloat = switch self {
        case .topLeading, .bottomLeading: padding
        case .topTrailing, .bottomTrailing: max(padding, canvasSize.width - badgeSize.width - padding)
        }

        let y: CGFloat = switch self {
        case .topLeading, .topTrailing: max(padding, canvasSize.height - badgeSize.height - padding)
        case .bottomLeading, .bottomTrailing: padding
        }

        return CGPoint(x: x, y: y)
    }
}
