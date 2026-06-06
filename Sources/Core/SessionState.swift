import Foundation

/// Lifecycle state of the AR session, published to SwiftUI overlays.
public enum SessionState: String, Sendable {
    case initializing
    case running
    case paused
    case failed
    case unsupported

    public var displayName: String {
        switch self {
        case .initializing: return "Initializing"
        case .running: return "Running"
        case .paused: return "Paused"
        case .failed: return "Failed"
        case .unsupported: return "Unsupported Device"
        }
    }

    public var isActive: Bool {
        self == .running
    }
}
