import Foundation

/// Applies asymmetric attack/release smoothing and adaptive peak normalization.
struct FeatureSmoother {
    private(set) var bass: Float = 0
    private(set) var mids: Float = 0
    private(set) var highs: Float = 0
    private(set) var energy: Float = 0

    private var peakBass: Float = AudioAnalysisConfiguration.peakFloor
    private var peakMids: Float = AudioAnalysisConfiguration.peakFloor
    private var peakHighs: Float = AudioAnalysisConfiguration.peakFloor
    private var peakEnergy: Float = AudioAnalysisConfiguration.peakFloor

    mutating func process(rawBass: Float, rawMids: Float, rawHighs: Float, rawEnergy: Float) -> (bass: Float, mids: Float, highs: Float, energy: Float) {
        peakBass = max(rawBass, peakBass * AudioAnalysisConfiguration.peakDecay)
        peakMids = max(rawMids, peakMids * AudioAnalysisConfiguration.peakDecay)
        peakHighs = max(rawHighs, peakHighs * AudioAnalysisConfiguration.peakDecay)
        peakEnergy = max(rawEnergy, peakEnergy * AudioAnalysisConfiguration.peakDecay)

        let normalizedBass = clamp01(rawBass / peakBass)
        let normalizedMids = clamp01(rawMids / peakMids)
        let normalizedHighs = clamp01(rawHighs / peakHighs)
        let normalizedEnergy = clamp01(rawEnergy / peakEnergy)

        bass = smooth(
            current: bass,
            target: normalizedBass,
            attack: AudioAnalysisConfiguration.bassAttackSmoothing,
            release: AudioAnalysisConfiguration.bassReleaseSmoothing
        )
        energy = smooth(
            current: energy,
            target: normalizedEnergy,
            attack: AudioAnalysisConfiguration.energyAttackSmoothing,
            release: AudioAnalysisConfiguration.energyReleaseSmoothing
        )
        mids = smooth(
            current: mids,
            target: normalizedMids,
            attack: AudioAnalysisConfiguration.midsAttackSmoothing,
            release: AudioAnalysisConfiguration.midsReleaseSmoothing
        )
        highs = smooth(
            current: highs,
            target: normalizedHighs,
            attack: AudioAnalysisConfiguration.highsAttackSmoothing,
            release: AudioAnalysisConfiguration.highsReleaseSmoothing
        )

        return (bass, mids, highs, energy)
    }

    mutating func reset() {
        bass = 0
        mids = 0
        highs = 0
        energy = 0
        peakBass = AudioAnalysisConfiguration.peakFloor
        peakMids = AudioAnalysisConfiguration.peakFloor
        peakHighs = AudioAnalysisConfiguration.peakFloor
        peakEnergy = AudioAnalysisConfiguration.peakFloor
    }

    private func smooth(current: Float, target: Float, attack: Float, release: Float) -> Float {
        let alpha = target > current ? attack : release
        return current + alpha * (target - current)
    }

    private func clamp01(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}

/// Onset detector emphasizing bass transients with a snappy strength decay.
struct BeatDetector {
    private var smoothedEnergy: Float = 0
    private var previousBass: Float = 0
    private var lastBeatTime: TimeInterval = 0
    private(set) var beatStrength: Float = 0

    mutating func process(energy: Float, bass: Float, timestamp: TimeInterval) -> Bool {
        if energy > smoothedEnergy {
            smoothedEnergy += 0.42 * (energy - smoothedEnergy)
        } else {
            smoothedEnergy += 0.09 * (energy - smoothedEnergy)
        }

        let flux = energy - smoothedEnergy
        let bassRise = bass - previousBass
        previousBass = bass

        let refractoryElapsed = timestamp - lastBeatTime
        let aboveThreshold = flux > 0.06
            && energy > smoothedEnergy * AudioAnalysisConfiguration.beatSensitivity
        // Lower bass floor so moderate-volume kicks still register.
        let bassHit = bassRise > 0.035 && bass > 0.16
        let isBeat = (aboveThreshold || bassHit)
            && refractoryElapsed >= AudioAnalysisConfiguration.beatRefractoryPeriod

        if isBeat {
            lastBeatTime = timestamp
            beatStrength = 1
            return true
        }

        beatStrength *= AudioAnalysisConfiguration.beatStrengthDecay
        return false
    }

    mutating func reset() {
        smoothedEnergy = 0
        previousBass = 0
        lastBeatTime = 0
        beatStrength = 0
    }
}
