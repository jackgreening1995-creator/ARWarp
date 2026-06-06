import ARKit
import Combine
import RealityKit
import UIKit

/// Debug settings exposed to the SwiftUI deformation panel.
@MainActor
final class DeformationDebugSettings: ObservableObject {
    @Published var isEnabled = true
    @Published var deformationTarget: DeformationTarget = .sceneMesh
    @Published var presetID: WarpPresetID
    @Published var masterIntensity: Float
    @Published var showsAdvancedQA = false

    @Published var beatPulseScale: Float
    @Published var bassAmplitudeScale: Float
    @Published var beatDecayTime: Float

    init(presetID: WarpPresetID = WarpPresetRegistry.defaultPresetID) {
        self.presetID = presetID
        let preset = WarpPresetRegistry.preset(for: presetID)
        self.masterIntensity = preset.defaultMapping.masterIntensity
        self.beatPulseScale = preset.defaultMapping.beatPulseScale
        self.bassAmplitudeScale = preset.defaultMapping.bassAmplitudeScale
        self.beatDecayTime = preset.defaultMapping.beatDecayTime
    }

    var preset: WarpPreset {
        WarpPresetRegistry.preset(for: presetID)
    }

    func selectPreset(_ presetID: WarpPresetID) {
        guard self.presetID != presetID else { return }
        self.presetID = presetID
        applyPresetDefaults(for: presetID)
    }

    private func applyPresetDefaults(for presetID: WarpPresetID) {
        let mapping = WarpPresetRegistry.preset(for: presetID).defaultMapping
        masterIntensity = mapping.masterIntensity
        beatPulseScale = mapping.beatPulseScale
        bassAmplitudeScale = mapping.bassAmplitudeScale
        beatDecayTime = mapping.beatDecayTime
    }
}

/// Coordinates audio-driven deformation for scene meshes (GPU) and optional test grid (CPU).
@MainActor
final class DeformationSceneController: ObservableObject {
    @Published private(set) var isTestGridVisible = false
    @Published private(set) var driveSnapshot = DeformationDriveSnapshot()
    @Published private(set) var sceneStats = SceneDeformationStats()
    @Published private(set) var lastError: ARWarpError?

    let debugSettings: DeformationDebugSettings

    private weak var arView: ARView?
    private weak var sceneMeshManager: SceneMeshDeformationManager?

    private var meshAnchor = AnchorEntity()
    private var gridMesh: DeformableGridMesh?
    private var gridEntity: ModelEntity?
    private var gridDeformer = AudioDrivenDeformer()
    private var driveSmoother = DeformationDriveSmoother()
    private var updateSubscription: (any Cancellable)?
    private var audioSubscription: AnyCancellable?
    private weak var audioEngine: AudioFeatureEngine?

    private var latestAudio: AudioFeatureSnapshot = .silent
    private var elapsedTime: Float = 0
    private var mapping = DeformationConfiguration.defaultMapping

    init(initialPresetID: WarpPresetID = WarpPresetRegistry.defaultPresetID) {
        self.debugSettings = DeformationDebugSettings(presetID: initialPresetID)
    }

    func attach(
        to arView: ARView,
        audioEngine: AudioFeatureEngine,
        sceneMeshManager: SceneMeshDeformationManager?
    ) {
        if self.arView === arView, updateSubscription != nil {
            self.sceneMeshManager = sceneMeshManager
            if self.audioEngine !== audioEngine {
                self.audioEngine?.onSnapshot = nil
            }
        } else {
            updateSubscription = nil
            audioSubscription = nil
        }

        self.arView = arView
        self.audioEngine = audioEngine
        self.sceneMeshManager = sceneMeshManager

        audioSubscription = audioEngine.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.latestAudio = snapshot
            }

        audioEngine.onSnapshot = { [weak self] snapshot in
            Task { @MainActor in
                self?.latestAudio = snapshot
            }
        }

