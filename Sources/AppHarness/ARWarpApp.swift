import ARWarpKit
import SwiftUI

@main
struct ARWarpApp: App {
    private let demoConfiguration = ARWarpModuleConfiguration(
        initialPresetID: .flow,
        showsControlsInitially: true,
        autoCollapseControlsWhenRoomReady: true,
        showsPerformanceStats: true,
        allowsAdvancedQAControls: true
    )

    var body: some Scene {
        WindowGroup {
            ARWarpView(configuration: demoConfiguration)
                .ignoresSafeArea()
        }
    }
}
