import Foundation
import simd

/// Live readout of how audio features contributed to the most recent deformation frame.
struct DeformationDriveSnapshot: Sendable, Equatable {
    var bassContribution: Float = 0
    var energyContribution: Float = 0
    var beatContribution: Float = 0
    var midsContribution: Float = 0
    var highsContribution: Float = 0
    var peakDisplacement: Float = 0
    var beatEnvelope: Float = 0
    var levelGain: Float = 1
}

/// Applies audio-modulated procedural displacement to the Phase 3 test grid (CPU path).
struct AudioDrivenDeformer {
    var mapping: AudioDeformationMapping
    var mode: DisplacementMode

    private var elapsedTime: Float = 0
    private var driveSmoother = DeformationDriveSmoother()
    private(set) var lastDriveSnapshot = DeformationDriveSnapshot()

    init(
        mapping: AudioDeformationMapping = DeformationConfiguration.defaultMapping,
        mode: DisplacementMode = .ripple
    ) {
        self.mapping = mapping
        self.mode = mode
    }

    mutating func resetTime() {
        elapsedTime = 0
        driveSmoother.reset()
        lastDriveSnapshot = DeformationDriveSnapshot()
    }

    @MainActor
    mutating func apply(
        to mesh: DeformableGridMesh,
        audio: AudioFeatureSnapshot,
        deltaTime: Float
    ) throws {
        let drives = driveSmoother.update(audio: audio, mapping: mapping, deltaTime: deltaTime)
        try apply(
            to: mesh,
            drives: drives,
            beatEnvelope: driveSmoother.beatEnvelope,
            audio: audio,
            deltaTime: deltaTime
        )
    }

    /// Applies displacement using pre-smoothed drives (shared with scene GPU path).
    @MainActor
    mutating func apply(
        to mesh: DeformableGridMesh,
        drives: DeformationDriveValues,
        beatEnvelope: Float,
        audio: AudioFeatureSnapshot,
        deltaTime: Float
    ) throws {
        elapsedTime += deltaTime

        var peakDisplacement: Float = 0
        var displacedPositions = mesh.basePositions
        var normals = [SIMD3<Float>](repeating: SIMD3(0, 1, 0), count: mesh.vertexCount)

        for index in 0..<mesh.vertexCount {
            let base = mesh.basePositions[index]
            let displacement = displacement(
                at: base,
                audio: audio,
                bassDrive: drives.bass,
                energyDrive: drives.energy,
                beatDrive: drives.beat,
                midsDrive: drives.mids,
                highsDrive: drives.highs,
                beatEnvelope: beatEnvelope
            )

            displacedPositions[index] = base + SIMD3(0, displacement, 0)
            peakDisplacement = max(peakDisplacement, abs(displacement))
        }

        recomputeNormals(
            segments: mesh.segments,
            positions: displacedPositions,
            normals: &normals
        )

        try mesh.writeVertices(positions: displacedPositions, normals: normals)

        lastDriveSnapshot = drives.asSnapshot(
            beatEnvelope: beatEnvelope,
            peakDisplacement: peakDisplacement
        )
    }

    private func displacement(
        at base: SIMD3<Float>,
        audio: AudioFeatureSnapshot,
        bassDrive: Float,
        energyDrive: Float,
        beatDrive: Float,
        midsDrive: Float,
        highsDrive: Float,
        beatEnvelope: Float
    ) -> Float {
        let time = elapsedTime
        let waveSpeed = 1.0 + audio.bass * mapping.bassSpeedScale
        let radial = length(SIMD2(base.x, base.z))
        let halfExtent = DeformationConfiguration.gridWidth * 0.5
        let centerFalloff = max(0, 1 - radial / (halfExtent * 1.05))

        switch mode {
        case .ripple:
            let primary = sin((base.x * 5.0 + base.z * 3.8) + time * waveSpeed)
            let secondary = cos((base.x * 2.8 - base.z * 5.5) - time * (waveSpeed * 0.65))
            let body = (primary * 0.6 + secondary * 0.4) * (bassDrive * 5.0 + energyDrive * 1.8)

            let texture = sin((base.x + base.z) * 16 + time * 8) * midsDrive * 5.5
                + sin((base.x - base.z) * 24 + time * 12) * highsDrive * 4.0

            let beatSlap = beatDrive * (0.75 + 0.25 * primary) * (0.6 + 0.4 * beatEnvelope)
            return body + texture + beatSlap

        case .pulse:
            let ringSpeed = 2.2 + audio.bass * mapping.bassSpeedScale * 2.8
            let ring = sin(radial * 12 - time * ringSpeed)
            let body = ring * centerFalloff * (bassDrive * 4.5 + energyDrive * 3.5)

            let surgePhase = radial * 10 - time * (6 + beatEnvelope * 10)
            let beatSurge = beatDrive * centerFalloff * (0.85 + 0.15 * sin(surgePhase))

            let texture = sin(radial * 22 + time * 9) * midsDrive * 3.5
                + sin(radial * 34 - time * 13) * highsDrive * 2.5
            return body + beatSurge + texture

        case .twist:
            let twistRate = 0.7 + bassDrive * 6
            let twistAngle = twistRate * sin(time * 0.9 + radial * 4.5)
            let rotatedX = base.x * cos(twistAngle) - base.z * sin(twistAngle)
            let swirl = sin(rotatedX * 9 + time * 1.8) * (bassDrive * 4.0 + energyDrive * 2.2)
            let lift = sin(time * waveSpeed * 0.5 + radial * 3) * energyDrive * 1.5

            let beatBowl = beatDrive * centerFalloff * cos(radial * 8 - time * 4)

            let detail = sin(radial * 20 + time * 14) * midsDrive * 2.8
                + sin(time * 16 + base.x * 18) * highsDrive * 2.0
            return swirl + lift + beatBowl + detail
        }
    }

    private func recomputeNormals(
        segments: Int,
        positions: [SIMD3<Float>],
        normals: inout [SIMD3<Float>]
    ) {
        let columns = segments + 1

        for row in 0..<columns {
            for column in 0..<columns {
                let index = row * columns + column
                let left = column > 0 ? index - 1 : index
                let right = column < segments ? index + 1 : index
                let up = row > 0 ? index - columns : index
                let down = row < segments ? index + columns : index

                let dx = positions[right] - positions[left]
                let dz = positions[down] - positions[up]
                let normal = normalize(cross(dz, dx))
                normals[index] = normal.isFinite ? normal : SIMD3(0, 1, 0)
            }
        }
    }
}

private extension SIMD3 where Scalar == Float {
    var isFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite
    }
}
