import SwiftUI

/// Internal ARWarp experience implementation used by the public `ARWarpView` wrapper.
struct ARWarpExperienceView: View {
    let configuration: ARWarpModuleConfiguration

    @StateObject private var sessionController = ARWarpSessionController()
    @StateObject private var audioEngine = AudioFeatureEngine()
    @StateObject private var deformationController: DeformationSceneController

    @Environment(\.scenePhase) private var scenePhase

    @State private var controlsPresented: Bool
    @State private var hasAutoCollapsedControls: Bool

    init(configuration: ARWarpModuleConfiguration = ARWarpModuleConfiguration()) {
        self.configuration = configuration
        _deformationController = StateObject(
            wrappedValue: DeformationSceneController(initialPresetID: configuration.initialPresetID)
        )
        _controlsPresented = State(initialValue: configuration.showsControlsInitially)
        _hasAutoCollapsedControls = State(initialValue: !configuration.autoCollapseControlsWhenRoomReady)
    }

    var body: some View {
        ZStack {
            ARWarpContainerView(
                controller: sessionController,
                deformationController: deformationController,
                audioEngine: audioEngine
            )

            atmosphereOverlay

            VStack(spacing: 12) {
                topChrome
                Spacer(minLength: 0)

                if let error = currentError {
                    errorCard(error)
                } else if !experienceStage.isLive && controlsPresented {
                    guideCard
                }

                bottomChrome
            }
            .padding(.vertical, 12)
        }
        .onAppear {
            audioEngine.start()
            publishStatusSnapshot(statusSnapshot)
        }
        .onDisappear {
            sessionController.detach()
            deformationController.detach()
            audioEngine.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                if sessionController.sessionState == .paused {
                    sessionController.resumeSession()
                } else if sessionController.sessionState.isActive {
                    audioEngine.resume()
                }
            case .inactive:
                audioEngine.pause()
            case .background:
                sessionController.pauseSession()
                audioEngine.stop()
            @unknown default:
                break
            }
        }
        .onChange(of: sessionController.sessionState) { _, newState in
            switch newState {
            case .running:
                if audioEngine.state == .paused || audioEngine.state == .stopped {
                    audioEngine.start()
                }
            case .paused, .failed, .unsupported:
                audioEngine.pause()
            case .initializing:
                break
            }
        }
        .onChange(of: sessionController.meshAnchorCount) { _, newCount in
            guard configuration.autoCollapseControlsWhenRoomReady else { return }
            guard newCount >= ARWarpConfiguration.meshAnchorGoalForLiveMode else { return }
            guard !hasAutoCollapsedControls, currentError == nil else { return }

            hasAutoCollapsedControls = true
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                controlsPresented = false
            }
        }
        .onChange(of: currentError != nil) { _, hasError in
            guard hasError else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                controlsPresented = true
            }
        }
        .onChange(of: statusSnapshot) { _, newSnapshot in
            publishStatusSnapshot(newSnapshot)
        }
    }

    private var topChrome: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ARWarp")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    chip(experienceStage.badge, tint: experienceStage.tint)
                    chip("\(sessionController.meshAnchorCount) anchors", tint: Color.white.opacity(0.18))

                    if audioEngine.state == .running {
                        chip(audioActivityLabel, tint: chromeAccent.opacity(0.22))
                    }
                }
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    controlsPresented.toggle()
                }
            } label: {
                Image(systemName: controlsPresented ? "slider.horizontal.3" : "waveform.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(chromeAccent.opacity(0.20), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private var guideCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(experienceStage.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(experienceStage.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()

                Image(systemName: experienceStage.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(experienceStage.tint)
            }

            progressRow(
                label: "Room read",
                value: roomReadiness,
                tint: chromeAccent
            )

            progressRow(
                label: "Audio read",
                value: audioReadiness,
                tint: experienceStage.tint
            )
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(experienceStage.tint.opacity(0.22), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private var bottomChrome: some View {
        VStack(spacing: 10) {
            if controlsPresented || shouldPinControls {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(deckTitle)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(deckSubtitle)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.68))
                        }

                        Spacer()

                        if !shouldPinControls {
                            Button("Hide") {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    controlsPresented = false
                                }
                            }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.plain)
                            .foregroundStyle(chromeAccent)
                        }
                    }

                    DeformationDebugPanel(
                        settings: deformationController.debugSettings,
                        driveSnapshot: deformationController.driveSnapshot,
                        sceneStats: deformationController.sceneStats,
                        isTestGridVisible: deformationController.isTestGridVisible,
                        showsPerformanceStats: configuration.showsPerformanceStats,
                        allowsAdvancedQAControls: configuration.allowsAdvancedQAControls,
                        onReposition: {
                            deformationController.repositionTestGrid()
                        },
                        accent: chromeAccent
                    )
                }
                .padding(18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(chromeAccent.opacity(0.18), lineWidth: 1)
                )
                .padding(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(experienceStage.badge)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(chromeAccent)
                        Text(collapsedDeckSummary)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.68))
                    }

                    Spacer()

                    Image(systemName: "chevron.up.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(chromeAccent.opacity(0.16), lineWidth: 1))
                .padding(.horizontal)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        controlsPresented = true
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: controlsPresented)
        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: shouldPinControls)
    }

    private func errorCard(_ error: ARWarpError) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
                Text("Warp Interrupted")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.22), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private func chip(_ label: String, tint: Color) -> some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint, in: Capsule())
    }

    private func progressRow(label: String, value: Float, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Text("\(Int(min(max(value, 0), 1) * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.72))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))

                    Capsule()
                        .fill(tint.gradient)
                        .frame(width: geometry.size.width * CGFloat(min(max(value, 0), 1)))
                }
            }
            .frame(height: 8)
        }
    }

    private var deckTitle: String {
        configuration.showsPerformanceStats ? "Performance Deck" : "Warp Controls"
    }

    private var deckSubtitle: String {
        if experienceStage.isLive {
            return "Room mesh is stable. Shape the motion, then collapse this deck."
        }
        return "Use this while scanning and tuning so the room can settle in."
    }

    private var collapsedDeckSummary: String {
        if configuration.showsPerformanceStats {
            return "\(deformationController.debugSettings.preset.displayName) • \(deformationController.sceneStats.activeChunks) live chunks"
        }
        return "\(deformationController.debugSettings.preset.displayName) preset"
    }

    private var presetAccent: Color {
        let accent = deformationController.debugSettings.preset.visualStyle.accentTint
        return Color(red: Double(accent.red), green: Double(accent.green), blue: Double(accent.blue))
    }

    private var chromeAccent: Color {
        if configuration.chromeTheme.followsPresetAccent {
            return presetAccent
        }

        let tint = configuration.chromeTheme.accentTint
        return Color(red: Double(tint.red), green: Double(tint.green), blue: Double(tint.blue))
    }

    private var overlayAccent: Color {
        if configuration.chromeTheme.followsPresetAccent {
            return presetAccent
        }

        let tint = configuration.chromeTheme.overlayTint
        return Color(red: Double(tint.red), green: Double(tint.green), blue: Double(tint.blue))
    }

    private var atmosphereOverlay: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.42),
                    .clear,
                    Color.black.opacity(0.26),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    overlayAccent.opacity(Double(0.18 * configuration.chromeTheme.overlayStrength)),
                    .clear,
                ],
                center: .bottom,
                startRadius: 20,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var roomReadiness: Float {
        min(
            Float(sessionController.meshAnchorCount) / Float(ARWarpConfiguration.meshAnchorGoalForLiveMode),
            1
        )
    }

    private var audioReadiness: Float {
        guard audioEngine.state == .running else { return 0 }

        return min(
            max(
                audioEngine.snapshot.energy * 0.55
                + audioEngine.snapshot.bass * 0.65
                + audioEngine.snapshot.beatStrength * 0.35,
                0
            ),
            1
        )
    }

    private var audioActivityLabel: String {
        let activity = max(audioEngine.snapshot.energy, audioEngine.snapshot.bass)
        switch activity {
        case ..<0.09: return "quiet"
        case ..<0.22: return "hearing motion"
        case ..<0.45: return "reactive"
        default: return "live pressure"
        }
    }

    private var currentError: ARWarpError? {
        sessionController.lastError ?? audioEngine.lastError ?? deformationController.lastError
    }

    private var shouldPinControls: Bool {
        currentError != nil
    }

    private var statusSnapshot: ARWarpStatusSnapshot {
        ARWarpStatusSnapshot(
            sessionState: sessionController.sessionState,
            meshAnchorCount: sessionController.meshAnchorCount,
            activePresetID: deformationController.debugSettings.presetID,
            isWarpEnabled: deformationController.debugSettings.isEnabled,
            isLive: experienceStage.isLive,
            lastError: currentError
        )
    }

    private func publishStatusSnapshot(_ snapshot: ARWarpStatusSnapshot) {
        configuration.onStatusChange?(snapshot)
    }

    private var experienceStage: ExperienceStage {
        if currentError != nil {
            return .recovery
        }

        switch sessionController.sessionState {
        case .initializing:
            return .booting
        case .paused:
            return .paused
        case .failed:
            return .recovery
        case .unsupported:
            return .unsupported
        case .running:
            break
        }

        if audioEngine.state == .permissionDenied {
            return .microphone
        }

        if roomReadiness < 0.55 {
            return .scanning
        }

        if audioEngine.state != .running {
            return .arming
        }

        if audioReadiness < ARWarpConfiguration.liveAudioThreshold {
            return .listening
        }

        return .live
    }
}

