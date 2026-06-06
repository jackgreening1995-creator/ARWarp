import Foundation

/// Lightweight RGB color used by the embeddable ARWarp chrome theme.
public struct ARWarpColor: Sendable, Equatable {
    public var red: Float
    public var green: Float
    public var blue: Float

    public init(red: Float, green: Float, blue: Float) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
    }

    private static func clamp(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

/// Host-controlled theme for ARWarp's HUD chrome and atmospheric overlay.
///
/// This theme does not alter room-warp materials; presets still own scene color and motion identity.
public struct ARWarpChromeTheme: Sendable, Equatable {
    public var followsPresetAccent: Bool
    public var accentTint: ARWarpColor
    public var overlayTint: ARWarpColor
    public var overlayStrength: Float

    public init(
        followsPresetAccent: Bool = true,
        accentTint: ARWarpColor = ARWarpColor(red: 0.42, green: 0.89, blue: 0.98),
        overlayTint: ARWarpColor = ARWarpColor(red: 0.42, green: 0.89, blue: 0.98),
        overlayStrength: Float = 1
    ) {
        self.followsPresetAccent = followsPresetAccent
        self.accentTint = accentTint
        self.overlayTint = overlayTint
        self.overlayStrength = min(max(overlayStrength, 0), 1)
    }

    public static let `default` = ARWarpChromeTheme()
}

/// High-level runtime state emitted to hosts embedding `ARWarpView`.
public struct ARWarpStatusSnapshot: Sendable, Equatable {
    public var sessionState: SessionState
    public var meshAnchorCount: Int
    public var activePresetID: WarpPresetID
    public var isWarpEnabled: Bool
    public var isLive: Bool
    public var lastError: ARWarpError?

    public init(
        sessionState: SessionState,
        meshAnchorCount: Int,
        activePresetID: WarpPresetID,
        isWarpEnabled: Bool,
        isLive: Bool,
        lastError: ARWarpError?
    ) {
        self.sessionState = sessionState
        self.meshAnchorCount = meshAnchorCount
        self.activePresetID = activePresetID
        self.isWarpEnabled = isWarpEnabled
        self.isLive = isLive
        self.lastError = lastError
    }
}

/// Minimal host-facing configuration for the embeddable ARWarp module.
///
/// Equality intentionally ignores `onStatusChange` so hosts can compare visual/runtime options
/// without treating callback identity as part of module behavior.
public struct ARWarpModuleConfiguration: Sendable, Equatable {
    public var initialPresetID: WarpPresetID
    public var showsControlsInitially: Bool
    public var autoCollapseControlsWhenRoomReady: Bool
    public var showsPerformanceStats: Bool
    public var allowsAdvancedQAControls: Bool
    public var chromeTheme: ARWarpChromeTheme
    public var onStatusChange: (@Sendable (ARWarpStatusSnapshot) -> Void)?

    public init(
        initialPresetID: WarpPresetID = .flow,
        showsControlsInitially: Bool = true,
        autoCollapseControlsWhenRoomReady: Bool = true,
        showsPerformanceStats: Bool = false,
        allowsAdvancedQAControls: Bool = false,
        chromeTheme: ARWarpChromeTheme = .default,
        onStatusChange: (@Sendable (ARWarpStatusSnapshot) -> Void)? = nil
    ) {
        self.initialPresetID = initialPresetID
        self.showsControlsInitially = showsControlsInitially
        self.autoCollapseControlsWhenRoomReady = autoCollapseControlsWhenRoomReady
        self.showsPerformanceStats = showsPerformanceStats
        self.allowsAdvancedQAControls = allowsAdvancedQAControls
        self.chromeTheme = chromeTheme
        self.onStatusChange = onStatusChange
    }

    public static func == (lhs: ARWarpModuleConfiguration, rhs: ARWarpModuleConfiguration) -> Bool {
        lhs.initialPresetID == rhs.initialPresetID
            && lhs.showsControlsInitially == rhs.showsControlsInitially
            && lhs.autoCollapseControlsWhenRoomReady == rhs.autoCollapseControlsWhenRoomReady
            && lhs.showsPerformanceStats == rhs.showsPerformanceStats
            && lhs.allowsAdvancedQAControls == rhs.allowsAdvancedQAControls
            && lhs.chromeTheme == rhs.chromeTheme
    }
}
