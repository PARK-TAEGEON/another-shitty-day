extends SceneTree
## 50-bone scripted flight pose: limbs move relative to the torso early in the
## arc, joints stay connected while scripted, and the physics hand-off keeps the
## last displayed pose (normal end over a ledge and an early crash into a wall).
## Landing: every shoe vertex sits inside its foot collider, and after the
## ledge and wall landings the rendered sole never hangs below the foot box.
## The legacy 31-bone rig (--kim-rig) keeps its previous path: no fold state.
const NPC = preload("res://scripts/office_npc.gd")
const GROUPS := {"torso": ["Chest"], "arms": ["UpperArm.L", "UpperArm.R"], "legs": ["UpperLeg.L", "UpperLeg.R"]}
# Shoe vertices may sit this far outside the foot box (rest pose, metres).
const SHOE_IN_BOX_M := 0.001
# In the landed pose the cached sole may hang this far below the box bottom.
const SOLE_BELOW_BOX_M := 0.005
var failures: Array[String] = []
var _shoe_checked := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("KIM_FLIGHT_POSE_CHECK: " + message)

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	_solid(stage, Vector3(0, -0.15, 0), Vector3(80, 0.3, 80))
	if "--kim-rig" in OS.get_cmdline_user_args():
		await _case(stage, "legacy", false)
	else:
		await _case(stage, "ledge", true)
		await _case(stage, "wall", true)
	stage.queue_free()
	await process_frame
	if failures.is_empty():
		print("KIM_FLIGHT_POSE_REGRESSION_OK")
	else:
		print("KIM_FLIGHT_POSE_REGRESSION_FAILED: ", failures)
	quit(0 if failures.is_empty() else 1)