private extension ARWarpExperienceView {
    enum ExperienceStage {
        case booting
        case scanning
        case arming
        case listening
        case live
        case paused
        case microphone
        case unsupported
        case recovery

        var title: String {
            switch self {
            case .booting: return "Waking the room"
            case .scanning: return "Scan the room slowly"
            case .arming: return "Mic is getting ready"
            case .listening: return "Bring in sound"
            case .live: return "Warp is live"
            case .paused: return "Session paused"
            case .microphone: return "Microphone needed"
            case .unsupported: return "LiDAR device required"
            case .recovery: return "Need a quick recovery"
            }
        }

        var subtitle: String {
            switch self {
            case .booting:
                return "Starting AR session, audio analysis, and the deformation pipeline."
            case .scanning:
                return "Move with the walls and floor in frame until the mesh fills in."
            case .arming:
                return "Give the microphone a moment, then the room can start reacting."
            case .listening:
                return "Play music near the device so the room can lock onto energy and beat."
            case .live:
                return "The mesh is tracking and the room is reacting. Push intensity from the deck when needed."
            case .paused:
                return "Come back to the app to resume tracking and audio response."
            case .microphone:
                return "Enable microphone access in Settings so ARWarp can feel the music."
            case .unsupported:
                return "Scene reconstruction is only available on LiDAR-equipped iPhone Pro and iPad Pro hardware."
            case .recovery:
                return "Open the deck, check the error, and get the room stable before pushing harder."
            }
        }

