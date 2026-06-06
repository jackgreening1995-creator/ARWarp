import AVFoundation
import Combine
import Foundation

/// Lifecycle state of the audio analysis engine.
enum AudioEngineState: String, Sendable {
    case stopped
    case requestingPermission
    case running
    case paused
    case permissionDenied
    case failed

    var displayName: String {
        rawValue.capitalized
    }
}

/// Real-time microphone capture, FFT analysis, and musical feature extraction.
///
/// Heavy work runs on a dedicated analysis queue; `@Published` snapshots update on the main thread.
/// Designed to feed the deformation pipeline via `AudioFeatureSnapshot` without further refactoring.
final class AudioFeatureEngine: ObservableObject {
    @Published private(set) var snapshot: AudioFeatureSnapshot = .silent
    @Published private(set) var state: AudioEngineState = .stopped
    @Published private(set) var lastError: ARWarpError?

    /// Optional callback for non-SwiftUI consumers (e.g. future deformation pipeline).
    var onSnapshot: ((AudioFeatureSnapshot) -> Void)?

    private let audioEngine = AVAudioEngine()
    private let analysisQueue = DispatchQueue(label: "com.arwarp.audio.analysis", qos: .userInteractive)

    private var fftAnalyzer = FFTAnalyzer()
    private var featureSmoother = FeatureSmoother()
    private var beatDetector = BeatDetector()

    private var isTapInstalled = false
    private var shouldRunAfterPermission = false
    private var shouldResumeAfterInterruption = false
    private var notificationObservers: [NSObjectProtocol] = []

    init() {
        registerForSessionNotifications()
    }

    deinit {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    /// Requests microphone permission (if needed) and starts capture + analysis.
    func start() {
        guard state != .running, state != .requestingPermission else { return }
        shouldRunAfterPermission = true
        lastError = nil

        requestMicrophonePermission { [weak self] granted in
            guard let self else { return }
            guard self.shouldRunAfterPermission else { return }

            if granted {
                self.analysisQueue.async {
                    self.startEngineOnAnalysisQueue()
                }
            } else {
                DispatchQueue.main.async {
                    self.state = .permissionDenied
                    self.lastError = .microphonePermissionDenied
                    self.shouldRunAfterPermission = false
                }
            }
        }
    }

    /// Stops capture and resets analysis state.
    func stop() {
        shouldRunAfterPermission = false

        analysisQueue.async { [weak self] in
            self?.stopEngineOnAnalysisQueue()
        }
    }

    /// Pauses analysis while keeping permission state; used when AR session pauses.
    func pause() {
        guard state == .running else { return }

        analysisQueue.async { [weak self] in
            self?.stopEngineOnAnalysisQueue(resetFeatures: true)
            DispatchQueue.main.async {
                self?.state = .paused
            }
        }
    }

    /// Resumes analysis after `pause()`.
    func resume() {
        guard state == .paused else { return }
        start()
    }

    // MARK: - Permission

    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async { [weak self] in
            self?.state = .requestingPermission
        }

        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                completion(granted)
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                completion(granted)
            }
        }
    }

    // MARK: - Engine lifecycle (analysis queue only)

    private func startEngineOnAnalysisQueue() {
        stopEngineOnAnalysisQueue(resetFeatures: false)

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker, .mixWithOthers, .allowBluetoothHFP]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            let bufferSize = AVAudioFrameCount(AudioAnalysisConfiguration.fftSize)

            // Remove any stale tap before installing.
            if isTapInstalled {
                inputNode.removeTap(onBus: 0)
                isTapInstalled = false
            }

            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
                self?.handleAudioBuffer(buffer)
            }
            isTapInstalled = true

            try audioEngine.start()

            DispatchQueue.main.async { [weak self] in
                self?.state = .running
                self?.lastError = nil
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.state = .failed
                self?.lastError = .audioEngineUnavailable
                self?.shouldRunAfterPermission = false
            }
        }
    }

    private func stopEngineOnAnalysisQueue(resetFeatures: Bool = true) {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }

        audioEngine.reset()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        if resetFeatures {
            featureSmoother.reset()
            beatDetector.reset()
            publishSnapshot(.silent)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.state != .permissionDenied, self.state != .failed {
                self.state = .stopped
            }
        }
    }

    // MARK: - Audio tap (real-time thread — keep minimal)

    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        let channelCount = Int(buffer.format.channelCount)
        let sampleRate = Float(buffer.format.sampleRate)

        // Copy mono samples quickly on the audio thread, then analyze off-thread.
        var monoSamples = [Float](repeating: 0, count: frameLength)

        if channelCount == 1 {
            monoSamples.withUnsafeMutableBufferPointer { destination in
                guard let base = destination.baseAddress else { return }
                base.update(from: channelData[0], count: frameLength)
            }
        } else {
            for index in 0..<frameLength {
                var sum: Float = 0
                for channel in 0..<channelCount {
                    sum += channelData[channel][index]
                }
                monoSamples[index] = sum / Float(channelCount)
            }
        }

        analysisQueue.async { [weak self] in
            self?.processSamples(monoSamples, sampleRate: sampleRate)
        }
    }

    private func processSamples(_ samples: [Float], sampleRate: Float) {
        let raw = fftAnalyzer.analyze(samples: samples, sampleRate: sampleRate)

        // Compress wide dynamic range before normalization.
        let logBass = log10(max(raw.bass, 1e-12))
        let logMids = log10(max(raw.mids, 1e-12))
        let logHighs = log10(max(raw.highs, 1e-12))
        let logEnergy = log10(max(raw.rms, 1e-6))

        let smoothed = featureSmoother.process(
            rawBass: logBass + 12,
            rawMids: logMids + 12,
            rawHighs: logHighs + 12,
            rawEnergy: logEnergy + 6
        )

        let timestamp = Date().timeIntervalSince1970
        let isBeat = beatDetector.process(energy: smoothed.energy, bass: smoothed.bass, timestamp: timestamp)

        let newSnapshot = AudioFeatureSnapshot(
            bass: smoothed.bass,
            mids: smoothed.mids,
            highs: smoothed.highs,
            energy: smoothed.energy,
            isBeat: isBeat,
            beatStrength: beatDetector.beatStrength,
            timestamp: timestamp
        )

        publishSnapshot(newSnapshot)
    }

    private func publishSnapshot(_ newSnapshot: AudioFeatureSnapshot) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.snapshot = newSnapshot
            self.onSnapshot?(newSnapshot)
        }
    }

    private func registerForSessionNotifications() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        notificationObservers.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: session,
                queue: nil
            ) { [weak self] notification in
                self?.handleSessionInterruption(notification)
            }
        )

        notificationObservers.append(
            center.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification,
                object: session,
                queue: nil
            ) { [weak self] _ in
                self?.handleMediaServicesReset()
            }
        )
    }

    private func handleSessionInterruption(_ notification: Notification) {
        guard
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else {
            return
        }

        switch type {
        case .began:
            guard state == .running else { return }
            shouldResumeAfterInterruption = shouldRunAfterPermission
            pause()

        case .ended:
            guard shouldResumeAfterInterruption else { return }
            shouldResumeAfterInterruption = false

            let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            guard options.contains(.shouldResume) else { return }

            analysisQueue.async { [weak self] in
                guard let self, self.shouldRunAfterPermission else { return }
                self.startEngineOnAnalysisQueue()
            }

        @unknown default:
            break
        }
    }

    private func handleMediaServicesReset() {
        guard shouldRunAfterPermission else { return }

        analysisQueue.async { [weak self] in
            guard let self else { return }
            self.startEngineOnAnalysisQueue()
        }
    }
}
