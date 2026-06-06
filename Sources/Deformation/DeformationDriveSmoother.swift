import Foundation

/// Smooths raw audio drives before they reach displacement math — shared by CPU grid and GPU scene paths.
struct DeformationDriveSmoother {
    private(set) var beatEnvelope: Float = 0

    private var bass: Float = 0
    private var energy: Float = 0
    private var mids: Float = 0
    private var highs: Float = 0

    mutating func update(
        audio: AudioFeatureSnapshot,
        mapping: AudioDeformationMapping,
        deltaTime: Float
    ) -> DeformationDriveValues {
        if audio.isBeat {
            beatEnvelope = 1
        } else {
            beatEnvelope *= exp(-deltaTime / max(mapping.beatDecayTime, 0.01))
        }

        let beatTarget = max(beatEnvelope, audio.beatStrength * 0.85)
        let intensity = max(mapping.masterIntensity, 0)

        var bassDrive = audio.bass * mapping.bassAmplitudeScale * intensity
        var energyDrive = audio.energy * mapping.energyIntensityScale * intensity
        var midsDrive = audio.mids * mapping.midsRippleScale * intensity
        var highsDrive = audio.highs * mapping.highsRippleScale * intensity
        let beatDrive = beatTarget * mapping.beatPulseScale * intensity

        let level = max(audio.energy, audio.bass)
        let quietThreshold = mapping.quietLevelThreshold
        let levelGain: Float
        if level < quietThreshold, quietThreshold > 0 {
            levelGain = 1 + mapping.quietLevelBoost * (1 - level / quietThreshold)
        } else {
            levelGain = 1
        }

        bassDrive *= levelGain
        energyDrive *= levelGain
        midsDrive *= levelGain
        highsDrive *= levelGain

        bass = smoothDrive(bass, target: bassDrive, mapping: mapping, deltaTime: deltaTime)
        energy = smoothDrive(energy, target: energyDrive, mapping: mapping, deltaTime: deltaTime)
        mids = smoothDrive(mids, target: midsDrive, mapping: mapping, deltaTime: deltaTime)
        highs = smoothDrive(highs, target: highsDrive, mapping: mapping, deltaTime: deltaTime)

        return DeformationDriveValues(
            bass: bass,
            energy: energy,
            mids: mids,
            highs: highs,
            beat: beatDrive,
            levelGain: levelGain
        )
    }

    mutating func reset() {
        bass = 0
        energy = 0
        mids = 0
        highs = 0
        beatEnvelope = 0
    }

    private func smoothDrive(
        _ current: Float,
        target: Float,
        mapping: AudioDeformationMapping,
        deltaTime: Float
    ) -> Float {
        let tau = target > current ? mapping.driveAttackTime : mapping.driveReleaseTime
        let alpha = 1 - exp(-deltaTime / max(tau, 0.001))
        return current + alpha * (target - current)
    }
}

/// Smoothed audio drives consumed by CPU and Metal deformation paths.
struct DeformationDriveValues: Sendable, Equatable {
    var bass: Float
    var energy: Float
    var mids: Float
    var highs: Float
    var beat: Float
    var levelGain: Float

    static let zero = DeformationDriveValues(
        bass: 0,
        energy: 0,
        mids: 0,
        highs: 0,
        beat: 0,
        levelGain: 1
    )
}

extension DeformationDriveValues {
    var visualResponse: Float {
        min(
            max(
                bass * 1.8
                + energy * 2.2
                + beat * 2.8
                + highs * 0.6,
                0
            ),
            1
        )
    }

    func asSnapshot(beatEnvelope: Float, peakDisplacement: Float = 0) -> DeformationDriveSnapshot {
        DeformationDriveSnapshot(
            bassContribution: bass,
            energyContribution: energy,
            beatContribution: beat,
            midsContribution: mids,
            highsContribution: highs,
            peakDisplacement: peakDisplacement,
            beatEnvelope: beatEnvelope,
            levelGain: levelGain
        )
    }
}
