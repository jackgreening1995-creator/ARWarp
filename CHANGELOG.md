# Changelog

All notable changes to ARWarp will be documented in this file.

## [0.1.0] — Initial Public Release

### Added
- `ARWarpKit` embeddable iOS framework with public `ARWarpView`
- ARKit scene reconstruction with LiDAR (`ARMeshAnchor` → `LowLevelMesh`)
- Metal compute shader vertex displacement (`SceneDeformation.metal`)
- Real-time FFT audio analysis engine (`AudioFeatureEngine`, `FFTAnalyzer`)
- Audio-driven mesh deformation pipeline (`AudioDrivenDeformer`, `SceneMeshDeformationManager`)
- Two warp presets: `bassPulse` (bass drives uniform offset) and `spectralRipple` (spectral spread maps to vertex normal offset)
- Reference demo app harness (`ARWarpApp.swift`)
- Unit tests: `ARWarpModuleConfigurationTests`, `ChunkVisibilityStateTests`, `WarpPresetRegistryTests`
- MIT License
- Documentation: architecture, implementation plan, proof runbook, embedding guide
- CI: GitHub Actions build workflow
- Project generation via XcodeGen (`project.yml`)

### Requirements
- iOS 18.0+
- Xcode 16.0+
- LiDAR-equipped iPhone Pro or iPad Pro (for real-device AR)
- Swift 5.9
