import AVFoundation

enum CameraPositionOption: String, CaseIterable, Identifiable {
    case rear
    case front

    var id: String { rawValue }

    var captureDevicePosition: AVCaptureDevice.Position {
        switch self {
        case .rear:
            return .back
        case .front:
            return .front
        }
    }

    var shortLabel: String {
        switch self {
        case .rear:
            return "REAR"
        case .front:
            return "FRONT"
        }
    }
}
