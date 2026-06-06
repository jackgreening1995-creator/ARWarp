import RealityKit
import simd

/// Vertex layout for the deformable test grid (`LowLevelMesh` buffer 0).
/// Uses shared `DeformableVertex` — same layout as scene mesh Metal kernel.
///
/// Phase 3 uses CPU displacement via `withUnsafeMutableBytes`. The same buffer layout is
/// compatible with a future Metal compute pass (`replace(bufferIndex:using:)`).
@MainActor
final class DeformableGridMesh {
    let lowLevelMesh: LowLevelMesh
    let meshResource: MeshResource

    let segments: Int
    let vertexCount: Int
    let basePositions: [SIMD3<Float>]
    let gridCoordinates: [SIMD2<Float>]

    private let bounds: BoundingBox

    init(segments: Int = DeformationConfiguration.gridSegments) throws {
        self.segments = segments
        let vertexColumns = segments + 1
        self.vertexCount = vertexColumns * vertexColumns

        let triangleCount = segments * segments * 2
        let indexCount = triangleCount * 3

        let descriptor = DeformableVertex.makeDescriptor(vertexCount: vertexCount, indexCount: indexCount)
        self.lowLevelMesh = try LowLevelMesh(descriptor: descriptor)
        self.meshResource = try MeshResource(from: lowLevelMesh)

        let halfWidth = DeformationConfiguration.gridWidth * 0.5
        let halfDepth = DeformationConfiguration.gridDepth * 0.5

        var positions: [SIMD3<Float>] = []
        var coordinates: [SIMD2<Float>] = []
        positions.reserveCapacity(vertexCount)
        coordinates.reserveCapacity(vertexCount)

        for row in 0..<vertexColumns {
            let v = Float(row) / Float(segments)
            for column in 0..<vertexColumns {
                let u = Float(column) / Float(segments)
                let x = (u * 2 - 1) * halfWidth
                let z = (v * 2 - 1) * halfDepth
                positions.append(SIMD3(x, 0, z))
                coordinates.append(SIMD2(u, v))
            }
        }

        self.basePositions = positions
        self.gridCoordinates = coordinates
        self.bounds = BoundingBox(
            min: [-halfWidth, -0.2, -halfDepth],
            max: [halfWidth, 0.2, halfDepth]
        )

        try populateStaticIndices(triangleCount: triangleCount)
        try writeVertices(positions: positions, normals: Array(repeating: SIMD3(0, 1, 0), count: vertexCount))
    }

    func writeVertices(positions: [SIMD3<Float>], normals: [SIMD3<Float>]) throws {
        guard positions.count == vertexCount, normals.count == vertexCount else {
            throw ARWarpError.deformationPipelineFailed("Vertex count mismatch")
        }

        lowLevelMesh.withUnsafeMutableBytes(bufferIndex: 0) { rawBytes in
            let vertices = rawBytes.bindMemory(to: DeformableVertex.self)
            for index in 0..<vertexCount {
                vertices[index].position = positions[index]
                vertices[index].normal = normals[index]
            }
        }
    }

    private func populateStaticIndices(triangleCount: Int) throws {
        var indices: [UInt32] = []
        indices.reserveCapacity(triangleCount * 3)

        let columns = segments + 1
        for row in 0..<segments {
            for column in 0..<segments {
                let topLeft = UInt32(row * columns + column)
                let topRight = topLeft + 1
                let bottomLeft = UInt32((row + 1) * columns + column)
                let bottomRight = bottomLeft + 1

                indices.append(contentsOf: [topLeft, bottomLeft, topRight])
                indices.append(contentsOf: [topRight, bottomLeft, bottomRight])
            }
        }

        lowLevelMesh.withUnsafeMutableIndices { rawIndices in
            let indexBuffer = rawIndices.bindMemory(to: UInt32.self)
            for (offset, index) in indices.enumerated() {
                indexBuffer[offset] = index
            }
        }

        lowLevelMesh.parts.replaceAll([
            LowLevelMesh.Part(
                indexCount: indices.count,
                topology: .triangle,
                bounds: bounds
            ),
        ])
    }
}
