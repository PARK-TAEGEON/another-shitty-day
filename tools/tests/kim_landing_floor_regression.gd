extends SceneTree
## Kim's kick landing on the real office floor. Run with --fixed-fps 30 (the
## frame rate of the flight-pose evidence captures).
##
## Two fixtures from docs/evidence/submission/flight_pose/flight-capture.gd, in
## the office open lane next to the low cabinet (board underside y = 0.45 m),
## Kim facing the player and flying +Z:
##   ledge - Kim on a 1 m test platform, so the arc ends at u = 1 over the floor
##   open  - the same lane without the platform
## each at 11 sideways offsets (-0.10 .. 0.10 m), every one a fresh office scene.
##
## Every physics step from the first ragdoll step (before the scripted flight),
## through the physics hand-off and the first floor contact, until rest, both feet are measured
## against the top face of the floor collider found under the lane (not y = 0):
##   collider - lowest point of every collision shape of the foot body
##   shoe     - lowest vertex of the shoe hull carried by the foot bone (50-bone)
## Rest: every Kim body below 0.05 m/s for 30 consecutive steps (0.5 s).
##
## 50-bone (default): a run fails when a foot collider or shoe sinks below the
## floor top by more than the limit at any step, when Kim does not come to rest
## within 20 s of the hand-off, or when the kick never reaches the scripted flight.
## --kim-rig (legacy 31-bone rig, not changed by the foot fix): the same runs are
## measured and printed (colliders only, no shoe hull) without penetration
## limits; the check is that its feet are still one capsule each without CCD.
const MAIN = preload("res://scenes/main.tscn")
const FIXTURES := ["ledge", "open"]
const OFFSETS := [-0.10, -0.08, -0.06, -0.04, -0.02, 0.0, 0.02, 0.04, 0.06, 0.08, 0.10]
const REST_SPEED := 0.05
const REST_STEPS := 30
const MAX_AFTER_STEPS := 1200
# Steps after the first ragdoll step without a scripted flight before the
# 31-bone fall counts as physics-owned from the start (boost delay is 0.08 s).
const NO_FLIGHT_STEPS := 30
# Limits in cm below the floor top, for any step from the first ragdoll step to
# rest. Source: aecd0f1 (the runtime before the flight pose) under these exact
# runs, docs/evidence/submission/flight_pose/checks/landing-floor-aecd0f1-v2.txt:
# the largest value among its runs whose floor contacts never pushed a foot
# downwards (ledge 7 of 11, open 6 of 11), plus 0.1 cm. The measurement itself
# rounds to 0.01 cm and the lowest 5 cm of shoe vertices are skinned 100 % to the
# foot, so the carried hull is exact there. The other aecd0f1 runs exceed these
# limits (ledge to 13.64 cm, open to 13.65 cm): that is aecd0f1's own spike.
const LIMIT_CM := {
	"ledge": {"collider": 5.17, "shoe": 3.78},
	"open": {"collider": 5.90, "shoe": 4.71},
}

var failures: Array[String] = []
var v2 := true
var game
var kim
var player
var rig
var _shoe_hull: Dictionary = {}
var _floor_top := NAN
var _floor_path := ""
var _run: Dictionary = {}
var _measuring := false
var _was_flight := false
var _still := 0

func _initialize() -> void:
	physics_frame.connect(_step)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("KIM_LANDING_FLOOR_CHECK: " + message)

func run() -> void:
	v2 = not "--kim-rig" in OS.get_cmdline_user_args()
	var summary := {}
	for fixture: String in FIXTURES:
		var limits: Dictionary = LIMIT_CM[fixture]
		var worst := {"collider": 0.0, "shoe": 0.0}
		for offset: float in OFFSETS:
			var result: Dictionary = await _case(fixture, offset)
			var label := "%s %+.2f" % [fixture, offset]
			print("KIM_LANDING_FLOOR ", JSON.stringify(result))
			if not result.get("ok", false):
				check(false, label + ": " + str(result.get("error", "run did not complete")))
				continue
			for key: String in worst:
				worst[key] = maxf(float(worst[key]), maxf(float(result.pre[key + "_cm"]), float(result.post[key + "_cm"])))
			if not v2:
				continue
			for key: String in limits:
				var pre := float(result.pre[key + "_cm"])
				var post := float(result.post[key + "_cm"])
				var at: int = int(result.post[key + "_step"]) if post >= pre else int(result.pre[key + "_step"])
				check(maxf(pre, post) <= float(limits[key]), "%s: %s %.2f cm below the floor at step %d (limit %.2f cm)" % [
					label, key, maxf(pre, post), at, float(limits[key])])
			check(bool(result.rest.reached), "%s: Kim did not come to rest within %.0f s of the hand-off" % [label, MAX_AFTER_STEPS / 60.0])
		summary[fixture] = worst
	print("KIM_LANDING_FLOOR_SUMMARY ", JSON.stringify({"mode": "50-bone" if v2 else "31-bone", "worst_cm": summary,
		"limits_cm": LIMIT_CM if v2 else "not gated"}))
	if failures.is_empty():
		print("KIM_LANDING_FLOOR_REGRESSION_OK")
	else:
		print("KIM_LANDING_FLOOR_REGRESSION_FAILED: ", failures.size(), " checks")
	quit(0 if failures.is_empty() else 1)

