extends SceneTree
## Outcome checks for the boss's short, purposeful approach in the actual office.
## Run with --headless --fixed-fps 60 --path game --script <this absolute path>.
## Measures travel/time, physical clearance, settled arrival and a moving target.
## Walking aesthetics and foot contact still require an actual rendered review.

const WorldScript: Script = preload("res://scripts/world.gd")
const PlayerScript: Script = preload("res://scripts/player.gd")
const PLAYER_START: Vector3 = Vector3(0, 0.08, 0.65)
const EXPECTED: Array[String] = ["왜 그래?", "뭐야 무슨 소리야?", "이게 무슨 짓이지?"]
const STEP: float = 1.0 / 60.0

var failures: Array[String] = []
var observations: Dictionary = {}
var spoken: Array[String] = []
var received_damage: float = 0.0
var stage: Node3D
var world: Node3D
var player: CharacterBody3D

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("BOSS_APPROACH_CHECK: " + message)

func _advance(seconds: float) -> void:
	for frame: int in range(ceili(seconds / STEP)):
		await physics_frame

func _flat(at: Vector3) -> Vector2:
	return Vector2(at.x, at.z)

func _coordinates(at: Vector3) -> Array[float]:
	return [at.x, at.y, at.z]

func _speed(actor: CharacterBody3D) -> float:
	return Vector2(actor.velocity.x, actor.velocity.z).length()

func _valid_opening_and_lecture() -> bool:
	if spoken.size() < EXPECTED.size():
		return false
	for index: int in range(EXPECTED.size()):
		if spoken[index] != EXPECTED[index]:
			return false
	var lecture: Array = WorldScript.BOSS_LECTURE_LINES
	if spoken.size() > EXPECTED.size() + lecture.size():
		return false
	for index: int in range(spoken.size() - EXPECTED.size()):
		if spoken[EXPECTED.size() + index] != str(lecture[index]["text"]):
			return false
	return true

func _distance(actor: Node3D) -> float:
	return _flat(actor.global_position).distance_to(_flat(player.global_position))

func _line_of_sight(actor: Node3D) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		actor.global_position + Vector3.UP,
		player.global_position + Vector3.UP,
		1)
	return actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _inside_solid(actor: CharacterBody3D) -> bool:
	# A slightly inset standing capsule ignores ordinary contact tolerance/floor.
	# This tests actual physics solids independently of the navigation rectangles.
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 2.10
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.transform = Transform3D(Basis.IDENTITY, actor.global_position + Vector3(0, 1.10, 0))
	return not actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _reset_fixture() -> void:
	Input.action_release("move_right")
	player.global_position = PLAYER_START
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.set("_pitch", -0.12)
	world.call("reset_world")
	spoken.clear()
	received_damage = 0.0
	await _advance(1.0)
	check(not bool(world.get("_disturbed")), "settling props disturbed the fresh office")

func _begin_approach() -> CharacterBody3D:
	check(bool(world.call("slam_desk", player.global_position)), "initial desk slam was not accepted")
	var boss: CharacterBody3D = world.get("opening_boss") as CharacterBody3D
	for frame: int in range(300):
		if str(boss.get("opening_phase")) == "approach":
			return boss
		await physics_frame
	check(false, "boss never began approaching after its line")
	return boss

func _trace_until_arrival(boss: CharacterBody3D, maximum_seconds: float, move_player: bool = false) -> Dictionary:
	var route: Array[Dictionary] = []
	var previous: Vector2 = _flat(boss.global_position)
	var distance_walked: float = 0.0
	var max_separation: float = _distance(boss)
	var max_height: float = boss.global_position.y
	var solid_overlap_frames: int = 0
	var settled_frames: int = 0
	var backward_seconds: float = 0.0
	var stationary_seconds: float = 0.0
	var longest_stationary_seconds: float = 0.0
	var arrival_time: float = -1.0
	var player_before: Vector3 = player.global_position
	for frame: int in range(ceili(maximum_seconds / STEP)):
		var time: float = float(frame) * STEP
		# Cross the office while the boss is already en route, then stop.
		# The player controller, table and colleague remain real physical objects.
		if move_player and frame == 48:
			Input.action_press("move_right")
		if move_player and frame == 96:
			Input.action_release("move_right")
		await physics_frame
		var at: Vector2 = _flat(boss.global_position)
		var displacement: Vector2 = at - previous
		distance_walked += displacement.length()
		previous = at
		max_separation = maxf(max_separation, _distance(boss))
		max_height = maxf(max_height, boss.global_position.y)
		if _inside_solid(boss):
			solid_overlap_frames += 1
		# Keep slow starts/turns legal; catch extended stalls and moonwalking.
		if _speed(boss) > 0.35 and displacement.length() > 0.003:
			var facing: Vector2 = Vector2(sin(boss.rotation.y), cos(boss.rotation.y))
			if facing.dot(displacement.normalized()) < -0.25:
				backward_seconds += STEP
		if time > 0.45 and _speed(boss) < 0.10 and _distance(boss) > 2.15:
			stationary_seconds += STEP
			longest_stationary_seconds = maxf(longest_stationary_seconds, stationary_seconds)
		else:
			stationary_seconds = 0.0
		if _distance(boss) <= 2.15 and _line_of_sight(boss) and _speed(boss) < 0.12 and (not move_player or time > 1.6):
			settled_frames += 1
		else:
			settled_frames = 0
		if frame % 12 == 0:
			route.append({"time": time + STEP, "boss": _coordinates(boss.global_position), "player": _coordinates(player.global_position), "speed": _speed(boss), "distance": _distance(boss)})
		if settled_frames >= 12:
			arrival_time = time + STEP - 11.0 * STEP
			break
	Input.action_release("move_right")
	return {
		"arrived": arrival_time >= 0.0,
		"arrival_seconds": arrival_time,
		"walked_metres": distance_walked,
		"max_distance_to_player": max_separation,
		"max_root_height": max_height,
		"solid_overlap_frames": solid_overlap_frames,
		"backward_seconds": backward_seconds,
		"longest_stall_seconds": longest_stationary_seconds,
		"arrival_distance": _distance(boss),
		"player_displacement": player.global_position.distance_to(player_before),
		"samples": route,
	}

