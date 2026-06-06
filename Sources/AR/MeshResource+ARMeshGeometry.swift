import ARKit
import RealityKit

extension MeshResource {
    /// Builds a RealityKit mesh from ARKit scene reconstruction geometry.
    static func from(arGeometry geometry: ARMeshGeometry) throws -> MeshResource {
        let data = try ARMeshGeometryExtractor.extract(from: geometry)

        var descriptor = MeshDescriptor(name: "ARSceneMesh")
        descriptor.positions = MeshBuffer(data.positions)
        descriptor.primitives = .triangles(data.indices)
        descriptor.normals = MeshBuffer(data.normals)

        return try MeshResource.generate(from: [descriptor])
    }
}
