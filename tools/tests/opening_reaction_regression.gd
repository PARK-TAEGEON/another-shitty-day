extends SceneTree
## Real-physics regression for the first desk-slam reaction scene.
## Run: godot --headless --path game --script /absolute/repo/tools/tests/opening_reaction_regression.gd
## This checks sequencing, interruption, reset, pause, free movement and the boss's route.
## It does not assess facial readability, animation quality or subtitle layout.

const WorldScript: Script = preload("res://scripts/world.gd")
const PlayerScript: Script = preload("res://scripts/player.gd")
const EXPECTED: Array[String] = ["왜 그래?", "뭐야 무슨 소리야?", "이게 무슨 짓이지?"]
const PLAYER_START: Vector3 = Vector3(0, 0.08, 0.65)

var failures: Array[String] = []
var observations: Dictionary = {}
var spoken: Array[Dictionary] = []
var invalidated: Array[int] = []
var received_damage: float = 0.0
var stage: Node3D
var world: Node3D
var player: CharacterBody3D

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("OPENING_REACTION_CHECK: " + message)

func _advance(seconds: float) -> void:
	var count: int = ceili(seconds * float(Engine.physics_ticks_per_second))
	for frame: int in range(count):
		await physics_frame

func _texts() -> Array[String]:
	var result: Array[String] = []
	for line: Dictionary in spoken:
		result.append(str(line["text"]))
	return result

func _valid_opening_and_lecture() -> bool:
	# A settled boss may now continue with the post-arrival lecture. The accepted
	# opening still has to be the exact first three lines, with no repeats or
	# unrelated delayed speech appended by a discarded opening timeline.
	var actual: Array[String] = _texts()
	if actual.size() < EXPECTED.size():
		return false
	for index: int in range(EXPECTED.size()):
		if actual[index] != EXPECTED[index]:
			return false
	var lecture: Array = WorldScript.BOSS_LECTURE_LINES
	if actual.size() > EXPECTED.size() + lecture.size():
		return false
	for index: int in range(actual.size() - EXPECTED.size()):
		if actual[EXPECTED.size() + index] != str(lecture[index]["text"]):
			return false
	return true

func _coordinates(at: Vector3) -> Array[float]:
	return [at.x, at.y, at.z]

func _line_of_sight(actor: Node3D) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		actor.global_position + Vector3.UP,
		player.global_position + Vector3.UP,
		1)
	return actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _horizontal_distance(actor: Node3D) -> float:
	var offset: Vector3 = actor.global_position - player.global_position
	offset.y = 0.0
	return offset.length()

func _on_scene_dialogue(speaker: String, text_value: String, duration: float, source: Node3D) -> void:
	check(is_instance_valid(source), "scene dialogue referenced a freed actor")
	check(duration > 0.0, "scene dialogue had no readable hold time")
	spoken.append({
		"speaker": speaker,
		"text": text_value,
		"duration": duration,
		"source_id": source.get_instance_id() if is_instance_valid(source) else 0,
		"scene_time": world.get("opening_elapsed")
	})

func _on_invalidated(source: Node3D) -> void:
	if is_instance_valid(source):
		invalidated.append(source.get_instance_id())

func _reset_fixture() -> void:
	Input.action_release("move_right")
	player.global_position = PLAYER_START
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.set("_pitch", -0.24)
	world.call("reset_world")
	spoken.clear()
	invalidated.clear()
	received_damage = 0.0
	await _advance(0.9)
	check(not bool(world.get("opening_started")) and not bool(world.get("opening_active")), "reset did not restore an unstarted opening")
	check(not bool(world.get("_disturbed")), "ordinary settled props disturbed a new office")

