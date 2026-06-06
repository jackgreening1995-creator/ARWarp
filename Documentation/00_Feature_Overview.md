# ARWarp — Feature Overview

## Vision

ARWarp adds an AR mode where the physical environment around the user warps, ripples, pulses, and morphs in real time based on music. Walls, floors, and surfaces should feel alive — as if the room itself is listening and responding to sound.

The aesthetic target is **procedural**, **sentient**, and **liminal**: not cartoonish distortion, but organic, high-fidelity surface motion that feels tied to musical structure and energy.

## Goals

1. **Musical reactivity** — Deformation and visuals track bass, transients, energy, and rhythm with low perceived latency.
2. **Environmental fidelity** — Warping follows real reconstructed geometry from the user's space, not abstract planes.
3. **Visual quality** — Smooth motion, coherent materials, and preset-specific art direction.
4. **Performance** — Stable frame rate on LiDAR devices during live AR + audio analysis + GPU deformation.
5. **Extensibility** — Clear module boundaries so agents and developers can add presets, shaders, and audio mappings safely.

## Target Experience

1. User launches ARWarp and grants camera (and later microphone) access.
2. The app scans the room; reconstructed mesh appears subtly overlaid on surfaces.
3. Music plays (device audio or mic capture); surfaces begin to warp in sync.
4. User can switch polished warp presets (currently **Flow** and **Fracture**) with distinct motion and material response.
5. The effect feels immediate, musical, and immersive — the room becomes part of the performance.

## Core Technical Approach

| Layer | Technology |
|-------|------------|
| Scene capture | ARKit scene reconstruction → `ARMeshAnchor` |
| Rendering | RealityKit `ModelEntity` + `LowLevelMesh` |
| Deformation | Metal compute shaders displacing vertex buffers |
| Audio analysis | `AVAudioEngine` + FFT → feature vector per frame |
| Presets | Configurable mappings from audio features → shader uniforms |

## Key Requirements

- Must feel **musical and responsive** (< 50 ms perceived audio-to-motion delay target).
- Prioritize **visual quality** over feature count in early phases.
- **Performant on LiDAR devices** (iPhone Pro, iPad Pro); degrade gracefully elsewhere.
- **Clean, agent-friendly code** — small files, explicit types, documented module contracts.

## Success Criteria

### Current Proof Gap
- [ ] AR session runs with world tracking and scene reconstruction enabled.
- [ ] Reconstructed mesh renders on real surfaces and updates as the scene changes.
- [ ] Stable on device; clear debug/status UI for mesh anchor count and session state.

### MVP (Phases 2–5B)
- [ ] Real-time audio features drive visible mesh deformation.
- [ ] At least two distinct warp presets with smooth switching.
- [ ] Sustained 60 fps on iPhone Pro class hardware in a typical room.

### Phase 5A (Completed In Code)
- [x] Formal preset registry with `Flow` and `Fracture`
- [x] Reactive room/grid materials tied to preset visual style
- [x] Chunk fade-in / fade-out smoothing for anchor churn
- [x] Unit tests for preset registry and fade helpers

### Phase 5B (Current Hardware Gate)
- [x] Runtime hardening for attach/detach, pause/resume, and resumed-frame stability
- [x] Manual proof runbook for the iPhone 12 Pro Max validation pass
- [x] Fresh simulator launch + test + unsigned `iphoneos` proof on May 25, 2026
- [ ] Signed install from this Mac to the iPhone 12 Pro Max
- [ ] Real-device LiDAR capture bundle for final closeout

### Phase 6A (Current Repo Slice)
- [x] `ARWarpKit` framework target plus thin `ARWarp` demo/proof harness
- [x] Public SwiftUI embedding surface: `ARWarpView(configuration:)`
- [x] Public module configuration, chrome theme, and status snapshot types
- [x] Supported SwiftUI host integration recipe in docs
- [x] Fresh harness launch, tests, and direct `ARWarpKit` build proof on May 25, 2026
- [ ] Post-split rerun of the Phase 5B LiDAR proof bundle after signing is repaired

### v1 Quality Bar
- [ ] Beat-aligned pulses feel tight to music.
- [ ] Materials respond to frequency bands (e.g. bass vs highs).
- [ ] No visible mesh popping during anchor updates.
- [ ] Documented preset format for adding new warp styles.

## Non-Goals (Early Phases)

- Multi-user / shared AR sessions
- Persistent room saves or mesh export
- Android / cross-platform support
- User-authored shader graphs

## Related Documents

- [01_Architecture.md](01_Architecture.md) — How components connect
- [02_Implementation_Plan.md](02_Implementation_Plan.md) — Phased delivery schedule
