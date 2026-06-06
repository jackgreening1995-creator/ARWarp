import RealityKit
import SwiftUI

/// UIKit bridge hosting a RealityKit ARView wired to session and deformation controllers.
struct ARWarpContainerView: UIViewRepresentable {
    @ObservedObject var controller: ARWarpSessionController
    @ObservedObject var deformationController: DeformationSceneController
    var audioEngine: AudioFeatureEngine

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        arView.environment.background = .cameraFeed()
        DispatchQueue.main.async {
            controller.attach(to: arView)
            deformationController.attach(
                to: arView,
                audioEngine: audioEngine,
                sceneMeshManager: controller.sceneMeshManager
            )
        }
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