func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	player = PlayerScript.new() as CharacterBody3D
	player.position = PLAYER_START
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	stage.add_child(player)
	player.set("enabled", true)
	world = WorldScript.new() as Node3D
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.set("player_target", player)
	stage.add_child(world)
	world.connect("scene_dialogue", _on_scene_dialogue)
	world.connect("scene_speaker_invalidated", _on_invalidated)
	world.connect("player_hit", func(damage: float) -> void: received_damage += damage)
	await _advance(1.0)
	check(not bool(world.get("_disturbed")), "idle office physics unexpectedly began a disturbance")
	check(not bool(world.call("slam_desk", Vector3(30, 0, 30))), "out-of-reach input started the desk scene")
	check(not bool(world.get("opening_started")), "a missed slam consumed the opening")

	# The actual desk impulses remain live. Repeated slams must not restart the conversation.
	check(bool(world.call("slam_desk", player.global_position)), "nearby first desk slam was rejected")
	check(bool(world.get("opening_active")), "first quiet desk slam did not start the scene")
	var first_boss: Node3D = world.get("opening_boss") as Node3D
	var first_coworker: Node3D = world.get("opening_coworker") as Node3D
	var boss_start: Vector3 = first_boss.global_position
	await _advance(0.1)
	world.call("slam_desk", player.global_position)
	await _advance(0.6)
	check(_texts() == [EXPECTED[0]], "nearby coworker did not speak first, once")
	check(not bool(first_coworker.get("opening_cancelled")) and not bool(first_boss.get("opening_cancelled")), "the desk's own unthrown props cancelled its actors")

	# Use the real input map and CharacterBody controller, not a teleported player fixture.
	var before_move: Vector3 = player.global_position
	player.rotation.y = 0.22
	player.set("_pitch", -0.18)
	Input.action_press("move_right")
	await _advance(0.3)
	Input.action_release("move_right")
	check(player.global_position.distance_to(before_move) > 0.45, "the reaction scene blocked player movement")
	check(bool(player.get("enabled")) and absf(player.rotation.y - 0.22) < 0.001 and absf(float(player.get("_pitch")) + 0.18) < 0.001, "the reaction scene locked input or forced the player's view")
	var pause_elapsed: float = float(world.get("opening_elapsed"))
	var pause_spoken: int = spoken.size()
	var pause_boss: Vector3 = first_boss.global_position
	paused = true
	await create_timer(0.25, true, false, true).timeout
	check(is_equal_approx(float(world.get("opening_elapsed")), pause_elapsed), "opening cues advanced while paused")
	check(spoken.size() == pause_spoken and first_boss.global_position.distance_to(pause_boss) < 0.001, "a paused actor moved or spoke")
	paused = false
	await _advance(2.3)
	world.call("slam_desk", PLAYER_START)
	await _advance(4.0)
	check(_valid_opening_and_lecture(), "repeat slam or desk physics stacked, reordered or omitted opening lines")
	check(not bool(world.get("opening_active")), "opening never returned control to ordinary NPC behaviour")

	# The existing furniture and loose chairs remain physical obstacles. The player has moved.
	var route: Array[Array] = []
	var reached: bool = false
	for sample: int in range(32):
		route.append(_coordinates(first_boss.global_position))
		if _horizontal_distance(first_boss) <= 2.35 and _line_of_sight(first_boss):
			reached = true
			break
		await _advance(0.5)
	check(reached, "boss could not walk around the actual divider/desk to the moved player's speaking range")
	check(first_boss.global_position.distance_to(boss_start) > 0.7, "boss approach did not produce visible displacement")
	check(is_zero_approx(received_damage), "ordinary boss confrontation attacked the player")
	check(_valid_opening_and_lecture(), "finished opening emitted a duplicate or unrelated delayed line")
	observations["first_slam_repeat_pause_and_route"] = {
		"dialogue": spoken.duplicate(true),
		"player_before_move": _coordinates(before_move),
		"player_after_move": _coordinates(player.global_position),
		"pause_scene_time": pause_elapsed,
		"boss_start": _coordinates(boss_start),
		"boss_end": _coordinates(first_boss.global_position),
		"boss_reached_speaking_range": reached,
		"route_samples": route,
		"player_damage": received_damage
	}

	# A speaker who is hit mid-line must be invalidated; the other actor can continue.
	await _reset_fixture()
	var coworker: Node3D = world.get("opening_coworker") as Node3D
	var coworker_id: int = coworker.get_instance_id()
	world.call("slam_desk", player.global_position)
	await _advance(0.5)
	check(_texts() == [EXPECTED[0]], "reset actors could not begin a fresh opening")
	coworker.call("receive_hit", Vector3(1.0, 0.0, -2.0), coworker.global_position, 100.0)
	check(not bool(coworker.call("can_opening_react")), "a downed coworker still accepted opening cues")
	await _advance(6.3)
	check(invalidated.has(coworker_id), "hitting the current speaker did not invalidate its displayed subtitle")
	check(_valid_opening_and_lecture(), "hitting the coworker cancelled the untouched boss's sequence")
	observations["actor_specific_interruption"] = {"dialogue": spoken.duplicate(true), "speaker_invalidated": invalidated.has(coworker_id)}

	# A future speaker cannot continue acting from the floor. Reset during this timeline
	# must also prevent its later approach cue from reaching newly created actors.
	await _reset_fixture()
	var old_boss: Node3D = world.get("opening_boss") as Node3D
	var old_boss_id: int = old_boss.get_instance_id()
	world.call("slam_desk", player.global_position)
	await _advance(0.1)
	old_boss.call("receive_hit", Vector3(1.0, 0.0, -2.0), old_boss.global_position, 100.0)
	await _advance(2.1)
	var boss_lines_suppressed: bool = _texts() == [EXPECTED[0]]
	check(boss_lines_suppressed, "downed boss delivered a pending peek line")
	check(not bool(old_boss.call("can_opening_react")), "a downed boss still accepted opening cues")
	world.call("reset_world")
	spoken.clear()
	await _advance(5.0)
	var new_boss: Node3D = world.get("opening_boss") as Node3D
	check(new_boss.get_instance_id() != old_boss_id, "reset retained the previous scene actor")
	check(spoken.is_empty() and not bool(world.get("opening_active")) and not bool(world.get("opening_started")), "a discarded timeline spoke or restarted after world reset")
	observations["downed_future_speaker_and_reset"] = {"pending_boss_lines_suppressed": boss_lines_suppressed, "post_reset_dialogue_count": spoken.size()}

	# Explicit cancellation is the end/restart hook; it must be safe even if simulation resumes.
	world.call("slam_desk", player.global_position)
	await _advance(0.1)
	world.call("cancel_opening_scene")
	spoken.clear()
	await _advance(4.3)
	check(not bool(world.get("opening_active")) and spoken.is_empty(), "explicit end/restart cancellation left a pending subtitle")
	observations["explicit_cancel"] = {"post_cancel_dialogue_count": spoken.size()}

	# If the player hits someone first, the later desk slam must not replay a calm first surprise.
	await _reset_fixture()
	var disturbed_coworker: Node3D = world.get("opening_coworker") as Node3D
	disturbed_coworker.call("receive_hit", Vector3(0.5, 0, -1), disturbed_coworker.global_position, 20.0)
	check(bool(world.get("_disturbed")), "a prior direct hit did not disturb the office")
	world.call("slam_desk", player.global_position)
	await _advance(4.3)
	check(not bool(world.get("opening_active")) and spoken.is_empty(), "a slam after an earlier attack replayed the peaceful opening")
	observations["earlier_disturbance"] = {"staged_dialogue_count": spoken.size()}

	observations["failures"] = failures
	print(JSON.stringify(observations, "\t"))
	Input.action_release("move_right")
	paused = false
	stage.queue_free()
	await process_frame
	await process_frame
	print("OPENING_REACTION_REGRESSION_OK" if failures.is_empty() else "OPENING_REACTION_REGRESSION_FAILED")
	quit(0 if failures.is_empty() else 1)
