import ARKit
import Metal
import RealityKit
import simd

/// One deformable scene-reconstruction chunk backed by `LowLevelMesh` and GPU base buffers.
@MainActor
final class DeformableSceneMesh {
    let identifier: UUID
    let lowLevelMesh: LowLevelMesh
    let meshResource: MeshResource
    let vertexCount: Int
    let indexCount: Int
    private(set) var localCenter: SIMD3<Float>

    let basePositionBuffer: MTLBuffer
    let baseNormalBuffer: MTLBuffer

    let modelEntity: ModelEntity
    let anchorEntity: AnchorEntity

    private var lastGeometryRebuild: TimeInterval = 0

    init(
        identifier: UUID,
        geometry: ARMeshGeometry,
        transform: simd_float4x4,
        device: MTLDevice,
        rootAnchor: AnchorEntity,
        material: Material
    ) throws {
        self.identifier = identifier
        let data = try ARMeshGeometryExtractor.extract(from: geometry)

        guard data.vertexCount <= SceneDeformationConfiguration.maxVerticesPerChunk else {
            throw ARWarpError.deformationPipelineFailed("Chunk exceeds vertex budget")
        }

        self.vertexCount = data.vertexCount
        self.indexCount = data.indexCount
        self.localCenter = data.center

        guard
            let positionBuffer = device.makeBuffer(
                bytes: data.positions,
                length: MemoryLayout<SIMD3<Float>>.stride * data.vertexCount,
                options: .storageModeShared
            ),
            let normalBuffer = device.makeBuffer(
                bytes: data.normals,
                length: MemoryLayout<SIMD3<Float>>.stride * data.vertexCount,
                options: .storageModeShared
            )
        else {
            throw ARWarpError.deformationPipelineFailed("Failed to allocate Metal base buffers")
        }

        self.basePositionBuffer = positionBuffer
        self.baseNormalBuffer = normalBuffer

        let descriptor = DeformableVertex.makeDescriptor(
            vertexCount: data.vertexCount,
            indexCount: data.indexCount
        )
        self.lowLevelMesh = try LowLevelMesh(descriptor: descriptor)
        self.meshResource = try MeshResource(from: lowLevelMesh)

        try Self.populateMeshBuffers(
            lowLevelMesh: lowLevelMesh,
            positions: data.positions,
            normals: data.normals,
            indices: data.indices,
            bounds: data.bounds
        )

        let entity = ModelEntity(mesh: meshResource, materials: [material])
        entity.name = "SceneMesh-\(identifier.uuidString.prefix(8))"

        let anchor = AnchorEntity(world: transform)
        anchor.name = "MeshAnchor-\(identifier.uuidString.prefix(8))"
        anchor.addChild(entity)
        rootAnchor.addChild(anchor)

        self.modelEntity = entity
        self.anchorEntity = anchor
        self.lastGeometryRebuild = Date().timeIntervalSince1970
    }

    func updateTransform(_ transform: simd_float4x4) {
        anchorEntity.transform = Transform(matrix: transform)
    }

    /// Refreshes base GPU buffers when ARKit refines geometry without changing vertex count.
    func refreshBaseGeometry(from geometry: ARMeshGeometry) throws {
        let data = try ARMeshGeometryExtractor.extract(from: geometry)
        guard data.vertexCount == vertexCount else {
            throw ARWarpError.deformationPipelineFailed("Vertex count changed")
        }

        localCenter = data.center

        memcpy(
            basePositionBuffer.contents(),
            data.positions,
            MemoryLayout<SIMD3<Float>>.stride * vertexCount
        )
        memcpy(
            baseNormalBuffer.contents(),
            data.normals,
            MemoryLayout<SIMD3<Float>>.stride * vertexCount
        )

        try Self.populateMeshBuffers(
            lowLevelMesh: lowLevelMesh,
            positions: data.positions,
            normals: data.normals,
            indices: data.indices,
            bounds: data.bounds
        )
        lastGeometryRebuild = Date().timeIntervalSince1970
    }

    var canRebuildNow: Bool {
        Date().timeIntervalSince1970 - lastGeometryRebuild >= SceneDeformationConfiguration.geometryRebuildCooldown
    }

    func worldCenter(applying transform: simd_float4x4) -> SIMD3<Float> {
        let local = SIMD4(localCenter.x, localCenter.y, localCenter.z, 1)
        let world = transform * local
        return SIMD3(world.x, world.y, world.z)
    }

    var centerXZ: SIMD2<Float> {
        SIMD2(localCenter.x, localCenter.z)
    }

    func applyMaterial(_ material: Material) {
        modelEntity.model?.materials = [material]
    }

    private static func populateMeshBuffers(
        lowLevelMesh: LowLevelMesh,
        positions: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        indices: [UInt32],
        bounds: (min: SIMD3<Float>, max: SIMD3<Float>)
    ) throws {
        lowLevelMesh.withUnsafeMutableBytes(bufferIndex: 0) { rawBytes in
            let vertices = rawBytes.bindMemory(to: DeformableVertex.self)
            for index in 0..<positions.count {
                vertices[index].position = positions[index]
                vertices[index].normal = normals[index]
            }
        }

        lowLevelMesh.withUnsafeMutableIndices { rawIndices in
            let indexBuffer = rawIndices.bindMemory(to: UInt32.self)
            for (offset, index) in indices.enumerated() {
                indexBuffer[offset] = index
            }
        }

        let meshBounds = BoundingBox(min: bounds.min, max: bounds.max)
        lowLevelMesh.parts.replaceAll([
            LowLevelMesh.Part(
                indexCount: indices.count,
                topology: .triangle,
                bounds: meshBounds
            ),
        ])
    }
}
