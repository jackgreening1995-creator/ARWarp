import Foundation

/// Typed errors surfaced from ARWarp subsystems to the UI layer.
public enum ARWarpError: LocalizedError, Equatable, Sendable {
    case sceneReconstructionUnavailable
    case sessionFailed(String)
    case meshConversionFailed
    case audioEngineUnavailable
    case microphonePermissionDenied
    case deformationPipelineFailed(String)

    public var errorDescription: String? {
        switch self {
        case .sceneReconstructionUnavailable:
            return "Scene reconstruction requires a LiDAR-equipped iPhone or iPad Pro."
        case .sessionFailed(let message):
            return "AR session failed: \(message)"
        case .meshConversionFailed:
            return "Failed to convert AR mesh geometry for rendering."
        case .audioEngineUnavailable:
            return "Audio engine could not be started."
        case .microphonePermissionDenied:
            return "Microphone access is required to analyze music for warping effects."
        case .deformationPipelineFailed(let message):
            return "Deformation pipeline error: \(message)"
        }
    }
}
