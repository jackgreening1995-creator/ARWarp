# ARWarp — Architecture

## High-Level Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│            Host SwiftUI app or ARWarp demo harness              │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                         ARWarpView                              │
│              (public SwiftUI entry in ARWarpKit)                │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                    ARWarpExperienceView                         │
│                 (internal status + controls shell)              │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                      ARWarpContainerView                        │
│                   (UIViewRepresentable → ARView)                │
└────────────┬───────────────────────────────┬────────────────────┘
             │                               │
┌────────────▼────────────┐     ┌────────────▼────────────────────┐
│ ARWarpSessionController │     │   DeformationSceneController     │
│  - ARSession config     │     │  - audio → drive smoothing       │
│  - delegate callbacks   │────▶│  - grid + room update policy     │
│  - state publishing     │     │  - reset on disable / detach     │
└────────────┬────────────┘     └────────────┬────────────────────┘
             │                               │
             │         ARKit                 │         RealityKit / Metal
             ▼                               ▼
      ARMeshAnchor                 SceneMeshDeformationManager
             │                     - chunk lifecycle + budgeting
             │                     - async GPU submission
             ▼                     - explicit rest-pose resets
┌────────────────────────┐                    │
│   AudioFeatureEngine   │────────────────────┘
│  - AVAudioEngine       │
│  - FFT / beat detect   │
└────────────────────────┘
```

## Module Boundaries

### App Harness (`Sources/AppHarness/`)

Reference demo app that stays in the repo even after the framework split.

| Type | Role |
|------|------|
| `ARWarpApp` | `@main` entry for the standalone harness app |

**Contract:** Harness-only defaults live here. Reusable ARWarp feature code does not.

### Core (`Sources/Core/`)

Shared foundation used by all modules.

| Type | Role |
|------|------|
| `ARWarpConfiguration` | Feature flags, mesh appearance defaults, session options |
| `ARWarpError` | Typed errors for session, mesh, audio, and GPU paths |
| `AudioFeatureSnapshot` | Immutable audio feature vector published by the audio engine |
| `SessionState` | Published AR session lifecycle state |
| `ARWarpModuleConfiguration` | Public host-facing module configuration |
| `ARWarpChromeTheme` | Public HUD chrome tint/overlay theme |
| `ARWarpStatusSnapshot` | Public host-facing runtime state snapshot |

**Contract:** Core must not import ARKit or RealityKit. Keeps types portable for tests.

### AR (`Sources/AR/`)

Owns everything between ARKit callbacks and visible mesh entities.

| Component | Responsibility |
|-----------|----------------|
| `ARWarpView` | Public SwiftUI entry point for host apps |
| `ARWarpSessionController` | Configures `ARWorldTrackingConfiguration`, implements `ARSessionDelegate`, publishes session state |
| `SceneMeshDeformationManager` | Maps `ARMeshAnchor` → deformable scene chunk, handles add/update/remove |
| `MeshResource+ARMeshGeometry` | Converts `ARMeshGeometry` to RealityKit `MeshResource` |
| `ARWarpContainerView` | Hosts `ARView`, wires controller + mesh manager |
| `ARWarpExperienceView` | Internal SwiftUI experience shell with configurable controls/status deck |

**Data flow:**
1. ARKit delivers `ARMeshAnchor` on session delegate.
2. `SceneMeshDeformationManager` builds or updates deformable scene chunks from anchor geometry.
3. Entities attach at anchor transforms; deformation updates happen through `LowLevelMesh`.

### Audio (`Sources/Audio/`)

| Component | Responsibility |
|-----------|----------------|
| `AudioFeatureEngine` | Mic tap, FFT, beat detection, `@Published` snapshots |
| `FFTAnalyzer` | Hann-windowed vDSP FFT, band energy extraction |
| `FeatureSmoother` / `BeatDetector` | Normalization and onset detection |

**Output:** `AudioFeatureSnapshot` with `bass`, `mids`, `highs`, `energy`, `isBeat`, `beatStrength`, `timestamp`.

### Deformation (`Sources/Deformation/`)

| Component | Responsibility |
|-----------|----------------|
| `DeformableSceneMesh` | One `ARMeshAnchor` → `LowLevelMesh` + Metal base buffers |
| `SceneMeshDeformationManager` | Anchor lifecycle, chunk budget, GPU dispatch |
| `MetalSceneDeformer` | Metal compute pipeline (`SceneDeformation.metal`) |
| `DeformableGridMesh` | Phase 3 CPU test grid (optional via deformation target) |
| `AudioDrivenDeformer` | CPU test-grid displacement |
| `DeformationDriveSmoother` | Shared audio → drive smoothing for CPU + GPU paths |
| `ARMeshGeometryExtractor` | Parses `ARMeshGeometry` positions/normals/indices |

**Phase 5A path:** `AudioFeatureSnapshot` → `DeformationDriveSmoother` → `WarpPreset` defaults + QA overrides → `AudioDeformUniforms` → Metal compute → `LowLevelMesh` vertex buffer (in-place, no mesh rebuild per frame).

### Chunk Lifecycle And Reset Semantics

1. `ARMeshAnchor` add/update creates or refreshes a `DeformableSceneMesh` chunk.
2. Each active frame, `SceneMeshDeformationManager` selects a budgeted subset of nearby chunks and submits one asynchronous Metal compute pass.
3. Newly created chunks fade in over a short visibility ramp instead of snapping fully on.
4. Replaced or removed chunks move into a retiring pool, fade out, then detach from the scene graph.
5. Chunks that were deformed previously but are no longer selected receive an explicit rest-pose pass, so stale warped geometry does not persist.
6. Disabling room deformation, detaching the controller, or resetting the AR session queues a full rest-pose submission for all known deformed chunks, including chunks already in flight on the GPU.
7. Base-geometry refresh is deferred while a submission is in flight so ARKit updates do not mutate buffers the GPU may still be reading.

### Materials (`Sources/Materials/`)

| Component | Responsibility |
|-----------|----------------|
| `WarpPresetRegistry` | Source of truth for `Flow` and `Fracture` |
| `SceneMeshMaterialFactory` | Builds scan / active / retiring room materials plus grid materials from `WarpVisualStyle` |

### Resources (`Resources/Shaders/`)

Metal source for compute deformation and future surface effects. Loaded from the owning framework bundle so `ARWarpKit` can embed cleanly in a host app.

## Public Embedding Contract

Phase 6A exposes a narrow public API:

- `ARWarpView(configuration:)`
- `ARWarpModuleConfiguration`
- `ARWarpChromeTheme`
- `ARWarpStatusSnapshot`
- `WarpPresetID`
- `SessionState`
- `ARWarpError`

Hosts do not control the low-level audio pipeline, AR session lifecycle, shader parameters, or QA-only tuning surface in this phase.

## Threading Model

| Work | Thread |
|------|--------|
| ARSession delegate | ARKit callback queue → dispatch to main for entity updates |
| RealityKit rendering | Main / render thread (managed by ARView) |
| Audio tap | Audio thread → FFT / feature extraction queue → publish snapshot to main |
| Metal compute | Encoded on the main actor (`LowLevelMesh` is `@MainActor`), committed to a dedicated `MTLCommandQueue`, and completed asynchronously without `waitUntilCompleted()` |

The deformation path avoids blocking ARKit or RealityKit on GPU completion. Only command encoding touches the main actor; command-buffer completion updates bookkeeping later on the main actor.

## State Ownership

```
ARWarpSessionController (Observable)
  ├── sessionState: SessionState
  ├── meshAnchorCount: Int
  └── isSceneReconstructionSupported: Bool

