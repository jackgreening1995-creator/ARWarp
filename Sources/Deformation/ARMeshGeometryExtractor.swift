import ARKit
import Foundation
import simd

/// Parsed vertex data extracted from `ARMeshGeometry`.
struct ARMeshGeometryData: Sendable {
    var positions: [SIMD3<Float>]
    var normals: [SIMD3<Float>]
    var indices: [UInt32]
    var bounds: (min: SIMD3<Float>, max: SIMD3<Float>)

    var vertexCount: Int { positions.count }
    var indexCount: Int { indices.count }

    var center: SIMD3<Float> {
        (bounds.min + bounds.max) * 0.5
    }

    var centerXZ: SIMD2<Float> {
        SIMD2(center.x, center.z)
    }
}

enum ARMeshGeometryExtractor {
    static func extract(from geometry: ARMeshGeometry) throws -> ARMeshGeometryData {
        let vertexCount = geometry.vertices.count
        guard vertexCount > 0 else {
            throw ARWarpError.meshConversionFailed
        }

        let vertexBuffer = geometry.vertices.buffer.contents()
        let vertexStride = geometry.vertices.stride
        let vertexOffset = geometry.vertices.offset

        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity(vertexCount)

        var minBounds = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maxBounds = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)

        for index in 0..<vertexCount {
            let base = vertexOffset + index * vertexStride
            let floatPointer = vertexBuffer.advanced(by: base).assumingMemoryBound(to: Float.self)
            let position = SIMD3(floatPointer[0], floatPointer[1], floatPointer[2])
            positions.append(position)
            minBounds = min(minBounds, position)
            maxBounds = max(maxBounds, position)
        }

        var normals = [SIMD3<Float>](repeating: SIMD3(0, 1, 0), count: vertexCount)
        if geometry.normals.count == vertexCount {
            let normalBuffer = geometry.normals.buffer.contents()
            let normalStride = geometry.normals.stride
            let normalOffset = geometry.normals.offset

            for index in 0..<vertexCount {
                let base = normalOffset + index * normalStride
                let floatPointer = normalBuffer.advanced(by: base).assumingMemoryBound(to: Float.self)
                let normal = SIMD3(floatPointer[0], floatPointer[1], floatPointer[2])
                normals[index] = length(normal) > 0.0001 ? normalize(normal) : SIMD3(0, 1, 0)
            }
        }

        let faceCount = geometry.faces.count
        guard faceCount > 0 else {
            throw ARWarpError.meshConversionFailed
        }

        let indexBuffer = geometry.faces.buffer.contents()
        let indexBytesPerIndex = geometry.faces.bytesPerIndex
        let indexCount = faceCount * 3

        var indices: [UInt32] = []
        indices.reserveCapacity(indexCount)

        for faceIndex in 0..<faceCount {
            for corner in 0..<3 {
                let indexOffset = (faceIndex * 3 + corner) * indexBytesPerIndex
                let indexPointer = indexBuffer.advanced(by: indexOffset)

                let index: UInt32
                switch indexBytesPerIndex {
                case 2:
                    index = UInt32(indexPointer.assumingMemoryBound(to: UInt16.self).pointee)
                case 4:
                    index = indexPointer.assumingMemoryBound(to: UInt32.self).pointee
                default:
                    throw ARWarpError.meshConversionFailed
                }
                indices.append(index)
            }
        }

        return ARMeshGeometryData(
            positions: positions,
            normals: normals,
            indices: indices,
            bounds: (min: minBounds, max: maxBounds)
        )
    }
}
