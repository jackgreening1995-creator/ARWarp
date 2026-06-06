import Foundation

/// Performance and budget settings for scene mesh GPU deformation.
enum SceneDeformationConfiguration {
    /// Maximum scene chunks deformed per frame (closest to camera first).
    static let maxActiveChunksPerFrame = 8

    /// Skip chunks with more vertices than this (topology too dense for real-time GPU pass).
    static let maxVerticesPerChunk = 32_768

    /// Only deform chunks whose centroid is within this distance from the camera (meters).
    static let maxDeformationDistance: Float = 5.25

    /// Minimum seconds between full geometry rebuilds for the same anchor during updates.
    static let geometryRebuildCooldown: TimeInterval = 0.35

    /// Scene mesh material opacity for environment-blended warp overlay.
    static let sceneMeshOpacity: Float = 0.18

    /// Seconds for newly discovered chunks to reach full opacity.
    static let chunkFadeInDuration: Float = 0.25

    /// Seconds for retired chunks to fade out before being removed.
    static let chunkRetireDuration: Float = 0.18

    /// Caps a resumed or badly-hitched frame so smoothing and fades do not jump in one update.
    static let maxFrameDeltaTime: Float = 1.0 / 15.0

    static func clampedFrameDeltaTime(_ deltaTime: Float) -> Float {
        min(max(deltaTime, 0), maxFrameDeltaTime)
    }
}

/// Runtime stats published to the debug HUD.
struct SceneDeformationStats: Sendable, Equatable {
    var totalChunks: Int = 0
    var activeChunks: Int = 0
    var skippedChunks: Int = 0
    var deformedVertices: Int = 0
    var gpuFrameMilliseconds: Float = 0
}

enum DeformationTarget: String, CaseIterable, Identifiable {
    case sceneMesh
    case testGrid
    case both

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sceneMesh: return "Room"
        case .testGrid: return "Grid"
        case .both: return "Both"
        }
    }
}
