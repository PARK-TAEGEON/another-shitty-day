# Technical verification: reusable character animation and Jolt ragdoll

Date: 2026-10-13 (KST). Work performed on `research/asset-reuse-2026-10-13` in separate labs. This document does not certify integration into `game/`.

## E0 — Quaternius Universal Animation Library Standard: PASS

Evidence: https://github.com/PARK-TAEGEON/another-shitty-day/actions/runs/38348850781

- Platform: GitHub Actions ubuntu-22.04, official Godot 4.7.2, headless Compatibility renderer.
- Source: https://store.godotengine.org/asset/quaternius/universal-animation-library/ (official CC0 Standard, archive downloaded on CI runner and not committed).
- Archive asset: `Animation Library[Standard]/Godot/AnimationLibrary_Godot_Standard.glb`.
- Imported GLB scenes: **1**; detected `Skeleton3D`: **1**; detected skinned meshes: **1**.
- Animation clips found and manually advanced: **46 of 46**.
- Import failures reported by E0 script: **0**.
- Representative clip names from real import: `Idle`, `Idle_Talking`, `Hit_Chest`, `Hit_Head`, `Punch_Cross`, `Crouch_Fwd`, `Jog_Fwd`.
- Evidence artifact: `e0-godot-import-evidence`, JSON report and logs on Actions run.

Scope of claim: the library's included rig and motion are loadable/playable. No retargeting onto the proposed Blender Kim manager rig has been demonstrated. No visual/video review or gameplay quality claim has been made. The free Standard library is *not* the full paid 120+ clip catalog.

## E1 — official Godot ragdoll Jolt physics diagnostic

Source: https://github.com/godotengine/godot-demo-projects/tree/master/3d/ragdoll_physics
Pinned upstream source commit: `b761b4cd5718a7118f2c95eb55f181d0a5f004f1`.
Action: https://github.com/PARK-TAEGEON/another-shitty-day/actions/runs/38349124791

**Status: automated run in progress at time of this note.** Do not mark E1 as PASS until its diagnostic JSON proves the 3 directions × 5 repeats completed.

- Script: `studies/asset-reuse/e1-ragdoll-lab/verify_physics.gd`.
- Renderer: forced Compatibility; physics engine: Jolt; 170 physics frames per trial.
- Success criteria: 15 bodies spawned with ≥12 bone colliders, physics actually moves and falls, positions/velocities finite, no deep floor penetration, no extreme uncontrolled speed.

**License correction:** Although Godot Foundation's ragdoll sample code is labeled MIT, `characters/mannequiny.glb` inside the demo is GDQuest's **CC BY 4.0** asset per its own `characters/mannequiny.LICENSE.md`. The sample model is loaded **only in a temporary CI checkout**, is **not imported to the shipping game**, and must not be falsely labeled CC0/MIT. Using it for release would require a separate attribution/rights assessment.

## Code integration boundary

Both E0 and E1 are isolated benchmarks and do not modify `game/`, `office_npc.gd`, physics config, NPC counts, approved art or dialogue timing. Next production step is a disabled-by-default render/rig adapter for **one** character, with existing hit/damage events preserved, not a mass replacement of current NPC visuals.

Human review only after a real Kim-manager playable scene and motion video exist. See `docs/ROADMAP-AND-GATES.md`.
