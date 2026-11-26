extends "../integration/kim-landing.gd"
## kim-landing.gd plus a per-frame flight log. Run with --fixed-fps 30.
##   -- --log=/path/out.json                     production office replay (default)
##   -- --log=... --fixture=front|side|wall|open|ledge fixed placement, one kick
##   -- ... --side-view                           review camera beside the arc
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

func _initialize() -> void:
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
	for i in 200:
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

func _write_log() -> void:
	if log_path == "":
		return
	var out := FileAccess.open(log_path, FileAccess.WRITE)
	out.store_string(JSON.stringify({"fixture": fixture if fixture != "" else "office_replay",
		"events": events, "frames": rows,
		"shoe": {"samples": measurements.size(),
			"peak_floor_penetration_m": maxf(0.0, FLOOR_TOP_M - measurements.min()) if not measurements.is_empty() else null,
			"last_floor_penetration_m": maxf(0.0, FLOOR_TOP_M - measurements[-1]) if not measurements.is_empty() else null}}, "  "))
	out.close()
