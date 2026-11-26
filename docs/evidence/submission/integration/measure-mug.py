"""Measure the sampled Godot hand against the runtime mug GLB in Blender."""
from pathlib import Path

import bpy


root = Path(__file__).resolve().parents[4]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root / "game/assets/submission/office/mug.glb"))
probe = root / "docs/evidence/submission/office/grip_mesh_check.py"
exec(compile(probe.read_bytes(), str(probe), "exec"))
