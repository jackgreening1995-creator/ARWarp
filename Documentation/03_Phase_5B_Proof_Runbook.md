# Phase 5B — LiDAR Proof Runbook

Manual proof workflow for closing the ARWarp demo-lock milestone on the connected iPhone 12 Pro Max. After the Phase 6A framework split, this same runbook is also the hardware regression gate for `ARWarpKit`.

## Current Blocker

As of **May 24, 2026**, this Mac can see the connected device destination (`jackalexander`, iPhone 12 Pro Max), but signed deployment is blocked before install:

- `No Account for Team (signing identity)`
- `No profiles for 'com.jackgreening.arwarp' were found`

Do not mark Phase 5 complete until that signing state is repaired and the capture bundle below is collected on-device.

## Prerequisites

- Xcode signed into a valid Apple developer account for a valid development team, or an equivalent valid development profile for `com.jackgreening.arwarp`
- Connected LiDAR phone: **iPhone 12 Pro Max**
- `ARWarp` scheme selected in Xcode
- Fresh install on the device
- Camera + Microphone permissions granted
- Music source ready near the device speaker

## Capture Order

1. Launch `ARWarp` on the iPhone 12 Pro Max.
2. Record a **scan baseline** pass while the room mesh fills in and the deck remains visible.
3. Keep warp on and capture a **Flow** pass in the same room.
4. Switch to **Fracture** and capture a second pass in the same room.
5. Collapse the deck and capture an unobstructed **camera-first** view while warp remains live.
6. Write a short performance note using the in-app chunk count and GPU ms HUD during the same session.

## Artifact Names

Use one folder per proof run:

`phase5b-proof-YYYY-MM-DD/`

Expected artifacts:

- `01-scan-baseline.mp4`
- `02-flow.mp4`
- `03-fracture.mp4`
- `04-collapsed-deck.mp4`
- `05-performance-note.md`

## Acceptance Checklist

- App installs and launches on the iPhone 12 Pro Max without a blank screen.
- First-launch permission flow completes successfully.
- Scene reconstruction reaches visible wall/floor chunks in a normal room.
- `Flow` and `Fracture` read as clearly different within the first minute.
- Toggling warp off returns the room toward rest without stuck deformation.
- Toggling warp back on resumes response correctly.
- Ongoing scanning does not show harsh chunk flash/pop during anchor churn.
- A longer live session does not crash or degrade severely.
- GPU ms and visual review support a 60 fps class demo in a typical 3×3 m room.

## If Something Fails

- If install fails: fix Xcode account / provisioning first; do not widen scope into new product features.
- If launch succeeds but AR is unstable: capture the failure mode and tune only existing constants (`maxActiveChunksPerFrame`, deformation radius, preset mapping, fade timings, readiness thresholds).
- If the effect looks the same across presets: tune preset mappings and materials, then repeat only the affected captures.
