# ARWarp

Music-reactive AR that warps real-world surfaces in response to sound.

ARWarp uses ARKit scene reconstruction with LiDAR to capture room geometry, then applies Metal compute shaders to displace vertex buffers driven by real-time FFT audio analysis. The result: walls, floors, and surfaces feel alive — as if the room itself is responding to music.

## Current Status

**Phase 6A — framework split and demo harness.** Simulator builds and unit tests pass. Real-device validation on iPhone 12 Pro Max is blocked by an Apple Developer account / provisioning profile issue.

Simulator builds and unit tests pass. Real-device validation requires a LiDAR-equipped iPhone Pro or iPad Pro with a valid Apple Developer signing identity.

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9 |
| AR | ARKit (scene reconstruction with LiDAR) |
| Rendering | RealityKit + Metal compute shaders |
| Audio | AVAudioEngine + FFT |
| Project generation | XcodeGen (`project.yml`) |
| Minimum deployment | iOS 18.0, Xcode 16+ |
| Required hardware | LiDAR-equipped iPhone Pro or iPad Pro |

## Project Structure

```
Sources/
├── AppHarness/   Demo app entry (thin harness, 1 file)
├── Core/         Shared types, module configuration, errors
├── AR/           Public SwiftUI surface, ARKit session, mesh rendering
├── Audio/        Music capture, FFT analysis, feature extraction
├── Deformation/  GPU vertex displacement, chunk lifecycle, compute pipeline
└── Materials/    Presets and reactive materials

Resources/
└── Shaders/      Metal compute/render shaders

Tests/            Unit tests (11 tests, 3 suites)

Documentation/    Architecture, implementation plan, proof runbook, embedding guide
```

Three Xcode targets:
- **ARWarpKit** — embeddable iOS framework with the public `ARWarpView`
- **ARWarp** — thin demo/proof harness app
- **ARWarpTests** — unit test bundle

## Setup

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) if not already installed:
   ```bash
   brew install xcodegen
   ```
2. Regenerate the Xcode project:
   ```bash
   xcodegen generate --spec project.yml
   ```
3. Open `ARWarp.xcodeproj` in Xcode 16+.
4. In the ARWarp target > Signing & Capabilities, set a Development Team.
5. Select a LiDAR-capable iPhone Pro or iPad Pro as the run destination.

## Run

Select the **ARWarp** scheme in Xcode and run. Grant Camera and Microphone access when prompted. Move slowly to scan the room — the reconstructed mesh will appear, and audio-driven warping will begin.

Simulator builds launch but cannot validate LiDAR scene reconstruction.

## Test / Build

### Simulator build and test

```bash
xcodebuild -project ARWarp.xcodeproj \
  -scheme ARWarp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build test
```

### Device build (unsigned)

```bash
xcodebuild -project ARWarp.xcodeproj \
  -scheme ARWarp \
  -destination 'generic/platform=iOS' \
  build
```

### Project listing

```bash
xcodebuild -list -project ARWarp.xcodeproj
xcodegen generate --spec project.yml   # regenerate ARWarp.xcodeproj
```

## Known Issues

- **Cannot install on real device.** Real-device deployment requires a valid Apple Developer signing identity. Set your Development Team in Xcode under Signing & Capabilities for the ARWarp target.
- **LiDAR proof unconfirmed.** Phase 5B real-device LiDAR verification is blocked until signing is resolved.
- **No App Store distribution.** No production signing, no App Store Connect setup, no icon assets beyond the default.
- **Simulator only validates compilation and tests.** Runtime AR behavior (scene reconstruction, mesh updates, deformation) cannot be verified in simulator.

## Roadmap

See [ROADMAP.md](ROADMAP.md) for planned features and priorities.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT — see [LICENSE](LICENSE).

## Documentation

- [Documentation/README.md](Documentation/README.md) — architecture and implementation plan
- [Documentation/00_Feature_Overview.md](Documentation/00_Feature_Overview.md) — vision and success criteria
- [Documentation/01_Architecture.md](Documentation/01_Architecture.md) — system components and data flow
- [Documentation/02_Implementation_Plan.md](Documentation/02_Implementation_Plan.md) — phased delivery plan
- [Documentation/03_Phase_5B_Proof_Runbook.md](Documentation/03_Phase_5B_Proof_Runbook.md) — manual proof workflow
- [Documentation/04_Embedding_ARWarpKit.md](Documentation/04_Embedding_ARWarpKit.md) — SwiftUI host integration recipe
