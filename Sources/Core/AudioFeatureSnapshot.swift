import Foundation

/// Immutable audio analysis snapshot consumed by the deformation pipeline.
/// Published by `AudioFeatureEngine` at analysis rate (~20–50 Hz depending on buffer size).
struct AudioFeatureSnapshot: Sendable, Equatable {
    /// Low-frequency energy (typically < 250 Hz), normalized 0…1.
    var bass: Float
    /// Mid-frequency energy (typically 250–2000 Hz), normalized 0…1.
    var mids: Float
    /// High-frequency energy (typically > 2000 Hz), normalized 0…1.
    var highs: Float
    /// Overall loudness (RMS), normalized 0…1.
    var energy: Float
    /// Whether a beat/onset was detected on this frame.
    var isBeat: Bool
    /// Beat strength 0…1 for deformation falloff (1.0 on onset, decays quickly).
    var beatStrength: Float
    /// Capture time for debugging and future AV ↔ AR sync.
    var timestamp: TimeInterval

    static let silent = AudioFeatureSnapshot(
        bass: 0,
        mids: 0,
        highs: 0,
        energy: 0,
        isBeat: false,
        beatStrength: 0,
        timestamp: 0
    )
}
