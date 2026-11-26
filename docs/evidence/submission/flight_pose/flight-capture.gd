extends "../integration/kim-landing.gd"
## kim-landing.gd plus a per-frame flight log. Run with --fixed-fps 30.
##   -- --log=/path/out.json                     production office replay (default)
##   -- --log=... --fixture=front|side|wall|open|ledge fixed placement, one kick
##   -- ... --side-view                           review camera beside the arc
##   -- ... --review-cam=room|wall                fixed low camera beside the landing area, HUD hidden
##   -- ... --after-frames=N                      frames recorded after the kick (default 200)
##   -- ... --kim-offset=X                        shift Kim and the player X m sideways
##                                                (landing spread; default 0)
## The log records the kick contact, ragdoll start, scripted flight start/end
## (normal or crash), the physics hand-off, flight progress u, game time and
## per-joint measurements of the 15 physical bones.
const JOINT_NAMES := ["Chest", "Head", "UpperArm.L", "Forearm.L", "Hand.L", "UpperArm.R",
	"Forearm.R", "Hand.R", "UpperLeg.L", "LowerLeg.L", "Foot.L", "UpperLeg.R", "LowerLeg.R", "Foot.R"]

var log_path := ""
var fixture := ""
var rows: Array = []
var events: Array = []
var game_time := 0.0
var frame_index := 0
var _parents: Dictionary = {}
var _anchor_local: Dictionary = {}
var _flight_rel: Dictionary = {}
var _prev_rel: Dictionary = {}
var _was_ragdoll := false
var _was_flight := false
var _after_flight := -1
var _kick_seen := false

# Per physics step, from flight start until the end: per foot, collider and shoe
# floor penetration against the floor collider's top face, floor contacts whose
# normal points down (from the floor towards the foot), and the ankle gap.
var steps: Array = []
var _step_index := 0
var _shoe_hull: Dictionary = {}
var _floor_top := NAN
var _floor_path := ""

func _initialize() -> void:
	physics_frame.connect(_log_step)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--log="):
			log_path = arg.substr(6)
		elif arg.begins_with("--fixture="):
			fixture = arg.substr(10)
	process_frame.connect(_log_frame)
	super._initialize()

func _capture() -> void:
	if fixture == "":
		await super._capture()
	else:
		await _fixture_capture()
	_write_log()

func _fixture_capture() -> void:
	change_scene_to_packed(MAIN)
	await scene_changed
	var game = current_scene
	kim = game.world.opening_boss
	player = game.player
	rig = kim._rig_adapter
	_watch_shoes()
	game._automated_run = true
	game._resume()
	kim._cancel_opening()
	kim.set_physics_process(false)
	player.contact_started.connect(_on_contact)
	# Same open aisle as kim-landing-fixture.gd. Kim faces +Z (towards the player).
	var kim_at := Vector3(0, 0.02, 4)
	var player_at := Vector3(0, 0.02, 5.15)
	var player_yaw := 0.0
	var flight_dir := Vector3(0, 0, -1)
	if fixture == "open" or fixture == "ledge":
		# A 5.4 m clear lane (probed at 0.2/0.8/1.6 m): the arc ends at u = 1.
		kim_at = Vector3(-5.5, 0.02, -2.5)
		player_at = Vector3(-5.5, 0.02, -3.65)
		player_yaw = PI
		flight_dir = Vector3(0, 0, 1)
		kim.rotation.y = PI
	if fixture == "ledge":
		# Test platform 1 m high: the arc never meets the floor, so it ends at u = 1.
		_test_box(game, Vector3(-5.5, 0.5, -2.5), Vector3(1.2, 1.0, 1.2))
		kim_at.y = 1.02
	if fixture == "side":
		# Kim turned 90 degrees: the kick lands on his left side.
		kim.rotation.y = -PI * 0.5
	elif fixture == "wall":
		# A test wall 1.1 m behind Kim makes the arc crash while he is folded.
		_test_box(game, Vector3(0, 1.5, 2.9), Vector3(3.0, 3.0, 0.2))
	var offset := 0.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--kim-offset="):
			offset = float(arg.substr(13))
	var sideways := Vector3(-flight_dir.z, 0, flight_dir.x) * offset
	kim_at += sideways
	player_at += sideways
	kim.global_position = kim_at
	player.place_at(player_at, player_yaw, -0.25)
	for i in 20:
		await process_frame
	_look_towards(kim.global_position + Vector3.UP * 1.25, 1.0)
	await process_frame
	player.perform_action("kick")
	# Review-only side camera, 5 m to the side of the arc; the game camera is untouched.
	var side_cam: Camera3D = null
	if OS.get_cmdline_user_args().has("--side-view"):
		side_cam = Camera3D.new()
		side_cam.fov = 58.0
		game.world.add_child(side_cam)
		var middle: Vector3 = kim_at + flight_dir * 1.8
		var beside := Vector3(-flight_dir.z, 0, flight_dir.x)
		if (middle + beside).length() > (middle - beside).length():
			beside = -beside # stay on the room side of the arc
		side_cam.global_position = middle + beside * 4.5 + Vector3.UP * 2.1
		side_cam.look_at(middle + Vector3.UP * 0.8)
		side_cam.make_current()
	# Review-only landing cameras, fixed for the whole run, 0.4 m above the floor
	# and 2.3 m beside the landing area: --review-cam=room (room side of the lane)
	# or --review-cam=wall (wall side). Together they show both feet, the floor
	# and the low cabinet beside the lane from the hand-off to rest. The HUD is
	# hidden in these evidence captures only.
	var review := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--review-cam="):
			review = arg.substr(13)
	if review == "room" or review == "wall":
		var cam := Camera3D.new()
		cam.fov = 60.0
		game.world.add_child(cam)
		var aim: Vector3 = Vector3(kim_at.x, 0.0, kim_at.z) + flight_dir * 5.2
		var beside := Vector3(-flight_dir.z, 0, flight_dir.x)
		if (aim + beside).length() > (aim - beside).length():
			beside = -beside # the room side of the lane
		if review == "wall":
			beside = -beside
		cam.global_position = aim + beside * 2.3 + Vector3.UP * 0.4
		cam.look_at(aim + Vector3.UP * 0.25)
		cam.make_current()
		for node: Node in game.find_children("*", "CanvasLayer", true, false):
			(node as CanvasLayer).visible = false
		if game.get("_hud") is CanvasItem:
			(game._hud as CanvasItem).visible = false
	var after_frames := 200
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--after-frames="):
			after_frames = int(arg.substr(15))
	for i in after_frames:
		_look_towards(rig.pelvis_position() + Vector3.UP * 0.3, 0.12)
		await process_frame
	print("FLIGHT_FIXTURE ", JSON.stringify({"fixture": fixture, "samples": measurements.size(),
		"peak_m": maxf(0.0, FLOOR_TOP_M - measurements.min()) if not measurements.is_empty() else -1.0,
		"last_m": maxf(0.0, FLOOR_TOP_M - measurements[-1]) if not measurements.is_empty() else -1.0,
		"pelvis": rig.pelvis_position()}))
	game.sound.stop_all()
	quit(0)

