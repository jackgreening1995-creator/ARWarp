# Shaders

## SceneDeformation.metal

GPU compute kernel for Phase 4 room mesh warping.

### Vertex layout (`DeformableVertex` — 24 bytes)

| Field | Type | Offset |
|-------|------|--------|
| position | float3 | 0 |
| normal | float3 | 12 |

Swift mirror: `Sources/Deformation/DeformableVertex.swift`

### Uniforms (`AudioDeformUniforms`)

Uploaded per chunk; must match Swift struct in `AudioDeformUniforms.swift`.

### Kernel: `deformSceneVertices`

Reads `basePositions` + `baseNormals`, computes scalar displacement along normal, writes `DeformableVertex` buffer in place via `LowLevelMesh.replace(bufferIndex:using:)`.
