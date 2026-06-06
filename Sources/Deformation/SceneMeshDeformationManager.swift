import ARKit
import Foundation
import RealityKit

/// Manages ARMeshAnchor lifecycle and GPU-deformed scene mesh chunks.
@MainActor
final class SceneMeshDeformationManager {
    private struct RetiringChunk {
        let chunk: DeformableSceneMesh
        var visibility: ChunkVisibilityState
    }

    private var chunks: [UUID: DeformableSceneMesh] = [:]
    private let rootAnchor: AnchorEntity
    private let metalDeformer: MetalSceneDeformer

    private var stableActiveChunkIdentifiers: [UUID] = []
    private var activeVisibilityStates: [UUID: ChunkVisibilityState] = [:]
    private var retiringChunks: [RetiringChunk] = []

    private var deformedChunkIdentifiers = Set<UUID>()
    private var queuedResetIdentifiers = Set<UUID>()
    private var inFlightDeformedChunkIdentifiers = Set<UUID>()
    private var inFlightRetainedChunks: [DeformableSceneMesh] = []
    private var isSubmissionInFlight = false
    private var submissionGeneration: UInt64 = 0

    private var latestGpuFrameMilliseconds: Float = 0
    private var lastSubmittedActiveChunkCount = 0
    private var lastSubmittedSkippedChunkCount = 0
    private var lastSubmittedDeformedVertexCount = 0
    private var lastPreset: WarpPreset = WarpPresetRegistry.defaultPreset

    private(set) var lastSubmissionError: ARWarpError?

    var meshAnchorCount: Int { chunks.count }

    init(rootAnchor: AnchorEntity) throws {
        self.rootAnchor = rootAnchor
        self.metalDeformer = try MetalSceneDeformer()
    }

    func reset() {
        submissionGeneration &+= 1

        for chunk in chunks.values {
            chunk.anchorEntity.removeFromParent()
        }
        for retiring in retiringChunks {
            retiring.chunk.anchorEntity.removeFromParent()
        }

        chunks.removeAll()
        stableActiveChunkIdentifiers.removeAll()
        activeVisibilityStates.removeAll()
        retiringChunks.removeAll()
        deformedChunkIdentifiers.removeAll()
        queuedResetIdentifiers.removeAll()
        inFlightDeformedChunkIdentifiers.removeAll()
        inFlightRetainedChunks.removeAll()
        lastSubmittedActiveChunkCount = 0
        lastSubmittedSkippedChunkCount = 0
        lastSubmittedDeformedVertexCount = 0
        latestGpuFrameMilliseconds = 0
        lastSubmissionError = nil
        lastPreset = WarpPresetRegistry.defaultPreset
    }

    func addOrUpdateMeshAnchor(_ meshAnchor: ARMeshAnchor) {
        let identifier = meshAnchor.identifier

        if let existing = chunks[identifier] {
            existing.updateTransform(meshAnchor.transform)

            // Avoid mutating base geometry while an earlier GPU submission may still be reading it.
            guard !isSubmissionInFlight else { return }

            let newVertexCount = meshAnchor.geometry.vertices.count
            if newVertexCount != existing.vertexCount, existing.canRebuildNow {
                replaceChunk(for: meshAnchor)
            } else if newVertexCount == existing.vertexCount, existing.canRebuildNow {
                try? existing.refreshBaseGeometry(from: meshAnchor.geometry)
            }
            return
        }

        createChunk(for: meshAnchor)
    }

    func removeMeshAnchor(withIdentifier identifier: UUID) {
        if let chunk = chunks.removeValue(forKey: identifier) {
            beginRetiring(
                chunk: chunk,
                visibility: activeVisibilityStates.removeValue(forKey: identifier) ?? ChunkVisibilityState(weight: 1)
            )
        }

        stableActiveChunkIdentifiers.removeAll { $0 == identifier }
        deformedChunkIdentifiers.remove(identifier)
        queuedResetIdentifiers.remove(identifier)
        inFlightDeformedChunkIdentifiers.remove(identifier)
    }

