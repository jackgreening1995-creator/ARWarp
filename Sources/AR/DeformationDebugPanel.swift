import SwiftUI

/// Live controls and drive-value readout for scene + test-grid deformation.
struct DeformationDebugPanel: View {
    @ObservedObject var settings: DeformationDebugSettings
    let driveSnapshot: DeformationDriveSnapshot
    let sceneStats: SceneDeformationStats
    let isTestGridVisible: Bool
    let showsPerformanceStats: Bool
    let allowsAdvancedQAControls: Bool
    let onReposition: () -> Void
    var accent: Color = Color(red: 0.2, green: 0.85, blue: 0.95)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Preset Deck")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text(statusLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(accent)
            }

            Toggle("Warp On", isOn: $settings.isEnabled)
                .font(.caption)
                .tint(accent)

            Picker(
                "Preset",
                selection: Binding(
                    get: { settings.presetID },
                    set: { settings.selectPreset($0) }
                )
            ) {
                ForEach(WarpPresetID.allCases) { presetID in
                    Text(WarpPresetRegistry.preset(for: presetID).displayName).tag(presetID)
                }
            }
            .pickerStyle(.segmented)

            Text(settings.preset.summary)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)

            sliderRow(label: "Intensity", value: $settings.masterIntensity, range: 0...2.4, format: "%.2f×")

            if showsPerformanceStats || allowsAdvancedQAControls {
                Divider().overlay(Color.white.opacity(0.15))
            }

            if showsPerformanceStats {
                sceneStatRow(label: "Room chunks", value: "\(sceneStats.activeChunks)/\(sceneStats.totalChunks)")
                sceneStatRow(label: "GPU time", value: String(format: "%.1f ms", sceneStats.gpuFrameMilliseconds))
                sceneStatRow(label: "Audio response", value: String(format: "%.2f", driveSnapshot.visualResponse))
                driveRow(label: "Beat tail", value: driveSnapshot.beatEnvelope)
            }

            if allowsAdvancedQAControls {
                DisclosureGroup(isExpanded: $settings.showsAdvancedQA) {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Target", selection: $settings.deformationTarget) {
                            ForEach(DeformationTarget.allCases) { target in
                                Text(target.displayName).tag(target)
                            }
                        }
                        .pickerStyle(.segmented)

                        sliderRow(label: "Beat punch", value: $settings.beatPulseScale, range: 0.05...0.40, format: "%.2f")
                        sliderRow(label: "Bass weight", value: $settings.bassAmplitudeScale, range: 0.08...0.30, format: "%.2f")
                        sliderRow(label: "Beat decay", value: $settings.beatDecayTime, range: 0.05...0.25, format: "%.2fs")

                        if showsPerformanceStats {
                            Divider().overlay(Color.white.opacity(0.12))

                            sceneStatRow(label: "Live verts", value: "\(sceneStats.deformedVertices)")
                            driveRow(label: "Bass drive", value: driveSnapshot.bassContribution)
                            driveRow(label: "Body drive", value: driveSnapshot.energyContribution)
                            driveRow(label: "Beat drive", value: driveSnapshot.beatContribution)
                            driveRow(label: "Probe peak", value: isTestGridVisible ? driveSnapshot.peakDisplacement : 0, emptyWhenZero: !isTestGridVisible)
                        }

                        if settings.deformationTarget != .sceneMesh {
                            Button("Reposition Grid", action: onReposition)
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.borderedProminent)
                                .tint(accent.opacity(0.85))
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    Text("Advanced QA")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accent)
                }
            }
        }
        .frame(maxWidth: 280)
    }

    private var statusLabel: String {
        guard settings.isEnabled else { return "Warp Off" }
        switch settings.deformationTarget {
            case .sceneMesh: return sceneStats.totalChunks > 0 ? "Room Live" : "Scanning…"
            case .testGrid: return isTestGridVisible ? "Probe Live" : "Probe Hidden"
            case .both: return "Split View"
        }
    }

    private func sliderRow(label: String, value: Binding<Float>, range: ClosedRange<Float>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(accent)
            }
            Slider(value: value, in: range)
                .tint(accent)
        }
    }

    private func sceneStatRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
            Spacer()
            Text(value)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(accent.opacity(0.9))
        }
    }

    private func driveRow(label: String, value: Float, emptyWhenZero: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
            Spacer()
            Text(emptyWhenZero && value == 0 ? "—" : String(format: "%.3f", value))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

private extension DeformationDriveSnapshot {
    var visualResponse: Float {
        min(
            max(
                bassContribution * 1.8
                + energyContribution * 2.2
                + beatContribution * 2.8
                + highsContribution * 0.6,
                0
            ),
            1
        )
    }
}

#Preview {
    ZStack {
        Color.black
        DeformationDebugPanel(
            settings: DeformationDebugSettings(),
            driveSnapshot: DeformationDriveSnapshot(
                bassContribution: 0.10,
                beatContribution: 0.08,
                peakDisplacement: 0.048,
                beatEnvelope: 0.72
            ),
            sceneStats: SceneDeformationStats(
                totalChunks: 12,
                activeChunks: 6,
                deformedVertices: 18_400,
                gpuFrameMilliseconds: 2.4
            ),
            isTestGridVisible: false,
            showsPerformanceStats: true,
            allowsAdvancedQAControls: true,
            onReposition: {}
        )
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }
}