## 31-bone feet: one capsule each, CCD off (the foot fix is 50-bone only).
func _check_legacy_feet() -> void:
	for side: String in ["L", "R"]:
		var body := _body("Foot." + side)
		var shapes: Array[Node] = body.find_children("*", "CollisionShape3D", false, false)
		check(shapes.size() == 1 and (shapes[0] as CollisionShape3D).shape is CapsuleShape3D,
			"31-bone Foot.%s has %d collision shapes, expected one capsule" % [side, shapes.size()])
		check(not PhysicsServer3D.body_is_continuous_collision_detection_enabled(body.get_rid()),
			"31-bone Foot.%s has continuous collision detection on" % side)

func _case(fixture: String, offset: float) -> Dictionary:
	change_scene_to_packed(MAIN)
	await scene_changed
	game = current_scene
	kim = game.world.opening_boss
	player = game.player
	rig = kim._rig_adapter
	_shoe_hull = {}
	_floor_top = NAN
	_floor_path = ""
	_measuring = false
	_was_flight = false
	_still = 0
	_run = {"fixture": fixture, "offset_m": offset, "ok": false, "kick": false, "steps": 0, "flight_start_step": -1, "handoff_step": -1,
		"end": "", "first_floor_step": -1, "down_contact_steps": 0,
		"pre": {"collider_cm": 0.0, "collider_step": -1, "shoe_cm": 0.0, "shoe_step": -1},
		"post": {"collider_cm": 0.0, "collider_step": -1, "shoe_cm": 0.0, "shoe_step": -1},
		"rest": {"reached": false, "step": -1, "collider_cm": null, "shoe_cm": null}}
	if not is_instance_valid(rig) or bool(rig.visual_v2) != v2:
		_run.error = "wrong Kim rig loaded"
		return _run
	player.contact_started.connect(func(kind: String, target: Node3D) -> void:
		if kind == "kick" and target == kim:
			_run.kick = true)
	game._automated_run = true
	game._resume()
	kim._cancel_opening()
	kim.set_physics_process(false)
	# Same placement as flight-capture.gd --fixture=open|ledge --kim-offset=X.
	var kim_at := Vector3(-5.5, 0.02, -2.5)
	var player_at := Vector3(-5.5, 0.02, -3.65)
	var flight_dir := Vector3(0, 0, 1)
	kim.rotation.y = PI
	var extra: StaticBody3D = null
	if fixture == "ledge":
		extra = _test_box(Vector3(-5.5, 0.5, -2.5), Vector3(1.2, 1.0, 1.2))
		kim_at.y = 1.02
	var sideways := Vector3(-flight_dir.z, 0, flight_dir.x) * offset
	kim_at += sideways
	player_at += sideways
	kim.global_position = kim_at
	player.place_at(player_at, PI, -0.25)
	for i in 20:
		await process_frame
	_find_floor(kim_at)
	if is_nan(_floor_top):
		_run.error = "no floor collider under the lane"
		return _run
	_run.floor = {"path": _floor_path, "top_m": snappedf(_floor_top, 0.0001)}
	_look_towards(kim.global_position + Vector3.UP * 1.25, 1.0)
	await process_frame
	player.perform_action("kick")
	_measuring = true
	var frames := 0
	while _measuring and frames < 120 + MAX_AFTER_STEPS / 2:
		_look_towards(rig.pelvis_position() + Vector3.UP * 0.3, 0.12)
		await process_frame
		frames += 1
	_measuring = false
	game.sound.stop_all()
	if extra != null:
		extra.queue_free()
	if _run.handoff_step < 0:
		_run.error = "the kick never handed Kim to physics (kick contact %s)" % str(_run.kick)
		return _run
	if v2 and _run.end == "no_flight":
		_run.error = "the 50-bone kick never reached the scripted flight"
		return _run
	if not v2 and fixture == FIXTURES[0] and offset == OFFSETS[0]:
		_check_legacy_feet()
	_run.ok = true
	return _run

func _look_towards(target: Vector3, weight: float) -> void:
	var d: Vector3 = target - player.camera.global_position
	player.rotation.y = lerp_angle(player.rotation.y, atan2(-d.x, -d.z), weight)
	player._pitch = lerpf(player._pitch, atan2(d.y, Vector2(d.x, d.z).length()), weight)

func _test_box(at: Vector3, size: Vector3) -> StaticBody3D:
	var solid := StaticBody3D.new()
	solid.collision_layer = 1
	solid.collision_mask = 0
	solid.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	solid.add_child(shape)
	game.world.add_child(solid)
	return solid

