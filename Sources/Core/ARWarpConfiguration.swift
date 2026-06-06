import Foundation

/// Central configuration for ARWarp session and rendering defaults.
enum ARWarpConfiguration {
    /// Minimum iOS version required for LowLevelMesh deformation pipeline.
    static let minimumOSVersion = (18, 0)

    /// Scene reconstruction mode — mesh with surface classification labels.
    static let usesMeshClassification = true

    /// Mesh anchors needed before the room usually feels "present" instead of half-scanned.
    static let meshAnchorGoalForLiveMode = 12

    /// Audio activity threshold for transitioning the HUD into live-performance messaging.
    static let liveAudioThreshold: Float = 0.09

    /// Base tint for room-mesh materials before mode-specific accents are layered on.
    static let debugMeshColor: (red: Float, green: Float, blue: Float) = (0.72, 0.88, 0.98)

    /// Whether to show plane detection alongside mesh (disabled during warp mode).
    static let enablePlaneDetection = false

    /// Automatic environment texturing for improved PBR response.
    static let environmentTexturingAutomatic = true
}
