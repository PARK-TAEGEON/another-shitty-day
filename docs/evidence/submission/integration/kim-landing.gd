extends "res://rig_slice/kim_submission_capture.gd"
## Sample rendered shoe vertices at the ragdoll modifier, before Godot restores
## the animation pose. Keep the production camera, physics, and floor geometry.
const FLOOR_TOP_M := -0.02

var skeleton: Skeleton3D
var binds: Array[int] = []
var bind_poses: Array[Transform3D] = []
var shoe_samples: Array[Dictionary] = []
var measurements: Array[float] = []
var first_render_frame := 0

func _capture() -> void:
	scene_changed.connect(_watch_shoes, CONNECT_ONE_SHOT)
	await super._capture()
	if measurements.is_empty():
		push_error("No rendered shoe poses measured")
		quit(1)
		return
	var lowest: float = measurements.min()
	print("INTEGRATION_KIM_LANDING ", JSON.stringify({
		"floor_top_m": FLOOR_TOP_M,
		"samples": measurements.size(),
		"shoe_vertices": shoe_samples.size(),
		"first_frame": first_render_frame,
		"lowest_frame": first_render_frame + measurements.find(lowest),
		"lowest_m": lowest,
		"peak_floor_penetration_m": maxf(0.0, FLOOR_TOP_M - lowest),
		"last_floor_penetration_m": maxf(0.0, FLOOR_TOP_M - measurements[-1]),
	}))

func _watch_shoes() -> void:
	var adapter: Node3D = current_scene.world.opening_boss._rig_adapter
	if not is_instance_valid(adapter) or not adapter.visual_v2:
		return
	skeleton = adapter.skeleton
	var mesh_node := adapter.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := mesh_node.skin
	for i in skin.get_bind_count():
		binds.append(skeleton.find_bone(skin.get_bind_name(i)))
		bind_poses.append(skin.get_bind_pose(i))
	for surface in mesh_node.mesh.get_surface_count():
		if mesh_node.mesh.surface_get_material(surface).resource_name != "Leather and eyes":
			continue
		var data := mesh_node.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
		var joints: PackedInt32Array = data[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = data[Mesh.ARRAY_WEIGHTS]
		var stride := joints.size() / vertices.size()
		for i in vertices.size():
			if vertices[i].y > 0.18:
				continue
			shoe_samples.append({"point": vertices[i], "binds": joints.slice(i * stride, (i + 1) * stride),
				"weights": weights.slice(i * stride, (i + 1) * stride)})
	adapter.simulator.modification_processed.connect(_sample_shoes)

func _sample_shoes() -> void:
	if not is_instance_valid(rig) or not rig.ragdoll_active or not rig.bodies[0].is_simulating_physics():
		return
	if measurements.is_empty():
		first_render_frame = Engine.get_process_frames()
	var transforms: Array[Transform3D] = []
	for i in binds.size():
		transforms.append(skeleton.global_transform * skeleton.get_bone_global_pose(binds[i]) * bind_poses[i])
	var lowest := INF
	for sample: Dictionary in shoe_samples:
		var posed := Vector3.ZERO
		for i in sample.binds.size():
			if sample.weights[i] > 0.0:
				posed += (transforms[sample.binds[i]] * sample.point) * sample.weights[i]
		lowest = minf(lowest, posed.y)
	measurements.append(lowest)
