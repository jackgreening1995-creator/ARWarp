import Foundation

/// Tunable constants for the real-time audio analysis pipeline.
enum AudioAnalysisConfiguration {
    /// FFT and tap buffer length — power of two; 2048 gives good bass resolution at 48 kHz.
    static let fftSize = 2048

    /// Frequency band edges in Hz.
    static let bassMaxHz: Float = 250
    static let midsMaxHz: Float = 2000

    // MARK: Smoothing (tuning pass — per-band attack/release)

    /// Bass attack — fast enough to feel kick transients.
    static let bassAttackSmoothing: Float = 0.52
    /// Bass release — slow decay keeps low-end feeling weighty between hits.
    static let bassReleaseSmoothing: Float = 0.08

    static let energyAttackSmoothing: Float = 0.48
    static let energyReleaseSmoothing: Float = 0.11

    static let midsAttackSmoothing: Float = 0.42
    static let midsReleaseSmoothing: Float = 0.14

    /// Highs release faster so shimmer doesn't smear into mud.
    static let highsAttackSmoothing: Float = 0.55
    static let highsReleaseSmoothing: Float = 0.22

    /// Adaptive peak decay — slower falloff helps moderate playback levels stay reactive.
    static let peakDecay: Float = 0.996

    /// Minimum peak floor to avoid divide-by-zero and over-amplification of silence.
    static let peakFloor: Float = 0.000_5

    // MARK: Beat detection

    /// Energy must exceed smoothed baseline by this factor (lower = more sensitive).
    static let beatSensitivity: Float = 1.28

    /// Minimum interval between beat triggers (seconds).
    static let beatRefractoryPeriod: TimeInterval = 0.20

    /// Per audio-frame decay of `beatStrength` — faster = snappier visual beat input.
    static let beatStrengthDecay: Float = 0.58
}
