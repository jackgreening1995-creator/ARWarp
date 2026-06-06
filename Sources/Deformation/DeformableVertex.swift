import RealityKit
import simd

/// Shared GPU/CPU vertex layout for deformable meshes (test grid + scene chunks).
///
/// Metal shader `SceneDeformation.metal` must keep this layout in sync:
/// - `position`: float3 @ offset 0
/// - `normal`: float3 @ offset 12
/// - stride: 24 bytes
struct DeformableVertex {
    var position: SIMD3<Float> = .zero
    var normal: SIMD3<Float> = [0, 1, 0]
}

extension DeformableVertex {
    static var vertexAttributes: [LowLevelMesh.Attribute] {
        [
            .init(
                semantic: .position,
                format: .float3,
                offset: MemoryLayout<Self>.offset(of: \.position)!
            ),
            .init(
                semantic: .normal,
                format: .float3,
                offset: MemoryLayout<Self>.offset(of: \.normal)!
            ),
        ]
    }

    static var vertexLayouts: [LowLevelMesh.Layout] {
        [.init(bufferIndex: 0, bufferStride: MemoryLayout<Self>.stride)]
    }

    static func makeDescriptor(vertexCount: Int, indexCount: Int) -> LowLevelMesh.Descriptor {
        var descriptor = LowLevelMesh.Descriptor()
        descriptor.vertexAttributes = vertexAttributes
        descriptor.vertexLayouts = vertexLayouts
        descriptor.vertexCapacity = vertexCount
        descriptor.indexCapacity = indexCount
        descriptor.indexType = .uint32
        return descriptor
    }
}