func _test_box(game: Node, at: Vector3, size: Vector3) -> void:
	var solid := StaticBody3D.new()
	solid.collision_layer = 1
	solid.collision_mask = 0
	solid.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	solid.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.82, 0.74)
	mesh.material_override = mat
	solid.add_child(mesh)
	game.world.add_child(solid)

func _on_contact(kind: String, target: Node3D) -> void:
	if kind == "kick" and target == kim:
		_event("kick_contact")

func _event(name: String, extra: Dictionary = {}) -> void:
	var row := {"event": name, "frame": frame_index, "movie_s": snappedf(frame_index / 30.0, 0.001),
		"game_s": snappedf(game_time, 0.0001)}
	row.merge(extra)
	events.append(row)
	print("FLIGHT_EVENT ", JSON.stringify(row))

func _body(name: String) -> PhysicalBone3D:
	for body: PhysicalBone3D in rig.bodies:
		if body.bone_name == name:
			return body
	return null

func _parent_body(body: PhysicalBone3D) -> PhysicalBone3D:
	var sk: Skeleton3D = rig.skeleton
	var bone := sk.get_bone_parent(sk.find_bone(body.bone_name))
	while bone >= 0:
		var found := _body(sk.get_bone_name(bone))
		if found != null:
			return found
		bone = sk.get_bone_parent(bone)
	return null

func _rel(name: String) -> Basis:
	var child := _body(name)
	var parent: PhysicalBone3D = _parents[name]
	return (parent.global_basis.orthonormalized().inverse() * child.global_basis.orthonormalized()).orthonormalized()

func _angle(a: Basis, b: Basis) -> float:
	return rad_to_deg((a.inverse() * b).get_rotation_quaternion().normalized().get_angle())