## The floor: the static body a ray meets 1 m beside Kim's start (the ledge box
## sits under Kim), and the top face of its box shape.
func _find_floor(kim_at: Vector3) -> void:
	var space: PhysicsDirectSpaceState3D = rig.get_world_3d().direct_space_state
	var at: Vector3 = kim_at + Vector3(1.0, 0, 0)
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, 3.0, at.z), Vector3(at.x, -3.0, at.z), 1)
	var exclude: Array[RID] = []
	for body: PhysicalBone3D in rig.bodies:
		exclude.append(body.get_rid())
	query.exclude = exclude
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty() or not hit.collider is StaticBody3D:
		return
	var floor_body := hit.collider as StaticBody3D
	for child: Node in floor_body.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			var box: Transform3D = floor_body.global_transform * (child as CollisionShape3D).transform
			var top: float = (box * Vector3(0, ((child as CollisionShape3D).shape as BoxShape3D).size.y * 0.5, 0)).y
			if absf(top - hit.position.y) < 0.001:
				_floor_top = top
				_floor_path = str(floor_body.get_path())

func _body(name: String) -> PhysicalBone3D:
	for body: PhysicalBone3D in rig.bodies:
		if body.bone_name == name:
			return body
	return null

## Shoe vertices skinned mostly to each foot, as a convex hull in the foot bone frame.
func _prepare_shoes() -> void:
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
		check(points.size() > 100, "found only %d shoe vertices on Foot.%s" % [points.size(), side])
		var cloud := ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points
		cloud.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
		_shoe_hull[side] = (cloud.create_convex_shape(true, false) as ConvexPolygonShape3D).points

## Lowest world height of a body's collision shapes (box, capsule, sphere).
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
	return low

func _step() -> void:
	if not _measuring or not is_instance_valid(rig) or not rig.ragdoll_active:
		return
	if rig._starting:
		return
	if v2 and _shoe_hull.is_empty():
		_prepare_shoes()
	# Step 1 is the first ragdoll step. Before the hand-off ("pre"): the steps
	# up to and during the scripted flight. The 31-bone rig may fall without a
	# scripted flight; then physics owns Kim from the first ragdoll step.
	_run.steps = int(_run.steps) + 1
	var step: int = _run.steps
	var flight: bool = rig._flight_active
	if flight and int(_run.flight_start_step) < 0:
		_run.flight_start_step = step
	if int(_run.handoff_step) < 0:
		if _was_flight and not flight:
			_run.handoff_step = step
			_run.end = "normal" if rig._flight_elapsed >= rig._flight_duration - 0.0001 else "crash"
		elif not flight and int(_run.flight_start_step) < 0 and step > NO_FLIGHT_STEPS:
			_run.handoff_step = 1
			_run.end = "no_flight"
	_was_flight = flight
	var before := int(_run.handoff_step) < 0
	var phase: Dictionary = _run.pre if before else _run.post
	var collider := -INF
	var shoe := -INF
	var on_floor := false
	var down := false
	for side: String in ["L", "R"]:
		var body := _body("Foot." + side)
		collider = maxf(collider, _floor_top - collider_low(body))
		if v2:
			var bone: Transform3D = body.global_transform * body.body_offset.affine_inverse()
			var low := INF
			for p: Vector3 in _shoe_hull[side]:
				low = minf(low, (bone * p).y)
			shoe = maxf(shoe, _floor_top - low)
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		for i in state.get_contact_count():
			var other := state.get_contact_collider_object(i) as Node
			if other != null and str(other.get_path()) == _floor_path:
				on_floor = true
				# Jolt reports the normal from the other object towards this body.
				if state.get_contact_local_normal(i).y < -0.5:
					down = true
	var collider_cm := snappedf(collider * 100.0, 0.01)
	var shoe_cm := snappedf(shoe * 100.0, 0.01) if v2 else 0.0
	if collider_cm > float(phase.collider_cm):
		phase.collider_cm = collider_cm
		phase.collider_step = step
	if shoe_cm > float(phase.shoe_cm):
		phase.shoe_cm = shoe_cm
		phase.shoe_step = step
	if before:
		return
	if on_floor and int(_run.first_floor_step) < 0:
		_run.first_floor_step = step
	if down:
		_run.down_contact_steps = int(_run.down_contact_steps) + 1
	var fastest := 0.0
	for body: PhysicalBone3D in rig.bodies:
		fastest = maxf(fastest, body.linear_velocity.length())
	_still = _still + 1 if fastest < REST_SPEED else 0
	if _still >= REST_STEPS:
		_run.rest = {"reached": true, "step": step, "s_after_handoff": snappedf((step - int(_run.handoff_step)) / 60.0, 0.01),
			"collider_cm": collider_cm, "shoe_cm": shoe_cm if v2 else null}
		_measuring = false
	elif step - int(_run.handoff_step) >= MAX_AFTER_STEPS:
		_run.rest = {"reached": false, "step": step, "fastest_m_s": snappedf(fastest, 0.001),
			"last_collider_cm": collider_cm, "last_shoe_cm": shoe_cm if v2 else null}
		_measuring = false