    func resetDeformedChunks() {
        lastSubmittedActiveChunkCount = 0
        lastSubmittedSkippedChunkCount = 0
        lastSubmittedDeformedVertexCount = 0

        let identifiersToReset = deformedChunkIdentifiers
            .union(inFlightDeformedChunkIdentifiers)
            .intersection(Set(chunks.keys))
        guard !identifiersToReset.isEmpty else {
            queuedResetIdentifiers.removeAll()
            return
        }

        queuedResetIdentifiers.formUnion(identifiersToReset)
        submitQueuedResetsIfPossible()
    }

    /// Selects nearby chunks and schedules a non-blocking Metal deformation pass.
    @discardableResult
    func updateDeformation(
        cameraPosition: SIMD3<Float>,
        anchorTransforms: [UUID: simd_float4x4],
        uniforms: AudioDeformUniforms,
        drives: DeformationDriveValues,
        preset: WarpPreset,
        deltaTime: Float,
        warpIsActive: Bool
    ) throws -> SceneDeformationStats {
        lastPreset = preset
        queuedResetIdentifiers.removeAll()

        let candidates = chunks.values.compactMap { chunk -> (DeformableSceneMesh, Float)? in
            guard let transform = anchorTransforms[chunk.identifier] else { return nil }
            let worldCenter = chunk.worldCenter(applying: transform)
            let distance = length(worldCenter - cameraPosition)
            guard distance <= SceneDeformationConfiguration.maxDeformationDistance else { return nil }
            return (chunk, distance)
        }
        .sorted { $0.1 < $1.1 }

        let selected: [DeformableSceneMesh]
        let selectedIdentifiers: Set<UUID>

        if warpIsActive {
            let budget = SceneDeformationConfiguration.maxActiveChunksPerFrame
            let eligibleByIdentifier = Dictionary(uniqueKeysWithValues: candidates.map { ($0.0.identifier, $0.0) })

            var orderedSelection: [DeformableSceneMesh] = []
            var identifierSet = Set<UUID>()

            for identifier in stableActiveChunkIdentifiers {
                guard let chunk = eligibleByIdentifier[identifier] else { continue }
                orderedSelection.append(chunk)
                identifierSet.insert(identifier)
                if orderedSelection.count == budget {
                    break
                }
            }

            if orderedSelection.count < budget {
                for (chunk, _) in candidates where !identifierSet.contains(chunk.identifier) {
                    orderedSelection.append(chunk)
                    identifierSet.insert(chunk.identifier)
                    if orderedSelection.count == budget {
                        break
                    }
                }
            }

            stableActiveChunkIdentifiers = orderedSelection.map(\.identifier)
            selected = orderedSelection
            selectedIdentifiers = identifierSet
        } else {
            stableActiveChunkIdentifiers.removeAll()
            selected = []
            selectedIdentifiers = []
        }

        let resetIdentifiers = warpIsActive
            ? deformedChunkIdentifiers.subtracting(selectedIdentifiers)
            : deformedChunkIdentifiers

        lastSubmittedActiveChunkCount = selected.count
        lastSubmittedSkippedChunkCount = warpIsActive ? max(0, candidates.count - selected.count) : 0

        advanceVisuals(
            activeChunkIDs: selectedIdentifiers,
            drives: drives,
            preset: preset,
            deltaTime: deltaTime,
            warpIsActive: warpIsActive
        )

        guard !isSubmissionInFlight else {
            return currentStats(totalChunks: chunks.count)
        }

        let workItems = makeWorkItems(
            selected: selected,
            activeUniforms: uniforms,
            resetIdentifiers: resetIdentifiers
        )

        guard !workItems.isEmpty else {
            lastSubmittedDeformedVertexCount = 0
            submitQueuedResetsIfPossible()
            return currentStats(totalChunks: chunks.count)
        }

        try submit(workItems: workItems)
        return currentStats(totalChunks: chunks.count)
    }

