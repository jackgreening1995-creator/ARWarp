import Foundation

/// Shared fade helper for chunk and mesh-visibility transitions.
struct ChunkVisibilityState: Sendable, Equatable {
    var weight: Float = 0

    mutating func fadeIn(deltaTime: Float, duration: Float) {
        weight = Self.step(from: weight, toward: 1, deltaTime: deltaTime, duration: duration)
    }

    mutating func fadeOut(deltaTime: Float, duration: Float) {
        weight = Self.step(from: weight, toward: 0, deltaTime: deltaTime, duration: duration)
    }

    var isVisible: Bool {
        weight > 0.001
    }

    private static func step(from current: Float, toward target: Float, deltaTime: Float, duration: Float) -> Float {
        guard duration > 0 else { return target }
        let delta = min(max(deltaTime / duration, 0), 1)
        if target >= current {
            return min(current + delta, target)
        } else {
            return max(current - delta, target)
        }
    }
}