func _assert_route_integrity(result: Dictionary, label: String) -> void:
	check(bool(result["arrived"]), label + ": boss did not reach an unobstructed speaking distance")
	check(int(result["solid_overlap_frames"]) == 0, label + ": shortcut cut through actual solid furniture")
	check(float(result["max_root_height"]) < 0.08, label + ": boss climbed/jumped onto office furniture")
	check(float(result["backward_seconds"]) < 0.35, label + ": boss walked backward for an extended portion of its route")
	check(float(result["longest_stall_seconds"]) < 0.75, label + ": boss stalled away from the player")
	check(is_zero_approx(received_damage), label + ": ordinary boss approach damaged the player")

func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	player = PlayerScript.new() as CharacterBody3D
	player.position = PLAYER_START
	stage.add_child(player)
	player.set("enabled", true)
	world = WorldScript.new() as Node3D
	world.set("player_target", player)
	stage.add_child(world)
	world.connect("scene_dialogue", func(_speaker: String, line: String, _duration: float, _actor: Node3D) -> void: spoken.append(line))
	world.connect("player_hit", func(damage: float) -> void: received_damage += damage)
	await _advance(1.0)
	var boss: CharacterBody3D = await _begin_approach()
	var stationary: Dictionary = await _trace_until_arrival(boss, 7.0)
	_assert_route_integrity(stationary, "stationary player")
	check(float(stationary["arrival_seconds"]) >= 0.0 and float(stationary["arrival_seconds"]) <= 4.5, "initial approach still takes more than 4.5 seconds")
	check(float(stationary["walked_metres"]) <= 5.2, "initial approach still takes an unnecessary tour of the office")
	check(float(stationary["max_distance_to_player"]) <= 3.6, "initial approach moves too far away before coming toward the player")
	check(float(stationary["arrival_distance"]) >= 1.50 and float(stationary["arrival_distance"]) <= 2.15, "boss failed to leave a sensible speaking distance")
	check(_valid_opening_and_lecture(), "approach changes altered or repeated the accepted three opening lines")
	check(bool(player.get("enabled")) and absf(player.rotation.y) < 0.001, "boss approach changed the player's control or view")
	observations["stationary_player"] = stationary

	# After braking, the boss should stand and address the player, not oscillate.
	await _advance(0.40)
	var stopped_at: Vector3 = boss.global_position
	var max_drift: float = 0.0
	var max_speed: float = 0.0
	for frame: int in range(120):
		await physics_frame
		max_drift = maxf(max_drift, boss.global_position.distance_to(stopped_at))
		max_speed = maxf(max_speed, _speed(boss))
	var to_player: Vector3 = player.global_position - boss.global_position
	var facing_error: float = absf(wrapf(boss.rotation.y - atan2(to_player.x, to_player.z), -PI, PI))
	check(max_drift < 0.03 and max_speed < 0.10, "arrived boss kept shuffling instead of standing still")
	check(facing_error < deg_to_rad(15.0), "arrived boss did not face the player")
	check(_valid_opening_and_lecture(), "settled arrival emitted repeated or unrelated opening dialogue")
	observations["settled_arrival"] = {"max_drift_metres": max_drift, "max_speed": max_speed, "facing_error_degrees": rad_to_deg(facing_error), "dialogue": spoken.duplicate()}

	await _reset_fixture()
	boss = await _begin_approach()
	# A slight outward view sends the strafe clear of the desk's front edge.
	player.rotation.y = -0.12
	player.set("_pitch", -0.20)
	var moving: Dictionary = await _trace_until_arrival(boss, 9.0, true)
	_assert_route_integrity(moving, "moving player")
	check(float(moving["player_displacement"]) > 1.5, "scene did not allow actual player movement during the approach")
	check(absf(player.rotation.y + 0.12) < 0.001 and absf(float(player.get("_pitch")) + 0.20) < 0.001, "approach forcibly turned or locked the player's camera")
	check(_valid_opening_and_lecture(), "moving during approach changed or repeated the accepted dialogue")
	observations["moving_player"] = moving

	observations["failures"] = failures
	print(JSON.stringify(observations, "\t"))
	stage.queue_free()
	await process_frame
	await process_frame
	print("BOSS_APPROACH_REGRESSION_OK" if failures.is_empty() else "BOSS_APPROACH_REGRESSION_FAILED")
	quit(0 if failures.is_empty() else 1)
