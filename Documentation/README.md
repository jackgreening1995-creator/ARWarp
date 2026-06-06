# ARWarp Documentation

ARWarp is a music-reactive augmented reality feature that warps and morphs real-world surfaces in response to audio. This folder contains the design and implementation reference for the project.

## Start Here

| Document | Purpose |
|----------|---------|
| [00_Feature_Overview.md](00_Feature_Overview.md) | Vision, goals, target experience, success criteria |
| [01_Architecture.md](01_Architecture.md) | System components, data flow, module boundaries |
| [02_Implementation_Plan.md](02_Implementation_Plan.md) | Phased delivery plan with deliverables |
| [03_Phase_5B_Proof_Runbook.md](03_Phase_5B_Proof_Runbook.md) | Manual iPhone 12 Pro Max proof workflow, artifact list, acceptance checklist |
| [04_Embedding_ARWarpKit.md](04_Embedding_ARWarpKit.md) | Supported SwiftUI host integration recipe for `ARWarpView(configuration:)` |

## Repository Layout

```
ARwarp/
├── Documentation/          ← You are here
├── Sources/
│   ├── AppHarness/         Reference demo app entry and proof defaults
│   ├── Audio/              Real-time FFT and music feature extraction
│   ├── AR/                 Public SwiftUI surface, ARKit session, scene presentation
│   ├── Deformation/        Vertex displacement, warp presets, compute pipeline
│   ├── Materials/          RealityKit / Metal materials and visual effects
│   └── Core/               Shared types and public module configuration
├── Resources/
│   └── Shaders/            Metal compute and render shaders
├── Tests/                  Unit and integration tests
└── ARWarp.xcodeproj/       App harness, ARWarpKit framework, tests
```

## Module Responsibilities

- **AppHarness** — Thin demo/proof app that instantiates `ARWarpView` with QA-friendly defaults.
- **Core** — Shared models, errors, public module configuration, and host-facing status types.
- **AR** — Owns the public `ARWarpView`, ARKit session, scene reconstruction, and mesh entity lifecycle.
- **Audio** — Captures and analyzes music; publishes bass, energy, beat, and spectral features.
- **Deformation** — Applies audio-driven displacement to reconstructed mesh vertices.
- **Materials** — Surface appearance, reactivity, and preset-specific visual language.
- **Resources/Shaders** — GPU kernels for deformation and effects.

## Development Notes

- **Target hardware:** iPhone Pro / iPad Pro with LiDAR and scene reconstruction.
- **Minimum iOS:** 18.0 (`LowLevelMesh` dynamic vertex updates).
- **Current repo slice:** Phase 6A is implemented — `ARWarpKit` exists as the embeddable framework, the app target is a thin harness, and simulator/tests/framework builds are verified. Real-device validation requires a LiDAR-equipped device with a valid Apple Developer signing identity.
- **Hardware release gate:** Phase 5B is still open until the connected iPhone 12 Pro Max passes the existing proof runbook after signing is repaired.

## Building

Open `ARWarp.xcodeproj` in Xcode, select a LiDAR-capable iPhone Pro or iPad Pro, and run the **ARWarp** scheme.

Simulator builds are useful for compile, test, and launch sanity checks, but they do not validate LiDAR scene reconstruction or real room deformation.

Required capability: **ARKit** with scene reconstruction (`meshWithClassification`).

## Supported Integration Recipe

Phase 6A supports one host embedding path: a SwiftUI app imports `ARWarpKit` and presents `ARWarpView(configuration:)`.

```swift
import SwiftUI
import ARWarpKit

struct HostView: View {
    var body: some View {
        ARWarpView(
            configuration: ARWarpModuleConfiguration(
                showsPerformanceStats: false,
                allowsAdvancedQAControls: false
            )
        )
        .ignoresSafeArea()
    }
}
```
