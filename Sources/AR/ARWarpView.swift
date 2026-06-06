import SwiftUI

/// Public embeddable surface for presenting ARWarp inside a SwiftUI host app.
public struct ARWarpView: View {
    private let configuration: ARWarpModuleConfiguration

    public init(configuration: ARWarpModuleConfiguration = ARWarpModuleConfiguration()) {
        self.configuration = configuration
    }

    public var body: some View {
        ARWarpExperienceView(configuration: configuration)
    }
}
