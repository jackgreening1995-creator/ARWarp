import ARKit
import Combine
import RealityKit

/// Configures ARKit session and forwards mesh anchors to the GPU deformation manager.
@MainActor
final class ARWarpSessionController: NSObject, ObservableObject {
    @Published private(set) var sessionState: SessionState = .initializing
    @Published private(set) var meshAnchorCount: Int = 0
    @Published private(set) var lastError: ARWarpError?
    @Published private(set) var isSceneReconstructionSupported: Bool = false

    private(set) var sceneMeshManager: SceneMeshDeformationManager?

    private weak var arView: ARView?
    private var rootAnchor: AnchorEntity?

    func attach(to arView: ARView) {
        guard self.arView !== arView || rootAnchor == nil else { return }

        if self.arView != nil {
            detach()
        }

        self.arView = arView
        arView.session.delegate = self
        arView.automaticallyConfigureSession = false

        let root = AnchorEntity(world: .zero)
        root.name = "ARWarpRoot"
        arView.scene.addAnchor(root)
        rootAnchor = root

        do {
            sceneMeshManager = try SceneMeshDeformationManager(rootAnchor: root)
        } catch {
            sceneMeshManager = nil
            lastError = .deformationPipelineFailed(error.localizedDescription)
        }

        isSceneReconstructionSupported = ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)

        guard isSceneReconstructionSupported else {
            sessionState = .unsupported
            lastError = .sceneReconstructionUnavailable
            return
        }

        startSession()
    }

    func pauseSession() {
        guard sessionState.isActive else { return }
        arView?.session.pause()
        sceneMeshManager?.resetDeformedChunks()
        sessionState = .paused
    }

    func resumeSession() {
        guard isSceneReconstructionSupported else { return }
        startSession()
    }

    func detach() {
        arView?.session.pause()
        arView?.session.delegate = nil
        sceneMeshManager?.reset()
        rootAnchor?.removeFromParent()

        sceneMeshManager = nil
        rootAnchor = nil
        arView = nil

        meshAnchorCount = 0
        lastError = nil
        sessionState = .initializing
    }

    private func startSession() {
        guard let arView else { return }

        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification
        configuration.environmentTexturing = ARWarpConfiguration.environmentTexturingAutomatic ? .automatic : .none

        if ARWarpConfiguration.enablePlaneDetection {
            configuration.planeDetection = [.horizontal, .vertical]
        }

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }

        arView.renderOptions.insert(.disableDepthOfField)
        arView.renderOptions.insert(.disableMotionBlur)
        arView.environment.sceneUnderstanding.options.insert(.occlusion)

        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        sceneMeshManager?.reset()
        meshAnchorCount = 0
        sessionState = .running
        lastError = nil
    }

    private func syncMeshCount() {
        meshAnchorCount = sceneMeshManager?.meshAnchorCount ?? 0
    }
}

extension ARWarpSessionController: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let meshAnchors = anchors.compactMap { $0 as? ARMeshAnchor }
        guard !meshAnchors.isEmpty else { return }

        Task { @MainActor in
            for anchor in meshAnchors {
                sceneMeshManager?.addOrUpdateMeshAnchor(anchor)
            }
            syncMeshCount()
        }
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let meshAnchors = anchors.compactMap { $0 as? ARMeshAnchor }
        guard !meshAnchors.isEmpty else { return }

        Task { @MainActor in
            for anchor in meshAnchors {
                sceneMeshManager?.addOrUpdateMeshAnchor(anchor)
            }
            syncMeshCount()
        }
    }

    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let meshAnchors = anchors.compactMap { $0 as? ARMeshAnchor }
        guard !meshAnchors.isEmpty else { return }

        Task { @MainActor in
            for anchor in meshAnchors {
                sceneMeshManager?.removeMeshAnchor(withIdentifier: anchor.identifier)
            }
            syncMeshCount()
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            sceneMeshManager?.resetDeformedChunks()
            sessionState = .failed
            lastError = .sessionFailed(error.localizedDescription)
        }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in
            sceneMeshManager?.resetDeformedChunks()
            sessionState = .paused
        }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor in
            resumeSession()
        }
    }
}