    func anchorTransforms() -> [UUID: simd_float4x4] {
        Dictionary(uniqueKeysWithValues: chunks.map { identifier, chunk in
            (identifier, chunk.anchorEntity.transformMatrix(relativeTo: nil))
        })
    }

    private func createChunk(for meshAnchor: ARMeshAnchor) {
        do {
            let chunk = try DeformableSceneMesh(
                identifier: meshAnchor.identifier,
                geometry: meshAnchor.geometry,
                transform: meshAnchor.transform,
                device: metalDeformer.metalDevice,
                rootAnchor: rootAnchor,
                material: SceneMeshMaterialFactory.makeRoomMaterial(
                    style: lastPreset.visualStyle,
                    phase: .scan,
                    response: 0,
                    scanCompletion: scanCompletion,
                    visibilityWeight: 0
                )
            )
            chunks[meshAnchor.identifier] = chunk
            activeVisibilityStates[meshAnchor.identifier] = ChunkVisibilityState(weight: 0)
        } catch {
            // Skip chunks that exceed vertex budget or fail conversion — keeps session alive.
        }
    }

    private func replaceChunk(for meshAnchor: ARMeshAnchor) {
        let identifier = meshAnchor.identifier

        if let existing = chunks.removeValue(forKey: identifier) {
            beginRetiring(
                chunk: existing,
                visibility: activeVisibilityStates.removeValue(forKey: identifier) ?? ChunkVisibilityState(weight: 1)
            )
        }

        stableActiveChunkIdentifiers.removeAll { $0 == identifier }
        deformedChunkIdentifiers.remove(identifier)
        queuedResetIdentifiers.remove(identifier)
        inFlightDeformedChunkIdentifiers.remove(identifier)

        createChunk(for: meshAnchor)
    }

    private func beginRetiring(chunk: DeformableSceneMesh, visibility: ChunkVisibilityState) {
        guard visibility.isVisible else {
            chunk.anchorEntity.removeFromParent()
            return
        }

        retiringChunks.append(
            RetiringChunk(
                chunk: chunk,
                visibility: visibility
            )
        )
    }

    private func makeWorkItems(
        selected: [DeformableSceneMesh],
        activeUniforms: AudioDeformUniforms,
        resetIdentifiers: Set<UUID>
    ) -> [SceneDeformationWorkItem] {
        let resetUniforms = AudioDeformUniforms.restPose(
            mode: lastPreset.motionKernel,
            bassSpeedScale: activeUniforms.bassSpeedScale
        )

        let resetChunks = resetIdentifiers.compactMap { chunks[$0] }

        return selected.map {
            SceneDeformationWorkItem(chunk: $0, uniforms: activeUniforms, isReset: false)
        } + resetChunks.map {
            SceneDeformationWorkItem(chunk: $0, uniforms: resetUniforms, isReset: true)
        }
    }

