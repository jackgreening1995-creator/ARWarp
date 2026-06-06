#include <metal_stdlib>
using namespace metal;

/// Must match Swift `DeformableVertex` — 24-byte stride.
struct DeformableVertex {
    float3 position;
    float3 normal;
};

/// Must match Swift `AudioDeformUniforms`.
struct AudioDeformUniforms {
    float time;
    float deltaTime;
    float bassDrive;
    float energyDrive;
    float beatDrive;
    float midsDrive;
    float highsDrive;
    float beatEnvelope;
    uint mode;
    float bassSpeedScale;
    float chunkCenterX;
    float chunkCenterZ;
};

constant uint kModeRipple = 0;
constant uint kModePulse = 1;
constant uint kModeTwist = 2;

/// Scalar displacement adapted from Phase 3 — applied along surface normal for room geometry.
inline float sceneDisplacement(float3 base,
                               float3 normal,
                               constant AudioDeformUniforms& u) {
    float waveSpeed = 1.0 + u.bassDrive * 6.0 / max(u.bassSpeedScale, 0.01);
    float3 radialOffset = base - float3(u.chunkCenterX, base.y, u.chunkCenterZ);
    float radial = length(radialOffset.xz);
    float t = u.time;

    float primary = sin(dot(base, float3(1.1, 0.7, 0.9)) * 3.2 + t * waveSpeed);
    float secondary = cos(dot(base, float3(0.8, 0.5, 1.3)) * 2.6 - t * waveSpeed * 0.65);

    float body = 0;
    float beat = 0;
    float detail = 0;

    if (u.mode == kModeRipple) {
        body = (primary * 0.6 + secondary * 0.4) * (u.bassDrive * 5.0 + u.energyDrive * 1.8);
        detail = sin(dot(base, float3(1, 1, 0)) * 16.0 + t * 8.0) * u.midsDrive * 5.5
               + sin(dot(base, float3(1, 0, 1)) * 24.0 + t * 12.0) * u.highsDrive * 4.0;
        beat = u.beatDrive * (0.75 + 0.25 * primary) * (0.6 + 0.4 * u.beatEnvelope);
    } else if (u.mode == kModePulse) {
        float ringSpeed = 2.2 + u.bassDrive * u.bassSpeedScale * 2.8;
        float ring = sin(radial * 12.0 - t * ringSpeed);
        float falloff = max(0.0, 1.0 - radial * 1.4);
        body = ring * falloff * (u.bassDrive * 4.5 + u.energyDrive * 3.5);
        float surgePhase = radial * 10.0 - t * (6.0 + u.beatEnvelope * 10.0);
        beat = u.beatDrive * falloff * (0.85 + 0.15 * sin(surgePhase));
        detail = sin(radial * 22.0 + t * 9.0) * u.midsDrive * 3.5
               + sin(radial * 34.0 - t * 13.0) * u.highsDrive * 2.5;
    } else if (u.mode == kModeTwist) {
        float twistRate = 0.7 + u.bassDrive * 6.0;
        float twistAngle = twistRate * sin(t * 0.9 + radial * 4.5);
        float rotatedX = base.x * cos(twistAngle) - base.z * sin(twistAngle);
        body = sin(rotatedX * 9.0 + t * 1.8) * (u.bassDrive * 4.0 + u.energyDrive * 2.2);
        body += sin(t * waveSpeed * 0.5 + radial * 3.0) * u.energyDrive * 1.5;
        float falloff = max(0.0, 1.0 - radial * 1.2);
        beat = u.beatDrive * falloff * cos(radial * 8.0 - t * 4.0);
        detail = sin(radial * 20.0 + t * 14.0) * u.midsDrive * 2.8
               + sin(t * 16.0 + base.x * 18.0) * u.highsDrive * 2.0;
    } else {
        body = (primary * 0.6 + secondary * 0.4) * (u.bassDrive * 5.0 + u.energyDrive * 1.8);
        detail = sin(dot(base, float3(1, 1, 0)) * 16.0 + t * 8.0) * u.midsDrive * 5.5
               + sin(dot(base, float3(1, 0, 1)) * 24.0 + t * 12.0) * u.highsDrive * 4.0;
        beat = u.beatDrive * (0.75 + 0.25 * primary) * (0.6 + 0.4 * u.beatEnvelope);
    }

    return body + beat + detail;
}

/// Displaces vertices in-place on the GPU using base topology + audio uniforms.
kernel void deformSceneVertices(constant AudioDeformUniforms& uniforms [[buffer(0)]],
                                device const float3* basePositions [[buffer(1)]],
                                device const float3* baseNormals [[buffer(2)]],
                                device DeformableVertex* vertices [[buffer(3)]],
                                uint id [[thread_position_in_grid]]) {
    float3 base = basePositions[id];
    float3 normal = baseNormals[id];
    float disp = sceneDisplacement(base, normal, uniforms);
    vertices[id].position = base + normal * disp;
    vertices[id].normal = normal;
}