        var badge: String {
            switch self {
            case .booting: return "booting"
            case .scanning: return "scanning"
            case .arming: return "arming"
            case .listening: return "listening"
            case .live: return "live"
            case .paused: return "paused"
            case .microphone: return "mic"
            case .unsupported: return "unsupported"
            case .recovery: return "recover"
            }
        }

        var symbol: String {
            switch self {
            case .booting: return "sparkles"
            case .scanning: return "viewfinder"
            case .arming: return "mic.badge.plus"
            case .listening: return "waveform"
            case .live: return "bolt.fill"
            case .paused: return "pause.circle.fill"
            case .microphone: return "mic.slash.fill"
            case .unsupported: return "iphone.slash"
            case .recovery: return "arrow.trianglehead.clockwise"
            }
        }

        var tint: Color {
            switch self {
            case .booting: return Color(red: 0.78, green: 0.88, blue: 1.0)
            case .scanning: return Color(red: 0.46, green: 0.89, blue: 0.98)
            case .arming: return Color(red: 0.99, green: 0.75, blue: 0.43)
            case .listening: return Color(red: 0.99, green: 0.55, blue: 0.36)
            case .live: return Color(red: 0.46, green: 0.89, blue: 0.98)
            case .paused: return Color.white.opacity(0.72)
            case .microphone, .unsupported, .recovery: return Color.orange
            }
        }

        var isLive: Bool {
            self == .live
        }
    }
}

#Preview {
    ARWarpView()
        .ignoresSafeArea()
}
