import Accelerate
import Foundation

/// Performs Hann-windowed real FFT and extracts band energies via vDSP.
final class FFTAnalyzer {
    struct BandEnergies: Sendable {
        var bass: Float
        var mids: Float
        var highs: Float
        var rms: Float
    }

    private let fftSize: Int
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup

    private var window: [Float]
    private var windowedInput: [Float]
    private var realParts: [Float]
    private var imagParts: [Float]
    private var magnitudes: [Float]

    init(fftSize: Int = AudioAnalysisConfiguration.fftSize) {
        guard fftSize.isPowerOfTwo, fftSize >= 256 else {
            fatalError("FFT size must be a power of two >= 256")
        }

        self.fftSize = fftSize
        self.log2n = vDSP_Length(log2(Double(fftSize)))

        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            fatalError("Failed to create FFT setup")
        }
        self.fftSetup = setup

        window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        windowedInput = [Float](repeating: 0, count: fftSize)
        realParts = [Float](repeating: 0, count: fftSize / 2)
        imagParts = [Float](repeating: 0, count: fftSize / 2)
        magnitudes = [Float](repeating: 0, count: fftSize / 2)
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    /// Runs FFT on mono samples and returns raw (unnormalized) band energy sums and RMS.
    func analyze(samples: [Float], sampleRate: Float) -> BandEnergies {
        let sampleCount = min(samples.count, fftSize)
        guard sampleCount > 0, sampleRate > 0 else {
            return BandEnergies(bass: 0, mids: 0, highs: 0, rms: 0)
        }

        windowedInput.withUnsafeMutableBufferPointer { buffer in
            buffer.initialize(repeating: 0)
            for index in 0..<sampleCount {
                buffer[index] = samples[index]
            }
        }

        vDSP_vmul(windowedInput, 1, window, 1, &windowedInput, 1, vDSP_Length(fftSize))

        realParts.withUnsafeMutableBufferPointer { realBuffer in
            imagParts.withUnsafeMutableBufferPointer { imagBuffer in
                guard let realBase = realBuffer.baseAddress,
                      let imagBase = imagBuffer.baseAddress else {
                    return
                }

                var splitComplex = DSPSplitComplex(realp: realBase, imagp: imagBase)

                windowedInput.withUnsafeMutableBufferPointer { buffer in
                    guard let base = buffer.baseAddress else { return }
                    base.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPointer in
                        vDSP_ctoz(complexPointer, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                    }
                }

                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

                var scale = Float(1.0 / Float(fftSize))
                vDSP_vsmul(splitComplex.realp, 1, &scale, splitComplex.realp, 1, vDSP_Length(fftSize / 2))
                vDSP_vsmul(splitComplex.imagp, 1, &scale, splitComplex.imagp, 1, vDSP_Length(fftSize / 2))

                vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }

        let binWidth = sampleRate / Float(fftSize)
        var bass: Float = 0
        var mids: Float = 0
        var highs: Float = 0

        // Skip DC bin (index 0).
        for bin in 1..<(fftSize / 2) {
            let frequency = Float(bin) * binWidth
            let power = magnitudes[bin] * magnitudes[bin]

            if frequency < AudioAnalysisConfiguration.bassMaxHz {
                bass += power
            } else if frequency < AudioAnalysisConfiguration.midsMaxHz {
                mids += power
            } else {
                highs += power
            }
        }

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(sampleCount))

        return BandEnergies(bass: bass, mids: mids, highs: highs, rms: rms)
    }
}

private extension Int {
    var isPowerOfTwo: Bool {
        self > 0 && (self & (self - 1)) == 0
    }
}
