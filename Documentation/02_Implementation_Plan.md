# ARWarp — Implementation Plan

Phased delivery with testable milestones. Each phase ends with a runnable build on LiDAR hardware unless noted.

---

## Phase 0 — Foundation ✅

**Goal:** Repository structure, shared types, and buildable app shell.

### Deliverables

- [x] Folder structure under `/Volumes/SWITCHBLADE/ARwarp/`
- [x] Documentation (this folder)
- [x] `ARWarpConfiguration`, `ARWarpError`, `SessionState`, `AudioFeatureSnapshot` (stub)
- [x] Xcode project with iOS 17+ target
- [x] Empty module placeholders (`Audio/`, `Deformation/`, `Materials/`, `Shaders/`)

### Verification

- Project builds for generic iOS device.
- App launches to placeholder AR experience view.

---

## Phase 1 — Scene Mesh AR Session ✅

**Goal:** Live AR session that reconstructs and displays the real-world mesh.

### Deliverables

- [x] `ARWarpSessionController` with scene reconstruction enabled
- [x] `SceneMeshManager` rendering `ARMeshAnchor` geometry as RealityKit entities
- [x] `MeshResource+ARMeshGeometry` conversion helper
- [x] `ARWarpContainerView` hosting `ARView` with camera feed
- [x] Debug overlay: session state, mesh anchor count, reconstruction support flag
- [x] Camera usage description in Info.plist

### Technical Notes

- Use `ARWorldTrackingConfiguration.sceneReconstruction = .meshWithClassification`
- Enable `environmentTexturing = .automatic` for better lighting
- Semi-transparent cyan debug material for mesh visibility
- Update mesh on `didUpdate anchors` — geometry changes as user scans

### Verification

- On iPhone/iPad Pro with LiDAR: mesh appears on walls/floor as user moves
- Anchor count increases during scanning
- Session recovers from brief tracking loss
- No crash when anchors are removed

### Exit Criteria

Phase 1 complete when mesh stably overlays reconstructed surfaces for 60+ seconds of movement.

---

## Phase 2 — Audio Feature Extraction ✅

**Goal:** Real-time music analysis pipeline producing a stable feature vector.

### Deliverables

- [x] `AudioFeatureEngine` using `AVAudioEngine` microphone input tap
- [x] FFT-based band energy (bass / mids / highs) via Accelerate vDSP
- [x] Smoothed `energy` and beat/onset detection with `beatStrength`
- [x] Publish `AudioFeatureSnapshot` at analysis rate (~23 Hz @ 2048 buffer)
- [x] Microphone permission + audio session category setup
- [x] Debug HUD showing live audio meters
- [x] `AudioFeatureMeterView` integrated into AR experience

### Verification

- Features respond to music within ~50 ms perceptually
- Values normalized and clamped (no NaN/Inf)
- Works with Apple Music / Spotify playing on device speaker (mic capture)

---

## Phase 3 — Audio-Driven Test Mesh Deformation ✅

**Goal:** Prove the full pipeline: microphone → `AudioFeatureSnapshot` → visible real-time mesh deformation in AR.

### Deliverables

- [x] `DeformableGridMesh` — subdivided `LowLevelMesh` test plane (48×48 segments)
- [x] `AudioDrivenDeformer` — procedural displacement (ripple, pulse, twist)
- [x] `DeformationSceneController` — AR placement, per-frame updates via `SceneEvents.Update`
- [x] Audio integration — subscribes to `AudioFeatureEngine.snapshot` (single source of truth)
- [x] `DeformationDebugPanel` — mode picker, intensity slider, live drive-value readout
- [x] iOS 18 minimum (required for `LowLevelMesh` dynamic updates)

### Technique (documented choice)

**CPU vertex displacement on `LowLevelMesh`** — not Metal compute or CustomMaterial geometry modifier.

| Option | Why not chosen for Phase 3 |
|--------|---------------------------|
| Metal compute | Correct long-term path; deferred until scene-mesh scale is validated |
| CustomMaterial geometry modifier | Fast prototype but doesn't exercise `LowLevelMesh` path needed for `ARMeshAnchor` geometry |
| **CPU + LowLevelMesh** ✅ | Direct buffer access, easy audio mapping debug, same vertex layout as future GPU kernel |

