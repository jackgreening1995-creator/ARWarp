import Foundation
import simd

/// Uniform block uploaded to the Metal deformation compute kernel (must match `SceneDeformation.metal`).
struct AudioDeformUniforms {
    var time: Float = 0
    var deltaTime: Float = 0
    var bassDrive: Float = 0
    var energyDrive: Float = 0
    var beatDrive: Float = 0
    var midsDrive: Float = 0
    var highsDrive: Float = 0
    var beatEnvelope: Float = 0
    var mode: UInt32 = 0
    var bassSpeedScale: Float = AudioDeformationMapping.default.bassSpeedScale
    var chunkCenterX: Float = 0
    var chunkCenterZ: Float = 0
}

extension AudioDeformUniforms {
    static func from(
        drives: DeformationDriveValues,
        beatEnvelope: Float,
        mode: DisplacementMode,
        mapping: AudioDeformationMapping,
        time: Float,
        deltaTime: Float,
        chunkCenter: SIMD2<Float>
    ) -> AudioDeformUniforms {
        AudioDeformUniforms(
            time: time,
            deltaTime: deltaTime,
            bassDrive: drives.bass,
            energyDrive: drives.energy,
            beatDrive: drives.beat,
            midsDrive: drives.mids,
            highsDrive: drives.highs,
            beatEnvelope: beatEnvelope,
            mode: mode.metalModeIndex,
            bassSpeedScale: mapping.bassSpeedScale,
            chunkCenterX: chunkCenter.x,
            chunkCenterZ: chunkCenter.y
        )
    }

    static func restPose(
        mode: DisplacementMode = .ripple,
        bassSpeedScale: Float = AudioDeformationMapping.default.bassSpeedScale
    ) -> AudioDeformUniforms {
        AudioDeformUniforms(
            mode: mode.metalModeIndex,
            bassSpeedScale: bassSpeedScale
        )
    }
}

private extension DisplacementMode {
    var metalModeIndex: UInt32 {
        switch self {
        case .ripple: return 0
        case .pulse: return 1
        case .twist: return 2
        }
    }
}
