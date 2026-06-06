import Foundation
import Metal
import RealityKit

private final class ARWarpKitBundleToken {}

struct SceneDeformationWorkItem {
    let chunk: DeformableSceneMesh
    let uniforms: AudioDeformUniforms
    let isReset: Bool
}

struct SceneDeformationSubmissionResult: Sendable {
    let deformedChunkIDs: Set<UUID>
    let resetChunkIDs: Set<UUID>
    let deformedVertexCount: Int
    let gpuFrameMilliseconds: Float
}

/// GPU compute pipeline that displaces scene mesh vertices via `SceneDeformation.metal`.
final class MetalSceneDeformer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLComputePipelineState

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw ARWarpError.deformationPipelineFailed("Metal device unavailable")
        }
        guard let commandQueue = device.makeCommandQueue() else {
            throw ARWarpError.deformationPipelineFailed("Metal command queue unavailable")
        }
        let bundle = Bundle(for: ARWarpKitBundleToken.self)
        guard let library = try? device.makeDefaultLibrary(bundle: bundle),
              let function = library.makeFunction(name: "deformSceneVertices") else {
            throw ARWarpError.deformationPipelineFailed("Scene deformation shader not found")
        }

        self.device = device
        self.commandQueue = commandQueue
        self.pipelineState = try device.makeComputePipelineState(function: function)
    }

    var metalDevice: MTLDevice { device }

    /// Encodes GPU displacement for the provided chunks into a single command buffer.
    ///
    /// Submission is intentionally non-blocking. Callers get completion on the main actor when
    /// the command buffer finishes so AR session updates do not stall waiting for GPU work.
    @MainActor
    func submit(
        workItems: [SceneDeformationWorkItem],
        completion: @escaping @Sendable (Result<SceneDeformationSubmissionResult, Error>) -> Void
    ) throws {
        guard !workItems.isEmpty else {
            completion(.success(SceneDeformationSubmissionResult(
                deformedChunkIDs: [],
                resetChunkIDs: [],
                deformedVertexCount: 0,
                gpuFrameMilliseconds: 0
            )))
            return
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw ARWarpError.deformationPipelineFailed("Failed to create Metal command buffer")
        }

        encoder.setComputePipelineState(pipelineState)

        var deformedVertices = 0
        var deformedChunkIDs = Set<UUID>()
        var resetChunkIDs = Set<UUID>()

        for item in workItems {
            guard let uniformsBuffer = device.makeBuffer(
                length: MemoryLayout<AudioDeformUniforms>.stride,
                options: .storageModeShared
            ) else {
                throw ARWarpError.deformationPipelineFailed("Failed to allocate deformation uniform buffer")
            }

            let chunk = item.chunk
            var chunkUniforms = item.uniforms
            chunkUniforms.chunkCenterX = chunk.centerXZ.x
            chunkUniforms.chunkCenterZ = chunk.centerXZ.y
            uniformsBuffer.contents().copyMemory(
                from: &chunkUniforms,
                byteCount: MemoryLayout<AudioDeformUniforms>.stride
            )

            let vertexBuffer = chunk.lowLevelMesh.replace(bufferIndex: 0, using: commandBuffer)

            encoder.setBuffer(uniformsBuffer, offset: 0, index: 0)
            encoder.setBuffer(chunk.basePositionBuffer, offset: 0, index: 1)
            encoder.setBuffer(chunk.baseNormalBuffer, offset: 0, index: 2)
            encoder.setBuffer(vertexBuffer, offset: 0, index: 3)

            let threadsPerGrid = MTLSize(width: chunk.vertexCount, height: 1, depth: 1)
            let threadsPerGroup = MTLSize(
                width: min(pipelineState.maxTotalThreadsPerThreadgroup, 256),
                height: 1,
                depth: 1
            )
            encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)

            if item.isReset {
                resetChunkIDs.insert(chunk.identifier)
            } else {
                deformedChunkIDs.insert(chunk.identifier)
                deformedVertices += chunk.vertexCount
            }
        }

        encoder.endEncoding()

        let submittedAt = CFAbsoluteTimeGetCurrent()
        commandBuffer.addCompletedHandler { commandBuffer in
            let elapsed = Float((CFAbsoluteTimeGetCurrent() - submittedAt) * 1000)
            let result = SceneDeformationSubmissionResult(
                deformedChunkIDs: deformedChunkIDs,
                resetChunkIDs: resetChunkIDs,
                deformedVertexCount: deformedVertices,
                gpuFrameMilliseconds: elapsed
            )

            Task { @MainActor in
                if let error = commandBuffer.error {
                    completion(.failure(ARWarpError.deformationPipelineFailed(error.localizedDescription)))
                } else {
                    completion(.success(result))
                }
            }
        }

        commandBuffer.commit()
    }
}
