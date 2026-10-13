# E1: physical ragdoll sanity test

Status: **CI test harness only until an actual Actions run proves PASS**.

## Source / rights

Uses the official Godot Foundation Ragdoll Physics Demo under MIT, from
`godotengine/godot-demo-projects`, pinned to commit
`b761b4cd5718a7118f2c95eb55f181d0a5f004f1` (2026-10-08).

**Important exception:** The demo's `characters/mannequiny.glb` is **GDQuest CC BY 4.0**, documented in
`3d/ragdoll_physics/characters/mannequiny.LICENSE.md`. The demo's MIT label does **not**
turn that mannequin into a CC0 or MIT character. This benchmark downloads and uses the
model only on a temporary CI runner and does **not ship it**, copy it into `game/`,
or add it to the repository. A shipping use would require its CC BY attribution obligations.

Sources:
- https://store.godotengine.org/asset/godot-foundation/ragdoll-physics-demo/
- https://github.com/godotengine/godot-demo-projects/tree/master/3d/ragdoll_physics
- https://github.com/godotengine/godot-demo-projects/blob/master/3d/ragdoll_physics/characters/mannequiny.LICENSE.md

## Test design

Workflow `.github/workflows/asset-e1-ragdoll-smoke.yml` temporarily fetches only the
upstream sample folder, installs the original Godot 4.7.2 and forces Compatibility renderer
while retaining Jolt Physics.

`verify_physics.gd` creates a procedural collision floor and runs three impulse
directions (front, side, back), five spawned mannequins per direction, for 170 physics ticks.

The runner checks that each skeleton has at least 12 physics bones and produces finite
positions/velocities. It also checks gravity-driven fall, nonzero horizontal travel, and
obvious deep floor penetration/uncontrolled velocities. A JSON report and logs are uploaded
as build artifacts. No upstream sample binaries are added to project history.

**This test is only a physics sanity check.** It does not yet prove the game's existing
`CharacterBody3D` can transition to ragdoll, that limbs never clip art geometry, that
contacts are visually funny, that the final Kim manager skinned mesh works, or that player
FPS remains 60 on Windows. Those need the production adapter and review scene.

## Production integration guard

Preserve `game/scripts/office_npc.gd` state, `receive_hit()` contract and damage event
accounting. A new physics layer/visual adapter should only replace the current downed-body
visual representation behind a disabled-by-default feature flag. Do not simultaneously
run its existing 90-degree procedural down pose and physical simulation.
