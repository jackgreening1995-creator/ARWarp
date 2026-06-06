# Embedding ARWarpKit

Phase 6A introduces the supported host-facing integration surface for ARWarp.

## Supported API

Use SwiftUI and present `ARWarpView(configuration:)`.

```swift
import SwiftUI
import ARWarpKit

struct DemoHostView: View {
    @State private var latestStatus: ARWarpStatusSnapshot?

    var body: some View {
        ARWarpView(
            configuration: ARWarpModuleConfiguration(
                initialPresetID: .flow,
                showsControlsInitially: true,
                autoCollapseControlsWhenRoomReady: true,
                showsPerformanceStats: false,
                allowsAdvancedQAControls: false,
                chromeTheme: .default,
                onStatusChange: { snapshot in
                    latestStatus = snapshot
                }
            )
        )
        .ignoresSafeArea()
    }
}
```

## Configuration Defaults

`ARWarpModuleConfiguration()` defaults to the lightweight embedded presentation:

- `initialPresetID = .flow`
- `showsControlsInitially = true`
- `autoCollapseControlsWhenRoomReady = true`
- `showsPerformanceStats = false`
- `allowsAdvancedQAControls = false`
- `chromeTheme = .default`

## Public Status Surface

`ARWarpStatusSnapshot` exposes the supported host-observable runtime state:

- `sessionState`
- `meshAnchorCount`
- `activePresetID`
- `isWarpEnabled`
- `isLive`
- `lastError`

## Phase 6A Constraints

- `ARWarpView` is the only supported host entry in this phase.
- `ARWarpKit` still owns microphone capture, permission flow, AR session lifecycle, and the internal deformation/audio pipeline.
- `WarpPresetID` remains fixed to `flow` and `fracture`.
- `ARWarpChromeTheme` affects HUD chrome only. Preset-owned room colors and material response stay inside the framework.
- No UIKit wrapper, host audio injection, capture/export API, or extra presets are part of Phase 6A.
