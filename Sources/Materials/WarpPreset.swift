import Foundation

struct WarpColor: Sendable, Equatable {
    var red: Float
    var green: Float
    var blue: Float

    init(red: Float, green: Float, blue: Float) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
    }

    func mixed(with other: WarpColor, amount: Float) -> WarpColor {
        let mix = Self.clamp(amount)
        return WarpColor(
            red: red + (other.red - red) * mix,
            green: green + (other.green - green) * mix,
            blue: blue + (other.blue - blue) * mix
        )
    }

    private static func clamp(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

public enum WarpPresetID: String, CaseIterable, Identifiable, Sendable {
    case flow
    case fracture

    public var id: String { rawValue }
}

struct WarpVisualStyle: Sendable, Equatable {
    let baseTint: WarpColor
    let accentTint: WarpColor
    let glowTint: WarpColor
    let scanOpacity: Float
    let activeOpacity: Float
    let retiringOpacity: Float
    let opacityResponseBoost: Float
    let scanTintMix: Float
    let activeTintMix: Float
    let responseTintBoost: Float
    let scanRoughness: Float
    let activeRoughness: Float
    let retiringRoughness: Float
    let metallic: Float
    let clearcoat: Float
    let clearcoatRoughness: Float
    let scanEmissive: Float
    let activeEmissiveBase: Float
    let activeEmissiveBoost: Float
    let retiringEmissive: Float
    let gridOpacity: Float
    let gridRoughness: Float
    let gridEmissiveBase: Float
    let gridEmissiveBoost: Float

    init(
        baseTint: WarpColor,
        accentTint: WarpColor,
        glowTint: WarpColor,
        scanOpacity: Float,
        activeOpacity: Float,
        retiringOpacity: Float,
        opacityResponseBoost: Float,
        scanTintMix: Float,
        activeTintMix: Float,
        responseTintBoost: Float,
        scanRoughness: Float,
        activeRoughness: Float,
        retiringRoughness: Float,
        metallic: Float,
        clearcoat: Float,
        clearcoatRoughness: Float,
        scanEmissive: Float,
        activeEmissiveBase: Float,
        activeEmissiveBoost: Float,
        retiringEmissive: Float,
        gridOpacity: Float,
        gridRoughness: Float,
        gridEmissiveBase: Float,
        gridEmissiveBoost: Float
    ) {
        self.baseTint = baseTint
        self.accentTint = accentTint
        self.glowTint = glowTint
        self.scanOpacity = Self.clamp(scanOpacity)
        self.activeOpacity = Self.clamp(activeOpacity)
        self.retiringOpacity = Self.clamp(retiringOpacity)
        self.opacityResponseBoost = Self.clamp(opacityResponseBoost)
        self.scanTintMix = Self.clamp(scanTintMix)
        self.activeTintMix = Self.clamp(activeTintMix)
        self.responseTintBoost = Self.clamp(responseTintBoost)
        self.scanRoughness = Self.clamp(scanRoughness)
        self.activeRoughness = Self.clamp(activeRoughness)
        self.retiringRoughness = Self.clamp(retiringRoughness)
        self.metallic = Self.clamp(metallic)
        self.clearcoat = Self.clamp(clearcoat)
        self.clearcoatRoughness = Self.clamp(clearcoatRoughness)
        self.scanEmissive = Self.clamp(scanEmissive)
        self.activeEmissiveBase = Self.clamp(activeEmissiveBase)
        self.activeEmissiveBoost = Self.clamp(activeEmissiveBoost)
        self.retiringEmissive = Self.clamp(retiringEmissive)
        self.gridOpacity = Self.clamp(gridOpacity)
        self.gridRoughness = Self.clamp(gridRoughness)
        self.gridEmissiveBase = Self.clamp(gridEmissiveBase)
        self.gridEmissiveBoost = Self.clamp(gridEmissiveBoost)
    }

    private static func clamp(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

struct WarpPreset: Sendable, Equatable {
    let id: WarpPresetID
    let displayName: String
    let summary: String
    let motionKernel: DisplacementMode
    let defaultMapping: AudioDeformationMapping
    let visualStyle: WarpVisualStyle
}

enum WarpPresetRegistry {
    static let defaultPresetID: WarpPresetID = .flow

    static let allPresets: [WarpPreset] = [
        flowPreset,
        fracturePreset,
    ]

    static var defaultPreset: WarpPreset {
        preset(for: defaultPresetID)
    }

    static func preset(for id: WarpPresetID) -> WarpPreset {
        allPresets.first { $0.id == id } ?? flowPreset
    }

    private static let baseTint = WarpColor(
        red: ARWarpConfiguration.debugMeshColor.red,
        green: ARWarpConfiguration.debugMeshColor.green,
        blue: ARWarpConfiguration.debugMeshColor.blue
    )

    private static let flowPreset = WarpPreset(
        id: .flow,
        displayName: "Flow",
        summary: "A smoother, translucent room pulse with bass-led motion and soft luminous edges.",
        motionKernel: .ripple,
        defaultMapping: AudioDeformationMapping(
            masterIntensity: 1.02,
            bassAmplitudeScale: 0.20,
            bassSpeedScale: 1.18,
            energyIntensityScale: 0.16,
            beatPulseScale: 0.19,
            midsRippleScale: 0.084,
            highsRippleScale: 0.038,
            beatDecayTime: 0.18,
            driveAttackTime: 0.032,
            driveReleaseTime: 0.14,
            quietLevelBoost: 0.50,
            quietLevelThreshold: 0.52
        ),
        visualStyle: WarpVisualStyle(
            baseTint: baseTint,
            accentTint: WarpColor(red: 0.42, green: 0.89, blue: 0.98),
            glowTint: WarpColor(red: 0.80, green: 0.96, blue: 1.0),
            scanOpacity: 0.13,
            activeOpacity: 0.24,
            retiringOpacity: 0.18,
            opacityResponseBoost: 0.05,
            scanTintMix: 0.22,
            activeTintMix: 0.54,
            responseTintBoost: 0.18,
            scanRoughness: 0.30,
            activeRoughness: 0.16,
            retiringRoughness: 0.34,
            metallic: 0.05,
            clearcoat: 0.92,
            clearcoatRoughness: 0.14,
            scanEmissive: 0.10,
            activeEmissiveBase: 0.26,
            activeEmissiveBoost: 0.62,
            retiringEmissive: 0.12,
            gridOpacity: 0.46,
            gridRoughness: 0.22,
            gridEmissiveBase: 0.14,
            gridEmissiveBoost: 0.36
        )
    )

    private static let fracturePreset = WarpPreset(
        id: .fracture,
        displayName: "Fracture",
        summary: "A sharper beat-first burst with brighter seams, stronger shockwaves, and hotter highlights.",
        motionKernel: .pulse,
        defaultMapping: AudioDeformationMapping(
            masterIntensity: 1.20,
            bassAmplitudeScale: 0.27,
            bassSpeedScale: 1.82,
            energyIntensityScale: 0.21,
            beatPulseScale: 0.34,
            midsRippleScale: 0.060,
            highsRippleScale: 0.028,
            beatDecayTime: 0.10,
            driveAttackTime: 0.020,
            driveReleaseTime: 0.095,
            quietLevelBoost: 0.66,
            quietLevelThreshold: 0.48
        ),
        visualStyle: WarpVisualStyle(
            baseTint: baseTint,
            accentTint: WarpColor(red: 1.0, green: 0.54, blue: 0.34),
            glowTint: WarpColor(red: 1.0, green: 0.83, blue: 0.60),
            scanOpacity: 0.15,
            activeOpacity: 0.30,
            retiringOpacity: 0.22,
            opacityResponseBoost: 0.09,
            scanTintMix: 0.20,
            activeTintMix: 0.72,
            responseTintBoost: 0.20,
            scanRoughness: 0.28,
            activeRoughness: 0.10,
            retiringRoughness: 0.30,
            metallic: 0.09,
            clearcoat: 1.0,
            clearcoatRoughness: 0.12,
            scanEmissive: 0.13,
            activeEmissiveBase: 0.44,
            activeEmissiveBoost: 0.96,
            retiringEmissive: 0.16,
            gridOpacity: 0.52,
            gridRoughness: 0.18,
            gridEmissiveBase: 0.22,
            gridEmissiveBoost: 0.50
        )
    )
}
