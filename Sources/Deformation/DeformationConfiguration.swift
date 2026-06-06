import Foundation

/// Tunable mapping from `AudioFeatureSnapshot` to vertex displacement.
///
/// Tuning notes (post–Phase 3 pass):
/// - Bass is weighted heaviest; highs are deliberately subtle so detail doesn't read as noise.
/// - `beatDecayTime` controls visual snap (short = punchy kick, not lingering wobble).
/// - `quietLevelBoost` lifts moderate-volume playback so the grid still feels alive without max gain.
struct AudioDeformationMapping: Sendable, Equatable {
    /// Master multiplier applied to all displacement.
    var masterIntensity: Float = 1.16

    // MARK: Band weights

    /// Bass scales primary wave amplitude and wave speed — the "weight" of the motion.
    var bassAmplitudeScale: Float = 0.23
    var bassSpeedScale: Float = 1.48

    /// Energy scales overall displacement; kept slightly below bass so kicks read as bass-led.
    var energyIntensityScale: Float = 0.18

    /// Beat envelope peak height — paired with `beatDecayTime` for snappy pulses.
    var beatPulseScale: Float = 0.29

    /// Mids add texture; boosted slightly so guitars/vocals register without dominating.
    var midsRippleScale: Float = 0.074

    /// Highs add sparkle; kept lower than mids to avoid nervous jitter.
    var highsRippleScale: Float = 0.031

    // MARK: Envelope & smoothing

    /// Seconds for beat-driven displacement to decay after a hit (short = snappy).
    var beatDecayTime: Float = 0.14

    /// Drive smoothing time constants (seconds) — decouples visual motion from raw FFT jitter.
    var driveAttackTime: Float = 0.026
    var driveReleaseTime: Float = 0.11

    /// Extra gain when overall level is moderate/quiet (0 = off, ~0.4 = noticeable lift).
    var quietLevelBoost: Float = 0.62

    /// Energy level below which quiet boost ramps in.
    var quietLevelThreshold: Float = 0.50

    static let `default` = AudioDeformationMapping()
}

extension AudioDeformationMapping {
    func overriding(
        masterIntensity: Float,
        bassAmplitudeScale: Float,
        beatPulseScale: Float,
        beatDecayTime: Float
    ) -> AudioDeformationMapping {
        var copy = self
        copy.masterIntensity = masterIntensity
        copy.bassAmplitudeScale = bassAmplitudeScale
        copy.beatPulseScale = beatPulseScale
        copy.beatDecayTime = beatDecayTime
        return copy
    }
}

/// Grid and placement settings for the Phase 3 test deformable mesh.
enum DeformationConfiguration {
    /// Subdivisions per axis (vertex count = (segments + 1)²).
    static let gridSegments = 48

    /// Physical size of the test plane in meters.
    static let gridWidth: Float = 0.65
    static let gridDepth: Float = 0.65

    /// Distance in front of the camera for initial placement (meters).
    static let placementDistance: Float = 0.75

    /// Default audio → displacement mapping.
    static let defaultMapping = AudioDeformationMapping.default
}
