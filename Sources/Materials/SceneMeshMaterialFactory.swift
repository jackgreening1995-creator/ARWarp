import RealityKit
import UIKit

enum WarpMeshVisualPhase {
    case scan
    case active
    case retiring
}

enum SceneMeshMaterialFactory {
    static func makeRoomMaterial(
        style: WarpVisualStyle,
        phase: WarpMeshVisualPhase,
        response: Float,
        scanCompletion: Float,
        visibilityWeight: Float
    ) -> Material {
        let clampedVisibility = clamp(visibilityWeight)
        let tint: WarpColor
        let opacity: Float
        let roughness: Float
        let emissiveIntensity: Float

        switch phase {
        case .scan:
            tint = style.baseTint.mixed(
                with: style.accentTint,
                amount: style.scanTintMix + scanCompletion * 0.16
            )
            opacity = style.scanOpacity * clampedVisibility
            roughness = style.scanRoughness
            emissiveIntensity = style.scanEmissive + scanCompletion * 0.14

        case .active:
            tint = style.baseTint.mixed(
                with: style.accentTint,
                amount: style.activeTintMix + response * style.responseTintBoost
            )
            opacity = min(
                style.activeOpacity + response * style.opacityResponseBoost,
                0.42
            ) * clampedVisibility
            roughness = style.activeRoughness
            emissiveIntensity = style.activeEmissiveBase + response * style.activeEmissiveBoost

        case .retiring:
            tint = style.baseTint.mixed(
                with: style.accentTint,
                amount: style.scanTintMix + response * style.responseTintBoost * 0.4
            )
            opacity = style.retiringOpacity * clampedVisibility
            roughness = style.retiringRoughness
            emissiveIntensity = style.retiringEmissive + response * style.activeEmissiveBoost * 0.18
        }

        return makeMaterial(
            tint: tint,
            glow: style.glowTint,
            opacity: opacity,
            roughness: roughness,
            metallic: style.metallic,
            clearcoat: style.clearcoat,
            clearcoatRoughness: style.clearcoatRoughness,
            emissiveIntensity: emissiveIntensity
        )
    }

    static func makeGridMaterial(
        style: WarpVisualStyle,
        response: Float,
        visibilityWeight: Float = 1
    ) -> Material {
        let tint = style.baseTint.mixed(
            with: style.accentTint,
            amount: style.activeTintMix + response * style.responseTintBoost
        )
        let opacity = min(style.gridOpacity + response * 0.12, 0.72) * clamp(visibilityWeight)
        let emissiveIntensity = style.gridEmissiveBase + response * style.gridEmissiveBoost

        return makeMaterial(
            tint: tint,
            glow: style.glowTint,
            opacity: opacity,
            roughness: style.gridRoughness,
            metallic: style.metallic,
            clearcoat: style.clearcoat,
            clearcoatRoughness: style.clearcoatRoughness,
            emissiveIntensity: emissiveIntensity
        )
    }

    private static func makeMaterial(
        tint: WarpColor,
        glow: WarpColor,
        opacity: Float,
        roughness: Float,
        metallic: Float,
        clearcoat: Float,
        clearcoatRoughness: Float,
        emissiveIntensity: Float
    ) -> Material {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(
            tint: UIColor(
                red: CGFloat(tint.red),
                green: CGFloat(tint.green),
                blue: CGFloat(tint.blue),
                alpha: CGFloat(clamp(opacity))
            )
        )
        material.blending = .transparent(opacity: .init(floatLiteral: clamp(opacity)))
        material.roughness = .init(floatLiteral: clamp(roughness))
        material.metallic = .init(floatLiteral: clamp(metallic))
        material.clearcoat = .init(floatLiteral: clamp(clearcoat))
        material.clearcoatRoughness = .init(floatLiteral: clamp(clearcoatRoughness))
        material.emissiveColor = .init(
            color: UIColor(
                red: CGFloat(glow.red),
                green: CGFloat(glow.green),
                blue: CGFloat(glow.blue),
                alpha: 1
            )
        )
        material.emissiveIntensity = clamp(emissiveIntensity)
        return material
    }

    private static func clamp(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