func _solid(stage: Node, at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	stage.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body

func _body(rig: Node, name: String) -> PhysicalBone3D:
	for body: PhysicalBone3D in rig.bodies:
		if body.bone_name == name:
			return body
	return null

func _parent(rig: Node, body: PhysicalBone3D) -> PhysicalBone3D:
	var sk: Skeleton3D = rig.skeleton
	var bone := sk.get_bone_parent(sk.find_bone(body.bone_name))
	while bone >= 0:
		var found := _body(rig, sk.get_bone_name(bone))
		if found != null:
			return found
		bone = sk.get_bone_parent(bone)
	return null

func _rel(rig: Node, body: PhysicalBone3D) -> Basis:
	return _parent(rig, body).global_basis.orthonormalized().inverse() * body.global_basis.orthonormalized()

func _angle(a: Basis, b: Basis) -> float:
	return rad_to_deg((a.inverse() * b).get_rotation_quaternion().normalized().get_angle())

func _anchor_gap(rig: Node, body: PhysicalBone3D, local: Vector3) -> float:
	return (body.global_transform * body.joint_offset.origin).distance_to(_parent(rig, body).global_transform * local)

func _case(stage: Node, label: String, v2: bool) -> void:
	var extra: Array[Node] = []
	var start := Vector3(0, 0.02, 0)
	if label == "ledge":
		extra.append(_solid(stage, Vector3(0, 0.5, 0), Vector3(1.2, 1.0, 1.2)))
		start.y = 1.02
	elif label == "wall":
		extra.append(_solid(stage, Vector3(2.0, 1.5, 0), Vector3(0.2, 3.0, 3.0)))
	var actor = NPC.new()
	actor.role = "boss"
	actor.display_name = "김 팀장"
	actor.use_kim_rig = true
	actor.position = start
	stage.add_child(actor)
	await physics_frame
	await physics_frame
	var rig: Node = actor._rig_adapter
	check(rig != null and rig.visual_v2 == v2, label + " loaded the wrong Kim rig")
	if rig == null:
		return
	if v2 and not _shoe_checked:
		_shoe_checked = true
		_check_shoe_inside_foot_box(rig)
	actor.receive_hit(Vector3(13, 2, 0), actor.global_position + Vector3.UP, 28.0, "kick")
	var flight_start_rel: Dictionary = {}
	var anchors: Dictionary = {}
	var flight_time := 0.0
	var early_ok := false
	var max_gap_change := 0.0
	var was_flight := false
	var handoff_rel: Dictionary = {}
	var after := -1
	var handoff_step := 0.0
	var ended := ""
	for _i in range(150):
		await physics_frame
		var flying: bool = rig._flight_active
		if flying and not was_flight:
			for body: PhysicalBone3D in rig.bodies:
				if body.bone_name == "Pelvis":
					continue
				flight_start_rel[body.bone_name] = _rel(rig, body)
				anchors[body.bone_name] = _parent(rig, body).global_transform.affine_inverse() * (body.global_transform * body.joint_offset.origin)
		if flying:
			flight_time += 1.0 / Engine.physics_ticks_per_second
			var moved := 0
			for group: String in GROUPS:
				var turn := 0.0
				for name: String in GROUPS[group]:
					turn = maxf(turn, _angle(flight_start_rel[name], _rel(rig, _body(rig, name))))
				if turn >= 5.0:
					moved += 1
			if flight_time <= 0.1 + 0.0001 and moved >= 2:
				early_ok = true
			for body: PhysicalBone3D in rig.bodies:
				if anchors.has(body.bone_name):
					max_gap_change = maxf(max_gap_change, _anchor_gap(rig, body, anchors[body.bone_name]))
		if was_flight and not flying:
			ended = "normal" if rig._flight_elapsed >= rig._flight_duration - 0.0001 else "crash"
			after = 0
			for body: PhysicalBone3D in rig.bodies:
				if body.bone_name != "Pelvis":
					handoff_rel[body.bone_name] = _rel(rig, body)
		elif after >= 0 and after < 3:
			after += 1
			for body: PhysicalBone3D in rig.bodies:
				if handoff_rel.has(body.bone_name):
					handoff_step = maxf(handoff_step, _angle(handoff_rel[body.bone_name], _rel(rig, body)))
		was_flight = flying
	# Landing: keep simulating until every body has been slow for 0.5 s.
	var sole_below_box := 0.0
	var sole_floor_peak := 0.0
	var still := 0
	var settle_steps := 0
	while v2 and ended != "" and settle_steps < 480 and still < 30:
		await physics_frame
		settle_steps += 1
		var fastest := 0.0
		for body: PhysicalBone3D in rig.bodies:
			fastest = maxf(fastest, body.linear_velocity.length())
		still = still + 1 if fastest < 0.05 else 0
		for side: String in ["L", "R"]:
			var foot: Dictionary = _foot_low(rig, side)
			sole_below_box = maxf(sole_below_box, float(foot.box) - float(foot.sole))
			sole_floor_peak = maxf(sole_floor_peak, -float(foot.sole))
	var sole_floor_rest := 0.0
	if v2 and ended != "":
		for side: String in ["L", "R"]:
			sole_floor_rest = maxf(sole_floor_rest, -float(_foot_low(rig, side).sole))
	check(not anchors.is_empty(), label + " never entered the scripted flight")
	if v2:
		check(flight_time > 0.1, label + ": the arc ended before 0.1 s, so the early pose was not tested")
		check(early_ok, label + ": fewer than two of torso/arms/legs turned 5 degrees within 0.1 s of flight")
		# Anchors are taken at flight start. The pose turns each joint about its own
		# pivot, so no scripted joint may open or segment stretch.
		check(max_gap_change < 0.002, label + ": a joint opened %.4f m during flight" % max_gap_change)
		check(handoff_step < 6.0, label + ": pose jumped %.1f degrees in the first hand-off steps" % handoff_step)
		check(still >= 30, label + ": Kim did not come to rest within 8 s of the hand-off")
		check(sole_below_box <= SOLE_BELOW_BOX_M, label + ": the sole hung %.3f m below the foot box after landing" % sole_below_box)
	else:
		check(rig._flight_start_xf.is_empty() and rig._flight_fold.is_empty(), label + ": the 31-bone rig used the 50-bone flight pose")
	if label == "ledge":
		check(ended == "normal", "ledge flight did not end at u = 1 (%s)" % ended)
	elif label == "wall":
		check(ended == "crash", "wall flight did not crash (%s)" % ended)
		for body: PhysicalBone3D in rig.bodies:
			check(body.global_position.x < 1.9, "wall crossed by %s at %s" % [body.name, str(body.global_position)])
	print("KIM_FLIGHT_POSE ", JSON.stringify({"case": label, "v2": v2, "end": ended, "early_two_groups": early_ok,
		"max_joint_opening_m": snappedf(max_gap_change, 0.00001),
		"handoff_step_deg": snappedf(handoff_step, 0.01), "flight_s": snappedf(flight_time, 0.001),
		"at_rest": still >= 30, "settle_s": snappedf(settle_steps / float(Engine.physics_ticks_per_second), 0.01),
		"sole_below_box_max_m": snappedf(sole_below_box, 0.0001),
		"sole_floor_penetration_peak_m": snappedf(sole_floor_peak, 0.0001),
		"sole_floor_penetration_rest_m": snappedf(sole_floor_rest, 0.0001)}))
	actor.queue_free()
	for node: Node in extra:
		node.queue_free()
	for _i in range(3):
		await physics_frame

## Lowest cached sole point (heel/toe, both edges) and lowest foot-box corner,
## both from the physics body. The stage floor top is y = 0.
func _foot_low(rig: Node, side: String) -> Dictionary:
	var body: PhysicalBone3D = _body(rig, "Foot." + side)
	var shape := body.get_child(0) as CollisionShape3D
	var box: Transform3D = body.global_transform * shape.transform
	var half: Vector3 = (shape.shape as BoxShape3D).size * 0.5
	var box_low := INF
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				box_low = minf(box_low, (box * Vector3(half.x * x, half.y * y, half.z * z)).y)
	var bone: Transform3D = body.global_transform * body.body_offset.affine_inverse()
	var sole_low := INF
	for point: Vector3 in rig._sole_points[rig.skeleton.find_bone("Foot." + side)]:
		sole_low = minf(sole_low, (bone * point).y)
	return {"box": box_low, "sole": sole_low}

## Rest pose: every shoe vertex (shoe material, skinned mostly to the foot)
## must lie inside that foot's physics box.
func _check_shoe_inside_foot_box(rig: Node) -> void:
	var sk: Skeleton3D = rig.skeleton
	var mesh_node := rig.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := mesh_node.skin
	var bind_bone: Array[int] = []
	for i in skin.get_bind_count():
		bind_bone.append(sk.find_bone(skin.get_bind_name(i)))
	var report := {}
	for side: String in ["L", "R"]:
		var foot := sk.find_bone("Foot." + side)
		var body: PhysicalBone3D = _body(rig, "Foot." + side)
		var shape := body.get_child(0) as CollisionShape3D
		var to_box: Transform3D = (sk.get_bone_global_rest(foot) * body.body_offset * shape.transform).affine_inverse()
		var half: Vector3 = (shape.shape as BoxShape3D).size * 0.5
		var count := 0
		var worst := 0.0
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
				if bind_bone[joints[i * stride + best]] != foot:
					continue
				count += 1
				var q: Vector3 = to_box * vertices[i]
				worst = maxf(worst, Vector3(maxf(absf(q.x) - half.x, 0.0), maxf(absf(q.y) - half.y, 0.0), maxf(absf(q.z) - half.z, 0.0)).length())
		check(count > 100, "found only %d shoe vertices on Foot.%s" % [count, side])
		check(worst <= SHOE_IN_BOX_M, "Foot.%s shoe reaches %.4f m outside its physics box" % [side, worst])
		report[side] = {"vertices": count, "outside_m": snappedf(worst, 0.0001)}
	print("KIM_FLIGHT_POSE_SHOE ", JSON.stringify(report))
