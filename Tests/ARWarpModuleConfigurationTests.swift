import SwiftUI
import XCTest
@testable import ARWarpKit

final class ARWarpModuleConfigurationTests: XCTestCase {
    func testDefaultConfigurationMatchesEmbeddedModuleContract() {
        let configuration = ARWarpModuleConfiguration()

        XCTAssertEqual(configuration.initialPresetID, .flow)
        XCTAssertTrue(configuration.showsControlsInitially)
        XCTAssertTrue(configuration.autoCollapseControlsWhenRoomReady)
        XCTAssertFalse(configuration.showsPerformanceStats)
        XCTAssertFalse(configuration.allowsAdvancedQAControls)
        XCTAssertEqual(configuration.chromeTheme, .default)
        XCTAssertNil(configuration.onStatusChange)
    }

    func testConfigurationEqualityIgnoresCallbackIdentity() {
        let first = ARWarpModuleConfiguration(
            initialPresetID: .fracture,
            showsControlsInitially: false,
            autoCollapseControlsWhenRoomReady: false,
            showsPerformanceStats: true,
            allowsAdvancedQAControls: true,
            chromeTheme: ARWarpChromeTheme(
                followsPresetAccent: false,
                accentTint: ARWarpColor(red: 0.9, green: 0.4, blue: 0.3),
                overlayTint: ARWarpColor(red: 0.2, green: 0.7, blue: 0.8),
                overlayStrength: 0.65
            ),
            onStatusChange: { _ in }
        )
        let second = ARWarpModuleConfiguration(
            initialPresetID: .fracture,
            showsControlsInitially: false,
            autoCollapseControlsWhenRoomReady: false,
            showsPerformanceStats: true,
            allowsAdvancedQAControls: true,
            chromeTheme: ARWarpChromeTheme(
                followsPresetAccent: false,
                accentTint: ARWarpColor(red: 0.9, green: 0.4, blue: 0.3),
                overlayTint: ARWarpColor(red: 0.2, green: 0.7, blue: 0.8),
                overlayStrength: 0.65
            ),
            onStatusChange: { _ in
                XCTFail("Callback should not be invoked during equality comparison.")
            }
        )

        XCTAssertEqual(first, second)
    }

    func testStatusSnapshotShapeAndEquality() {
        let first = ARWarpStatusSnapshot(
            sessionState: .running,
            meshAnchorCount: 14,
            activePresetID: .flow,
            isWarpEnabled: true,
            isLive: true,
            lastError: nil
        )
        let second = ARWarpStatusSnapshot(
            sessionState: .running,
            meshAnchorCount: 14,
            activePresetID: .flow,
            isWarpEnabled: true,
            isLive: true,
            lastError: nil
        )
        let third = ARWarpStatusSnapshot(
            sessionState: .failed,
            meshAnchorCount: 0,
            activePresetID: .fracture,
            isWarpEnabled: false,
            isLive: false,
            lastError: .audioEngineUnavailable
        )

        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, third)
    }

    func testPublicPresetAvailabilityRemainsExactlyFlowAndFracture() {
        XCTAssertEqual(WarpPresetID.allCases, [.flow, .fracture])
    }

    func testPublicViewConstructsWithCustomConfiguration() {
        let configuration = ARWarpModuleConfiguration(
            initialPresetID: .fracture,
            showsControlsInitially: false,
            autoCollapseControlsWhenRoomReady: false,
            showsPerformanceStats: true,
            allowsAdvancedQAControls: true,
            chromeTheme: ARWarpChromeTheme(
                followsPresetAccent: false,
                accentTint: ARWarpColor(red: 0.9, green: 0.4, blue: 0.3),
                overlayTint: ARWarpColor(red: 0.3, green: 0.5, blue: 0.9),
                overlayStrength: 0.8
            )
        )

        let view = ARWarpView(configuration: configuration)
        _ = view.body
        XCTAssertTrue(true)
    }
}
