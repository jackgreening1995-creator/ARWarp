import Foundation

/// Procedural displacement presets for the Phase 3 test mesh.
enum DisplacementMode: String, CaseIterable, Identifiable, Sendable {
    case ripple
    case pulse
    case twist

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ripple: return "Tide"
        case .pulse: return "Pulse"
        case .twist: return "Vortex"
        }
    }

    var summary: String {
        switch self {
        case .ripple: return "Wide bass swells that travel across the room"
        case .pulse: return "Shockwave rings with hard beat surges"
        case .twist: return "Rotational pressure that winds up around impacts"
        }
    }

    var accentColorComponents: (red: Float, green: Float, blue: Float) {
        switch self {
        case .ripple: return (0.46, 0.89, 0.98)
        case .pulse: return (0.99, 0.55, 0.36)
        case .twist: return (0.77, 0.66, 1.0)
        }
    }

    var glowColorComponents: (red: Float, green: Float, blue: Float) {
        switch self {
        case .ripple: return (0.78, 0.95, 1.0)
        case .pulse: return (1.0, 0.79, 0.56)
        case .twist: return (0.90, 0.86, 1.0)
        }
    }
}