func _log_frame() -> void:
	# Rendered runs: the movie frame. Headless draws nothing, so count process frames.
	frame_index = Engine.get_frames_drawn() if DisplayServer.get_name() != "headless" else Engine.get_process_frames()
	if not is_instance_valid(rig) or rig.bodies.is_empty():
		return
	if not _kick_seen and is_instance_valid(player) and fixture == "":
		_kick_seen = true
		player.contact_started.connect(_on_contact)
	game_time += root.get_process_delta_time()
	var ragdoll: bool = rig.ragdoll_active and not rig._starting
	if ragdoll and not _was_ragdoll:
		for name: String in JOINT_NAMES:
			var child := _body(name)
			var parent := _parent_body(child)
			_parents[name] = parent
			var anchor: Vector3 = child.global_transform * child.joint_offset.origin
			_anchor_local[name] = parent.global_transform.affine_inverse() * anchor
			_prev_rel[name] = _rel(name)
		_event("ragdoll_start")
	_was_ragdoll = ragdoll
	if not ragdoll:
		return
	var flight: bool = rig._flight_active
	var u: float = clampf(rig._flight_elapsed / maxf(rig._flight_duration, 0.001), 0.0, 1.0)
	if flight and not _was_flight:
		for name: String in JOINT_NAMES:
			_flight_rel[name] = _rel(name)
		_event("flight_start", {"u": snappedf(u, 0.0001)})
	if _was_flight and not flight:
		var normal: bool = rig._flight_elapsed >= rig._flight_duration - 0.0001
		_event("flight_end_normal" if normal else "flight_end_crash",
			{"u": snappedf(u, 0.0001), "flight_elapsed": snappedf(rig._flight_elapsed, 0.0001)})
		_after_flight = 0
	_was_flight = flight
	var gaps := {}
	var max_gap := 0.0
	var turn := {}
	var max_step := 0.0
	for name: String in JOINT_NAMES:
		var child := _body(name)
		var parent: PhysicalBone3D = _parents[name]
		var gap: float = (child.global_transform * child.joint_offset.origin).distance_to(parent.global_transform * (_anchor_local[name] as Vector3))
		gaps[name] = snappedf(gap * 1000.0, 0.01)
		max_gap = maxf(max_gap, gap)
		var rel := _rel(name)
		if _flight_rel.has(name):
			turn[name] = snappedf(_angle(_flight_rel[name], rel), 0.01)
		max_step = maxf(max_step, _angle(_prev_rel[name], rel))
		_prev_rel[name] = rel
	var positions := {}
	var overlaps: Array[String] = []
	var space: PhysicsDirectSpaceState3D = rig.get_world_3d().direct_space_state
	var exclude: Array[RID] = [kim.get_rid(), player.get_rid()]
	for body: PhysicalBone3D in rig.bodies:
		exclude.append(body.get_rid())
	for body: PhysicalBone3D in rig.bodies:
		positions[body.bone_name] = body.global_position.snappedf(0.001)
		for child: Node in body.get_children():
			if not child is CollisionShape3D:
				continue
			var params := PhysicsShapeQueryParameters3D.new()
			params.shape = (child as CollisionShape3D).shape
			params.transform = body.global_transform * (child as CollisionShape3D).transform
			params.collision_mask = 3
			params.exclude = exclude
			var info: Dictionary = space.get_rest_info(params)
			# A floor contact is expected. A wall or furniture face is a burial.
			if not info.is_empty() and (info.normal as Vector3).y < 0.72 and not overlaps.has(body.bone_name):
				overlaps.append(body.bone_name)
	var scripted_count := 0
	var fastest := 0.0
	var asleep := 0
	for body: PhysicalBone3D in rig.bodies:
		if bool(body.get("scripted")):
			scripted_count += 1
		fastest = maxf(fastest, body.linear_velocity.length())
		if PhysicsServer3D.body_get_state(body.get_rid(), PhysicsServer3D.BODY_STATE_SLEEPING):
			asleep += 1
	rows.append({"frame": frame_index, "movie_s": snappedf(frame_index / 30.0, 0.001),
		"game_s": snappedf(game_time, 0.0001), "flight": flight, "u": snappedf(u, 0.0001),
		"scripted_bodies": scripted_count, "pelvis": rig.pelvis_position(),
		"max_joint_gap_mm": snappedf(max_gap * 1000.0, 0.01), "joint_gap_mm": gaps,
		"turn_since_flight_start_deg": turn, "max_joint_step_deg": snappedf(max_step, 0.01),
		"bodies": positions, "wall_or_furniture_overlap": overlaps,
		"shoe_lowest_m": snappedf(measurements[-1], 0.0001) if not measurements.is_empty() else null,
		"fastest_body_m_s": snappedf(fastest, 0.001), "sleeping_bodies": asleep})
	if _after_flight >= 0:
		_after_flight += 1

