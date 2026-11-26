extends "flight-capture.gd"
## Contact diagnosis (headless, --fixed-fps 30), writes <log>-trace.json next to
## the flight-capture log. Every physics step from 3 steps before the hand-off
## until the end. Coordinates are world space (Y up, floor top from the floor
## box shape). Contacts come from PhysicsDirectBodyState3D of the foot body.
## Per foot: lowest point of every foot collision shape (collider_pen_cm) and of
## the box alone (box_pen_cm), lowest shoe point (shoe hull carried by the
## physics foot bone), the floor top under the foot (from the floor box shape),
## ankle gap, and each contact: other object path and its shape index, the foot
## shape index (0 = box, 1-12 = edge capsules after the fix), the world normal
## pointing from the other object towards the foot (Jolt convention in Godot
## 4.7: jolt_contact_listener_3d.cpp), and the world contact point on the foot.
var trace: Array = []
var _t_hull: Dictionary = {}
var _t_floor_body: StaticBody3D = null
var _t_floor_top := 0.0
var _armed := false
var _step := 0

func _initialize() -> void:
	physics_frame.connect(_trace_step)
	super._initialize()

func _t_prepare() -> void:
	var sk: Skeleton3D = rig.skeleton
	var mesh_node := rig.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := mesh_node.skin
	for side: String in ["L", "R"]:
		var foot := sk.find_bone("Foot." + side)
		var rest_inv := sk.get_bone_global_rest(foot).affine_inverse()
		var points := PackedVector3Array()
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
				var best := 0
				for k in stride:
					if weights[i * stride + k] > weights[i * stride + best]:
						best = k
				if sk.find_bone(skin.get_bind_name(joints[i * stride + best])) == foot:
					points.append(rest_inv * vertices[i])
		var hull := ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points
		hull.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
		_t_hull[side] = (hull.create_convex_shape(true, false) as ConvexPolygonShape3D).points
	# The floor: the static box under Kim's start whose top face is the walkable floor.
	var space: PhysicsDirectSpaceState3D = rig.get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	for body: PhysicalBone3D in rig.bodies:
		exclude.append(body.get_rid())
	# Beside the start (the ledge platform sits under Kim there).
	var probe: Vector3 = (kim as Node3D).global_position + Vector3(1.0, 0, 0)
	var query := PhysicsRayQueryParameters3D.create(Vector3(probe.x, 3.0, probe.z), Vector3(probe.x, -3.0, probe.z), 1)
	query.exclude = exclude
	var hit: Dictionary = space.intersect_ray(query)
	_t_floor_body = hit.collider
	for child in _t_floor_body.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			var xf: Transform3D = _t_floor_body.global_transform * (child as CollisionShape3D).transform
			_t_floor_top = (xf * Vector3(0, ((child as CollisionShape3D).shape as BoxShape3D).size.y * 0.5, 0)).y
	print("TRACE_FLOOR ", _t_floor_body.get_path(), " top ", _t_floor_top, " hull points ", _t_hull["L"].size(), "/", _t_hull["R"].size())

func _trace_step() -> void:
	if not is_instance_valid(rig) or rig.bodies.is_empty() or not rig.ragdoll_active:
		return
	if _t_hull.is_empty():
		_t_prepare()
	_step += 1
	if rig._flight_active and rig._flight_elapsed >= rig._flight_duration - 3.0 / Engine.physics_ticks_per_second:
		_armed = true
	if not rig._flight_active and rig._flight_elapsed > 0.0:
		_armed = true
	if not _armed:
		return
	var row := {"step": _step, "frame": Engine.get_process_frames(), "flight": rig._flight_active}
	for side: String in ["L", "R"]:
		var body: PhysicalBone3D = _body("Foot." + side)
		var shape := body.get_child(0) as CollisionShape3D
		var box: Transform3D = body.global_transform * shape.transform
		var half: Vector3 = (shape.shape as BoxShape3D).size * 0.5
		var low := INF
		for x: float in [-1.0, 1.0]:
			for y: float in [-1.0, 1.0]:
				for z: float in [-1.0, 1.0]:
					low = minf(low, (box * Vector3(half.x * x, half.y * y, half.z * z)).y)
		var bone: Transform3D = body.global_transform * body.body_offset.affine_inverse()
		var shoe := INF
		for p: Vector3 in _t_hull[side]:
			shoe = minf(shoe, (bone * p).y)
		var shin: PhysicalBone3D = _body("LowerLeg." + side)
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		var contacts := []
		for i in state.get_contact_count():
			var other: Object = state.get_contact_collider_object(i)
			contacts.append({"other": str((other as Node).get_path()) if other is Node else str(other),
				"other_shape": state.get_contact_collider_shape(i),
				"foot_shape": state.get_contact_local_shape(i),
				"normal_world_towards_foot": state.get_contact_local_normal(i).snappedf(0.001),
				"point_on_foot_world": state.get_contact_local_position(i).snappedf(0.001),
				"impulse": state.get_contact_impulse(i).snappedf(0.001)})
		row[side] = {"collider_pen_cm": snappedf((_t_floor_top - collider_low(body)) * 100.0, 0.01),
			"box_pen_cm": snappedf((_t_floor_top - low) * 100.0, 0.01),
			"shoe_pen_cm": snappedf((_t_floor_top - shoe) * 100.0, 0.01),
			"center": body.global_position.snappedf(0.001),
			"xform": [body.global_transform.basis.x, body.global_transform.basis.y, body.global_transform.basis.z, body.global_transform.origin].map(func(v: Vector3) -> Array: return [v.x, v.y, v.z]),
			"shape_xform": [shape.transform.basis.x, shape.transform.basis.y, shape.transform.basis.z, shape.transform.origin].map(func(v: Vector3) -> Array: return [v.x, v.y, v.z]), "long_axis_y": snappedf(absf(box.basis.z.normalized().y), 0.01),
			"ankle_gap_mm": snappedf((body.global_transform * body.joint_offset.origin).distance_to(shin.global_transform * (_anchor_local["Foot." + side] as Vector3)) * 1000.0, 0.1) if _anchor_local.has("Foot." + side) else null,
			"speed": snappedf(body.linear_velocity.length(), 0.001), "contacts": contacts,
			"lin_vel": [body.linear_velocity.x, body.linear_velocity.y, body.linear_velocity.z],
			"ang_vel": [body.angular_velocity.x, body.angular_velocity.y, body.angular_velocity.z]}
	trace.append(row)

func _write_log() -> void:
	super._write_log()
	var out := FileAccess.open(log_path.replace(".json", "-trace.json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"floor": str(_t_floor_body.get_path()) if _t_floor_body else "", "floor_top": _t_floor_top, "steps": trace}))
	out.close()