        if updateSubscription == nil {
            subscribeToSceneUpdates()
        }
    }

    func detach() {
        updateSubscription = nil
        audioSubscription = nil
        audioEngine?.onSnapshot = nil
        audioEngine = nil
        sceneMeshManager?.resetDeformedChunks()
        tearDownTestGrid()
        sceneMeshManager = nil
        arView = nil
        driveSmoother.reset()
        gridDeformer.resetTime()
        driveSnapshot = DeformationDriveSnapshot()
        sceneStats = SceneDeformationStats()
        elapsedTime = 0
        lastError = nil
    }

    func repositionTestGrid() {
        guard let arView, let frame = arView.session.currentFrame else { return }

        let cameraTransform = frame.camera.transform
        let cameraPosition = SIMD3(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )

        var forward = SIMD3(
            -cameraTransform.columns.2.x,
            0,
            -cameraTransform.columns.2.z
        )
        if length(forward) < 0.001 {
            forward = SIMD3(0, 0, -1)
        } else {
            forward = normalize(forward)
        }

        let placement = cameraPosition + forward * DeformationConfiguration.placementDistance
        meshAnchor.position = placement
        meshAnchor.orientation = simd_quatf(angle: atan2(forward.x, forward.z), axis: SIMD3(0, 1, 0))
    }

    private func subscribeToSceneUpdates() {
        guard let arView else { return }

        updateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            Task { @MainActor in
                self?.tick(deltaTime: Float(event.deltaTime))
            }
        }
    }

    private func syncMappingFromDebugSettings() {
        mapping = debugSettings.preset.defaultMapping.overriding(
            masterIntensity: debugSettings.masterIntensity,
            bassAmplitudeScale: debugSettings.bassAmplitudeScale,
            beatPulseScale: debugSettings.beatPulseScale,
            beatDecayTime: debugSettings.beatDecayTime
        )
    }

    private func tick(deltaTime: Float) {
        let deltaTime = SceneDeformationConfiguration.clampedFrameDeltaTime(deltaTime)
        guard deltaTime > 0 else { return }

        let preset = debugSettings.preset
        let target = debugSettings.deformationTarget
        let shouldDeformSceneMeshes = debugSettings.isEnabled && (target == .sceneMesh || target == .both)
        let shouldShowTestGrid = debugSettings.isEnabled && (target == .testGrid || target == .both)

        if !shouldShowTestGrid {
            tearDownTestGrid()
        }

        elapsedTime += deltaTime
        syncMappingFromDebugSettings()

        let drives: DeformationDriveValues
        if debugSettings.isEnabled {
            drives = driveSmoother.update(
                audio: latestAudio,
                mapping: mapping,
                deltaTime: deltaTime
            )
            driveSnapshot = drives.asSnapshot(beatEnvelope: driveSmoother.beatEnvelope)
        } else {
            driveSmoother.reset()
            drives = .zero
            driveSnapshot = DeformationDriveSnapshot()
        }

        if shouldShowTestGrid {
            ensureTestGrid(preset: preset)
            updateTestGridMaterial(preset: preset, response: drives.visualResponse)
            deformTestGrid(preset: preset, drives: drives, deltaTime: deltaTime)
        }

        updateSceneMeshes(
            preset: preset,
            drives: drives,
            deltaTime: deltaTime,
            warpIsActive: shouldDeformSceneMeshes
        )

        lastError = sceneMeshManager?.lastSubmissionError
    }

    private func updateSceneMeshes(
        preset: WarpPreset,
        drives: DeformationDriveValues,
        deltaTime: Float,
        warpIsActive: Bool
    ) {
        guard let sceneMeshManager, let arView, let frame = arView.session.currentFrame else {
            sceneStats = SceneDeformationStats(totalChunks: sceneMeshManager?.meshAnchorCount ?? 0)
            return
        }

        let cameraTransform = frame.camera.transform
        let cameraPosition = SIMD3(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )

        let uniforms = AudioDeformUniforms.from(
            drives: drives,
            beatEnvelope: driveSmoother.beatEnvelope,
            mode: preset.motionKernel,
            mapping: mapping,
            time: elapsedTime,
            deltaTime: deltaTime,
            chunkCenter: .zero
        )

        do {
            sceneStats = try sceneMeshManager.updateDeformation(
                cameraPosition: cameraPosition,
                anchorTransforms: sceneMeshManager.anchorTransforms(),
                uniforms: uniforms,
                drives: drives,
                preset: preset,
                deltaTime: deltaTime,
                warpIsActive: warpIsActive
            )
        } catch {
            lastError = .deformationPipelineFailed(error.localizedDescription)
        }
    }

    private func deformTestGrid(
        preset: WarpPreset,
        drives: DeformationDriveValues,
        deltaTime: Float
    ) {
        guard let gridMesh else { return }

        gridDeformer.mode = preset.motionKernel
        gridDeformer.mapping = mapping

        do {
            try gridDeformer.apply(
                to: gridMesh,
                drives: drives,
                beatEnvelope: driveSmoother.beatEnvelope,
                audio: latestAudio,
                deltaTime: deltaTime
            )

            if debugSettings.deformationTarget == .testGrid || debugSettings.deformationTarget == .both {
                driveSnapshot = gridDeformer.lastDriveSnapshot
            }
        } catch {
            lastError = .deformationPipelineFailed(error.localizedDescription)
        }
    }

    private func ensureTestGrid(preset: WarpPreset) {
        guard gridMesh == nil, let arView else { return }

        do {
            let grid = try DeformableGridMesh()
            gridMesh = grid

            let entity = ModelEntity(
                mesh: grid.meshResource,
                materials: [SceneMeshMaterialFactory.makeGridMaterial(
                    style: preset.visualStyle,
                    response: 0
                )]
            )
            entity.name = "AudioDeformTestMesh"
            gridEntity = entity

            meshAnchor.name = "AudioDeformAnchor"
            meshAnchor.addChild(entity)
            arView.scene.addAnchor(meshAnchor)

            repositionTestGrid()
            isTestGridVisible = true
        } catch {
            lastError = .deformationPipelineFailed(error.localizedDescription)
            isTestGridVisible = false
        }
    }

    private func updateTestGridMaterial(preset: WarpPreset, response: Float) {
        guard let gridEntity else { return }
        gridEntity.model?.materials = [
            SceneMeshMaterialFactory.makeGridMaterial(
                style: preset.visualStyle,
                response: response
            ),
        ]
    }

    private func tearDownTestGrid() {
        for child in meshAnchor.children {
            child.removeFromParent()
        }

        meshAnchor.removeFromParent()
        meshAnchor = AnchorEntity()
        gridMesh = nil
        gridEntity = nil
        gridDeformer.resetTime()
        isTestGridVisible = false
    }
}