## Shoe vertices skinned mostly to each foot, as a convex hull in the foot bone frame.
func _prepare_feet() -> void:
	var sk: Skeleton3D = rig.skeleton
	var mesh_node := rig.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := mesh_node.skin
	for side: String in ["L", "R"]:
		var foot := sk.find_bone("Foot." + side)
		var rest_inv := sk.get_bone_global_rest(foot).affine_inverse()
		var points := PackedVector3Array()
		for surface in mesh_node.mesh.get_surface_count():
			var material := mesh_node.mesh.surface_get_material(surface)
			if material == null or material.resource_name != "Leather and eyes":
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
		if points.is_empty():
			continue
		var cloud := ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points
		cloud.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
		_shoe_hull[side] = (cloud.create_convex_shape(true, false) as ConvexPolygonShape3D).points
	# The floor: what a ray finds 1 m beside Kim's start (the ledge box sits under him).
	var space: PhysicsDirectSpaceState3D = rig.get_world_3d().direct_space_state
	var at: Vector3 = (kim as Node3D).global_position + Vector3(1.0, 0, 0)
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, 3.0, at.z), Vector3(at.x, -3.0, at.z), 1)
	var exclude: Array[RID] = []
	for body: PhysicalBone3D in rig.bodies:
		exclude.append(body.get_rid())
	query.exclude = exclude
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return
	var floor_body := hit.collider as CollisionObject3D
	_floor_path = str(floor_body.get_path())
	for child: Node in floor_body.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			var box: Transform3D = floor_body.global_transform * (child as CollisionShape3D).transform
			_floor_top = (box * Vector3(0, ((child as CollisionShape3D).shape as BoxShape3D).size.y * 0.5, 0)).y

## Lowest world height of a body's collision shapes (box, capsule, sphere, convex).
static func collider_low(body: CollisionObject3D) -> float:
	var low := INF
	for child: Node in body.get_children():
		if not child is CollisionShape3D:
			continue
		var cs := child as CollisionShape3D
		var xf: Transform3D = body.global_transform * cs.transform
		var shape := cs.shape
		if shape is BoxShape3D:
			var h: Vector3 = (shape as BoxShape3D).size * 0.5
			for x: float in [-1.0, 1.0]:
				for y: float in [-1.0, 1.0]:
					for z: float in [-1.0, 1.0]:
						low = minf(low, (xf * Vector3(h.x * x, h.y * y, h.z * z)).y)
		elif shape is CapsuleShape3D:
			var c := shape as CapsuleShape3D
			var half_line: float = c.height * 0.5 - c.radius
			low = minf(low, minf((xf * Vector3(0, half_line, 0)).y, (xf * Vector3(0, -half_line, 0)).y) - c.radius)
		elif shape is SphereShape3D:
			low = minf(low, xf.origin.y - (shape as SphereShape3D).radius)
		elif shape is ConvexPolygonShape3D:
			for p: Vector3 in (shape as ConvexPolygonShape3D).points:
				low = minf(low, (xf * p).y)
	return low

func _log_step() -> void:
	if not is_instance_valid(rig) or rig.bodies.is_empty() or not rig.ragdoll_active:
		return
	if _shoe_hull.is_empty():
		_prepare_feet()
	_step_index += 1
	if is_nan(_floor_top) or (not rig._flight_active and rig._flight_elapsed <= 0.0):
		return
	var row := {"step": _step_index, "frame": Engine.get_frames_drawn() if DisplayServer.get_name() != "headless" else Engine.get_process_frames(),
		"flight": rig._flight_active}
	for side: String in ["L", "R"]:
		var body := _body("Foot." + side)
		if body == null or not _shoe_hull.has(side):
			continue
		var bone: Transform3D = body.global_transform * body.body_offset.affine_inverse()
		var shoe := INF
		for p: Vector3 in _shoe_hull[side]:
			shoe = minf(shoe, (bone * p).y)
		var down := 0
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		for i in state.get_contact_count():
			if str((state.get_contact_collider_object(i) as Node).get_path()) == _floor_path and state.get_contact_local_normal(i).y < -0.5:
				down += 1
		var shin := _body("LowerLeg." + side)
		row[side] = {"collider_cm": snappedf((_floor_top - collider_low(body)) * 100.0, 0.01),
			"shoe_cm": snappedf((_floor_top - shoe) * 100.0, 0.01), "floor_normal_down": down,
			"ankle_gap_mm": snappedf((body.global_transform * body.joint_offset.origin).distance_to(shin.global_transform * (_anchor_local["Foot." + side] as Vector3)) * 1000.0, 0.1) if _anchor_local.has("Foot." + side) else null,
			"speed": snappedf(body.linear_velocity.length(), 0.001)}
	steps.append(row)

func _write_log() -> void:
	if log_path == "":
		return
	var out := FileAccess.open(log_path, FileAccess.WRITE)
	out.store_string(JSON.stringify({"fixture": fixture if fixture != "" else "office_replay",
		"events": events, "frames": rows, "floor": {"path": _floor_path, "top_m": _floor_top}, "steps": steps,
		"shoe": {"samples": measurements.size(),
			"peak_floor_penetration_m": maxf(0.0, FLOOR_TOP_M - measurements.min()) if not measurements.is_empty() else null,
			"last_floor_penetration_m": maxf(0.0, FLOOR_TOP_M - measurements[-1]) if not measurements.is_empty() else null}}, "  "))
	out.close()