### Audio → displacement mapping

| Feature | Drives |
|---------|--------|
| `bass` | Primary wave amplitude + wave speed (ripple/pulse/twist) |
| `energy` | Overall displacement intensity |
| `beatStrength` / `isBeat` | Sharp pulses and spikes |
| `mids` | Secondary ripples |
| `highs` | Fine high-frequency surface detail |

Tunable via `AudioDeformationMapping` and live `masterIntensity` slider.

### Verification

- Cyan grid mesh appears ~0.75 m in front of camera
- Mesh deforms visibly when music plays (device speaker + mic)
- Mode switch and intensity slider work live
- Drive readout values change with audio

### Post–Phase 3 tuning pass ✅

Lightweight feel tuning without architectural changes:

- Per-band audio attack/release (bass slow release, highs fast release)
- Snappier beat detection + faster `beatStrength` decay
- Visual `beatEnvelope` with configurable decay (`beatDecayTime`)
- `DeformationDriveSmoother` decouples FFT jitter from mesh motion
- `quietLevelBoost` for moderate playback levels
- Mode-specific rebalance (ripple/pulse/twist distinct characters)
- Live tuning sliders: beat punch, bass weight, beat decay

---

## Phase 4 — Scene Mesh Deformation ✅

**Goal:** Apply audio-driven displacement to reconstructed `ARMeshAnchor` geometry (the real room).

### Deliverables

- [x] `ARMeshGeometryExtractor` — shared ARKit geometry parsing
- [x] `DeformableSceneMesh` — `ARMeshGeometry` → `LowLevelMesh` + GPU base buffers
- [x] `SceneDeformation.metal` — compute kernel displacing along surface normals
- [x] `MetalSceneDeformer` — command buffer dispatch via `LowLevelMesh.replace`
- [x] `SceneMeshDeformationManager` — anchor lifecycle, budget, distance culling
- [x] Shared `DeformationDriveSmoother` feeding both GPU scene + optional CPU test grid
- [x] Deformation target picker: Room / Grid / Both
- [x] Debug HUD: active chunks, GPU verts, GPU ms
- [x] Scene understanding occlusion enabled on `ARView`

### Performance strategy

- Max **8 chunks/frame** (closest to camera, round-robin over time)
- Max **32,768 vertices/chunk** (larger anchors skipped)
- Max **5.25 m** deformation radius from camera
- Geometry rebuild cooldown **350 ms** on anchor updates

### Stabilization notes

- Chunks that leave the active budget or deformation radius are explicitly written back to rest pose.
- Turning room deformation off, detaching the controller, or restarting the AR session queues full resets for already-deformed chunks, including chunks from an in-flight GPU submission.
- `MetalSceneDeformer` now commits work asynchronously; the main actor no longer calls `waitUntilCompleted()`.
- Base geometry is not refreshed while a GPU submission is in flight, which avoids mutating source buffers mid-dispatch at the cost of briefly deferring some ARKit mesh refinements.

### Verification

- Walls/floor warp in response to music on LiDAR device
- GPU ms readout stable at room scale with chunk budget

---

## Phase 5A — Warp Presets & Polish ✅

**Goal:** Production visual quality, preset registry, performance hardening.

### Deliverables

- [x] `WarpPresetID`, `WarpPreset`, `WarpVisualStyle`, and `WarpPresetRegistry`
- [x] Presets: **Flow**, **Fracture** + refined room/grid materials
- [x] Reactive materials (emissive, opacity tied to energy)
- [x] Anchor update fade-in / fade-out retirement to reduce pop-in
- [x] Unit tests for preset registry and fade helpers

### Verification

- Simulator build / run sanity
- Simulator unit tests for preset registry and fade helpers
- Unsigned `iphoneos` compile

Phase 5A is complete in code when the preset/material/fade system is merged and the non-device gates stay green.

## Phase 5B — LiDAR Demo Lock 🚧

**Goal:** Close Phase 5 on the real LiDAR phone with a stable demo path and a documented manual proof workflow.

### Deliverables