    private func submit(workItems: [SceneDeformationWorkItem]) throws {
        let generation = submissionGeneration

        isSubmissionInFlight = true
        inFlightRetainedChunks = workItems.map(\.chunk)
        inFlightDeformedChunkIdentifiers = Set(
            workItems.lazy
                .filter { !$0.isReset }
                .map { $0.chunk.identifier }
        )

        do {
            try metalDeformer.submit(workItems: workItems) { [weak self] result in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    self.isSubmissionInFlight = false
                    self.inFlightRetainedChunks.removeAll()
                    self.inFlightDeformedChunkIdentifiers.removeAll()

                    guard generation == self.submissionGeneration else { return }

                    switch result {
                    case .success(let submission):
                        self.latestGpuFrameMilliseconds = submission.gpuFrameMilliseconds
                        self.lastSubmittedDeformedVertexCount = submission.deformedVertexCount
                        self.lastSubmissionError = nil

                        self.deformedChunkIdentifiers.formUnion(submission.deformedChunkIDs)
                        self.deformedChunkIdentifiers.subtract(submission.resetChunkIDs)
                        self.deformedChunkIdentifiers.formIntersection(Set(self.chunks.keys))

                    case .failure(let error):
                        self.lastSubmissionError = (error as? ARWarpError)
                            ?? .deformationPipelineFailed(error.localizedDescription)
                    }

                    self.submitQueuedResetsIfPossible()
                }
            }
        } catch {
            isSubmissionInFlight = false
            inFlightRetainedChunks.removeAll()
            inFlightDeformedChunkIdentifiers.removeAll()
            throw error
        }
    }

    private func submitQueuedResetsIfPossible() {
        guard !isSubmissionInFlight else { return }

        let identifiersToReset = queuedResetIdentifiers.intersection(Set(chunks.keys))
        guard !identifiersToReset.isEmpty else {
            queuedResetIdentifiers.removeAll()
            deformedChunkIdentifiers.formIntersection(Set(chunks.keys))
            return
        }

        let resetUniforms = AudioDeformUniforms.restPose(
            mode: lastPreset.motionKernel,
            bassSpeedScale: lastPreset.defaultMapping.bassSpeedScale
        )
        let workItems = identifiersToReset.compactMap { chunks[$0] }.map {
            SceneDeformationWorkItem(chunk: $0, uniforms: resetUniforms, isReset: true)
        }

        guard !workItems.isEmpty else {
            queuedResetIdentifiers.removeAll()
            return
        }

        do {
            try submit(workItems: workItems)
            queuedResetIdentifiers.subtract(identifiersToReset)
        } catch {
            lastSubmissionError = (error as? ARWarpError)
                ?? .deformationPipelineFailed(error.localizedDescription)
        }
    }

    private func currentStats(totalChunks: Int) -> SceneDeformationStats {
        SceneDeformationStats(
            totalChunks: totalChunks,
            activeChunks: lastSubmittedActiveChunkCount,
            skippedChunks: lastSubmittedSkippedChunkCount,
            deformedVertices: lastSubmittedDeformedVertexCount,
            gpuFrameMilliseconds: latestGpuFrameMilliseconds
        )
    }

    private var scanCompletion: Float {
        min(Float(chunks.count) / Float(ARWarpConfiguration.meshAnchorGoalForLiveMode), 1)
    }

    private func advanceVisuals(
        activeChunkIDs: Set<UUID>,
        drives: DeformationDriveValues,
        preset: WarpPreset,
        deltaTime: Float,
        warpIsActive: Bool
    ) {
        let response = warpIsActive ? drives.visualResponse : 0

        for (identifier, chunk) in chunks {
            var visibility = activeVisibilityStates[identifier] ?? ChunkVisibilityState(weight: 0)
            visibility.fadeIn(
                deltaTime: deltaTime,
                duration: SceneDeformationConfiguration.chunkFadeInDuration
            )
            activeVisibilityStates[identifier] = visibility

            let phase: WarpMeshVisualPhase = warpIsActive && activeChunkIDs.contains(identifier)
                ? .active
                : .scan

            chunk.applyMaterial(
                SceneMeshMaterialFactory.makeRoomMaterial(
                    style: preset.visualStyle,
                    phase: phase,
                    response: response,
                    scanCompletion: scanCompletion,
                    visibilityWeight: visibility.weight
                )
            )
        }

        var updatedRetiringChunks: [RetiringChunk] = []
        for var retiring in retiringChunks {
            retiring.visibility.fadeOut(
                deltaTime: deltaTime,
                duration: SceneDeformationConfiguration.chunkRetireDuration
            )

            guard retiring.visibility.isVisible else {
                retiring.chunk.anchorEntity.removeFromParent()
                continue
            }

            retiring.chunk.applyMaterial(
                SceneMeshMaterialFactory.makeRoomMaterial(
                    style: preset.visualStyle,
                    phase: .retiring,
                    response: response,
                    scanCompletion: scanCompletion,
                    visibilityWeight: retiring.visibility.weight
                )
            )
            updatedRetiringChunks.append(retiring)
        }
        retiringChunks = updatedRetiringChunks
    }
}
