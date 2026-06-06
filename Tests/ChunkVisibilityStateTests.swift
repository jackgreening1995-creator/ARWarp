import XCTest
@testable import ARWarpKit

final class ChunkVisibilityStateTests: XCTestCase {
    func testFadeInReachesFullVisibilityOverConfiguredDuration() {
        var state = ChunkVisibilityState(weight: 0)

        state.fadeIn(deltaTime: 0.10, duration: 0.25)
        XCTAssertEqual(state.weight, 0.40, accuracy: 0.001)

        state.fadeIn(deltaTime: 0.15, duration: 0.25)
        XCTAssertEqual(state.weight, 1.0, accuracy: 0.001)
        XCTAssertTrue(state.isVisible)

        state.fadeIn(deltaTime: 0.25, duration: 0.25)
        XCTAssertEqual(state.weight, 1.0, accuracy: 0.001)
    }

    func testFadeOutDropsBelowVisibilityThreshold() {
        var state = ChunkVisibilityState(weight: 1)

        state.fadeOut(deltaTime: 0.09, duration: 0.18)
        XCTAssertEqual(state.weight, 0.5, accuracy: 0.001)
        XCTAssertTrue(state.isVisible)

        state.fadeOut(deltaTime: 0.18, duration: 0.18)
        XCTAssertEqual(state.weight, 0.0, accuracy: 0.001)
        XCTAssertFalse(state.isVisible)
    }

    func testFrameDeltaClampPreventsResumeSpike() {
        XCTAssertEqual(
            SceneDeformationConfiguration.clampedFrameDeltaTime(0.016),
            0.016,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            SceneDeformationConfiguration.clampedFrameDeltaTime(0.5),
            SceneDeformationConfiguration.maxFrameDeltaTime,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            SceneDeformationConfiguration.clampedFrameDeltaTime(-0.2),
            0,
            accuracy: 0.0001
        )
    }
}
