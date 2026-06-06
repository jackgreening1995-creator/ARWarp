import XCTest
@testable import ARWarpKit

final class WarpPresetRegistryTests: XCTestCase {
    func testRegistryContainsExactlyFlowAndFracture() {
        let presetIDs = WarpPresetRegistry.allPresets.map(\.id)
        XCTAssertEqual(presetIDs, [.flow, .fracture])
        XCTAssertEqual(Set(presetIDs).count, 2)
    }

    func testEachPresetMapsToValidKernel() {
        let kernels = Set(WarpPresetRegistry.allPresets.map(\.motionKernel))
        XCTAssertEqual(kernels, [.ripple, .pulse])
    }

    func testVisualStyleValuesStayWithinNormalizedBounds() {
        for preset in WarpPresetRegistry.allPresets {
            let style = preset.visualStyle
            let values: [Float] = [
                style.scanOpacity,
                style.activeOpacity,
                style.retiringOpacity,
                style.opacityResponseBoost,
                style.scanTintMix,
                style.activeTintMix,
                style.responseTintBoost,
                style.scanRoughness,
                style.activeRoughness,
                style.retiringRoughness,
                style.metallic,
                style.clearcoat,
                style.clearcoatRoughness,
                style.scanEmissive,
                style.activeEmissiveBase,
                style.activeEmissiveBoost,
                style.retiringEmissive,
                style.gridOpacity,
                style.gridRoughness,
                style.gridEmissiveBase,
                style.gridEmissiveBoost,
                style.baseTint.red,
                style.baseTint.green,
                style.baseTint.blue,
                style.accentTint.red,
                style.accentTint.green,
                style.accentTint.blue,
                style.glowTint.red,
                style.glowTint.green,
                style.glowTint.blue,
            ]

            XCTAssertTrue(values.allSatisfy { (0...1).contains($0) }, "Out-of-range value in preset \(preset.id.rawValue)")
        }
    }
}