- [x] Runtime hardening for attach/detach, pause/resume, and resumed-frame deformation spikes
- [x] Manual proof runbook under `Documentation/03_Phase_5B_Proof_Runbook.md`
- [x] Fresh simulator launch sanity with the lightweight deck + explicit unsupported-state UI
- [x] Fresh simulator unit tests
- [x] Fresh unsigned `iphoneos` compile
- [ ] Signed build/install on the connected iPhone 12 Pro Max
- [ ] Real LiDAR proof bundle (scan baseline, Flow, Fracture, collapsed-deck capture, performance note)

### Verification

- Simulator build / run sanity
- Simulator unit tests for preset registry and fade helpers
- Unsigned `iphoneos` compile
- Signed device build/install on iPhone 12 Pro Max
- 60 fps sustained in 3×3 m room with 20+ mesh anchors on LiDAR hardware
- Visual review against liminal/sentient aesthetic target on real hardware

### Current Blocker Snapshot

Fresh on **May 25, 2026**:

- Connected destination is visible: `jackalexander` (iPhone 12 Pro Max)
- Signed build is blocked on this Mac before install:
  - `No Account for Team (signing identity)`
  - `No profiles for 'com.jackgreening.arwarp' were found`

Phase 5B stays open until signing is repaired and the proof bundle is captured on the real device.

---

## Phase 6A — Embeddable Module & Demo Harness 🚧

**Goal:** Turn ARWarp into an embeddable iOS framework while preserving the standalone app as the proof and QA harness.

### Deliverables

- [x] `ARWarpKit` framework target in `project.yml`
- [x] Thin `ARWarp` app harness target that depends on `ARWarpKit`
- [x] Public SwiftUI entry: `ARWarpView(configuration:)`
- [x] Public host types: `ARWarpModuleConfiguration`, `ARWarpChromeTheme`, `ARWarpStatusSnapshot`
- [x] `WarpPresetID`, `SessionState`, and `ARWarpError` exported as public `Sendable` types
- [x] Framework-aware shader bundle loading in the Metal deformation path
- [x] Unit tests moved to target `ARWarpKit`
- [x] Docs recipe for SwiftUI host embedding
- [ ] Rerun the Phase 5B real-device proof runbook after signing is repaired

### Verification

- Simulator build / run sanity for the harness app
- Simulator unit tests remain green
- Direct `ARWarpKit` framework build for iPhone Simulator
- Direct `ARWarpKit` framework build for `iphoneos`
- Unsigned `iphoneos` compile for the harness app
- Existing Phase 5B iPhone 12 Pro Max proof runbook rerun after signing recovery

### Current Blocker Snapshot

Fresh on **May 25, 2026**:

- `ARWarpKit` now builds directly for iPhone Simulator and `iphoneos`
- `ARWarp` harness still builds, tests, and launches in simulator
- Signed build for the connected iPhone 12 Pro Max is still blocked on this Mac:
  - `No Account for Team (signing identity)`
  - `No profiles for 'com.jackgreening.arwarp' were found`

Phase 6A stays open until the existing Phase 5B proof runbook is rerun successfully on the real LiDAR phone after signing is repaired.

---

## Phase 6B — Host Integration & Ship Prep

**Goal:** Ready for broader embedding and release preparation after the module split is proven on hardware.

### Deliverables

- Host-app integration checklist beyond the local harness
- Distribution/readiness checklist
- QA closeout for release candidates

---

## Risk Register

| Risk | Mitigation |
|------|------------|
| Mesh update stalls main thread | Incremental updates; cap anchors per frame |
| Audio latency | Small FFT windows; parallel analysis queue |
| GPU memory pressure | Pool buffers; drop distant anchors |
| Simulator lacks LiDAR | Clear unsupported UI; Test on device |

---

## Current Status

| Phase | Status |
|-------|--------|
| 0 | Complete |
| 1 | Complete |
| 2 | Complete |
| 3 | Complete (+ tuning pass) |
| 4 | Complete (stabilized, pending on-device LiDAR validation) |
| 5A | Complete in code |
| 5B | In progress; blocked on current Mac signing/provisioning for real-device proof |
| 6A | In progress in repo; framework split complete, waiting on post-split real-device rerun |
| 6B | Not started |

Next action: set up a valid Apple Developer signing identity, then execute `Documentation/03_Phase_5B_Proof_Runbook.md` on a LiDAR-equipped iPhone Pro or iPad Pro to close Phase 5B and verify the Phase 6A module split on hardware.