SceneMeshDeformationManager
  ├── chunks: [UUID: DeformableSceneMesh]
  ├── activeVisibilityStates: [UUID: ChunkVisibilityState]
  ├── retiringChunks: [RetiringChunk]
  ├── deformedChunkIdentifiers: Set<UUID>
  └── queuedResetIdentifiers: Set<UUID>

AudioFeatureEngine (Observable)
  └── snapshot: AudioFeatureSnapshot
```

## Configuration

`ARWarpConfiguration` centralizes:

- Scene reconstruction mode (`.meshWithClassification`)
- Plane detection (optional, off by default in warp mode)
- Debug mesh opacity and color
- Performance caps (chunk budget, vertex limit, deformation distance)

## Error Handling

Failures surface as `ARWarpError` and publish to UI:

- `.sceneReconstructionUnavailable` — device lacks LiDAR / capability
- `.sessionFailed(underlying)` — ARKit runtime failure
- `.meshConversionFailed` — geometry → MeshResource failure
- `.deformationPipelineFailed` — Metal or `LowLevelMesh` submission failure

Scene-mesh deformation fails soft where possible: bad anchors are skipped, queued resets are retried on later frames, and late GPU completions from an older session are ignored.

## Extension Points

1. **Warp presets** — `WarpPresetRegistry` can be extended with additional preset IDs, mappings, and visual styles.
2. **Material themes** — `SceneMeshMaterialFactory` consumes `WarpVisualStyle`, so new looks do not require mesh-lifecycle rewrites.
3. **Audio mappers** — Preset defaults plus targeted QA overrides shape `AudioDeformUniforms` without forking the pipeline.

## Dependencies

| Framework | Usage |
|-----------|-------|
| ARKit | Session, mesh anchors, world tracking |
| RealityKit | ARView, entities, materials, `LowLevelMesh` |
| Metal | Compute deformation |
| AVFoundation | Audio engine |
| SwiftUI | App shell and overlays |
