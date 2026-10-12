extends SceneTree
## Exercise the real main scene, player input, boss and speaker-aware HUD together.
## Run with --headless --fixed-fps 60 --path game --script <this absolute path>.
## Checks state and timing outcomes; gesture readability still needs rendered review.

const MainScript: Script = preload("res://scripts/main.gd")
const OPENING: Array[String] = ["왜 그래?", "뭐야 무슨 소리야?", "이게 무슨 짓이지?"]
const LECTURE: Array[String] = [
	"지금 뭐 하는 거야? 여기가 집이야?",
	"기분 나쁘다고 책상을 치면, 일이 해결돼?",
	"내가 말하고 있잖아. 대답 안 해?",
]
const GESTURES: Array[String] = ["question", "admonish", "insist"]
const STEP: float = 1.0 / 60.0

var failures: Array[String] = []
var observations: Dictionary = {}
var spoken: Array[Dictionary] = []
var action_results: Array[String] = []
var game: Node3D
var world: Node3D
var player: CharacterBody3D
var boss: CharacterBody3D
var clock: float = 0.0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("BOSS_LECTURE_CHECK: " + message)

func _advance(seconds: float) -> void:
	for frame: int in range(ceili(seconds / STEP)):
		clock += STEP
		await physics_frame

func _release_inputs() -> void:
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "slam", "punch", "pickup", "kick"]:
		if InputMap.has_action(action):
			Input.action_release(action)

func _tap_action(action: String) -> void:
	# Input.action_press alone does not dispatch the player's input handler.
	var pressed: InputEventAction = InputEventAction.new()
	pressed.action = action
	pressed.pressed = true
	Input.parse_input_event(pressed)
	var released: InputEventAction = InputEventAction.new()
	released.action = action
	released.pressed = false
	Input.parse_input_event(released)
	Input.flush_buffered_events()

func _texts() -> Array[String]:
	var result: Array[String] = []
	for line: Dictionary in spoken:
		result.append(str(line["text"]))
	return result

func _lecture_texts() -> Array[String]:
	var result: Array[String] = []
	for line: Dictionary in spoken:
		if LECTURE.has(str(line["text"])):
			result.append(str(line["text"]))
	return result

func _caption_is_clear_of(actor: Node3D) -> bool:
	return not bool(game.get("_caption_is_scene")) or game.get("_caption_source") != actor or float(game.get("_caption_timer")) <= 0.0

func _on_scene_dialogue(speaker: String, text_value: String, duration: float, source: Node3D) -> void:
	check(is_instance_valid(source), "scene dialogue referenced a freed actor")
	if not is_instance_valid(source):
		return
	var lecture_index: int = LECTURE.find(text_value)
	var gesture: String = str(source.get("boss_lecture_gesture")) if lecture_index >= 0 else ""
	spoken.append({"speaker": speaker, "text": text_value, "duration": duration, "time": clock, "source_id": source.get_instance_id(), "gesture": gesture})
	if lecture_index >= 0:
		check(source == boss, "a different actor delivered the boss's lecture")
		check(bool(source.call("can_boss_lecture")), "boss lectured before a settled, unobstructed arrival")
		check(bool(player.call("is_idle_for_boss_lecture")), "boss lectured while the player was acting or moving")
		check(gesture == GESTURES[lecture_index], "lecture line did not start its corresponding gesture")
		check(not bool(world.get("opening_active")), "lecture overlapped the accepted opening sequence")
		check(duration >= 2.5, "lecture line did not leave a readable subtitle duration")
		var caption: Label = game.get("_caption_label") as Label
		check(caption.text == text_value and game.get("_caption_source") == boss, "real HUD did not display the active boss line")

func _dispose_fixture() -> void:
	_release_inputs()
	paused = false
	if is_instance_valid(game):
		var sound: Node = game.get("sound") as Node
		if is_instance_valid(sound):
			sound.call("stop_all")
		game.queue_free()
		await process_frame
		await process_frame
	game = null

func _new_fixture() -> void:
	await _dispose_fixture()
	clock = 0.0
	spoken.clear()
	action_results.clear()
	game = MainScript.new() as Node3D
	root.add_child(game)
	# Prevent persistent options/record writes during the actual end-run check.
	game.set("_automated_run", true)
	game.call("_resume")
	world = game.get("world") as Node3D
	player = game.get("player") as CharacterBody3D
	boss = world.get("opening_boss") as CharacterBody3D
	world.connect("scene_dialogue", _on_scene_dialogue)
	player.connect("action_performed", func(kind: String, _at: Vector3) -> void: action_results.append(kind))
	await _advance(1.0)
	check(not bool(world.get("_disturbed")), "fresh office became disturbed without player input")

func _first_lecture() -> bool:
	var activity_before: int = int(player.get("activity_serial"))
	_tap_action("slam")
	check(int(player.get("activity_serial")) == activity_before + 1, "real F input did not register exactly one accepted player action")
	var ready_since: float = -1.0
	for frame: int in range(720):
		if bool(boss.call("can_boss_lecture")) and not bool(world.get("opening_active")):
			if ready_since < 0.0:
				ready_since = clock
		else:
			ready_since = -1.0
		if bool(world.get("boss_lecture_active")):
			check(_texts() == OPENING + [LECTURE[0]], "the real opening/lecture sequence was missing, duplicated or reordered")
			check(ready_since >= 0.0 and clock - ready_since >= 0.90, "lecture started without roughly one quiet second after the boss settled")
			return true
		await _advance(STEP)
	check(false, "idle player never received a post-arrival lecture")
	return false

func _wait_for_line(index: int, maximum_seconds: float = 5.0) -> bool:
	for frame: int in range(ceili(maximum_seconds / STEP)):
		if int(world.get("boss_lecture_index")) == index and bool(world.get("boss_lecture_active")):
			return true
		await _advance(STEP)
	check(false, "lecture did not resume at unsaid line %d" % index)
	return false

func _check_interrupted(label: String) -> void:
	check(not bool(world.get("boss_lecture_active")), label + ": active lecture continued")
	check(str(boss.get("boss_lecture_gesture")).is_empty(), label + ": speech gesture remained active")
	check(_caption_is_clear_of(boss), label + ": interrupted boss subtitle remained on the real HUD")

func _test_idle_interrupt_resume() -> void:
	await _new_fixture()
	if not await _first_lecture():
		return
	var first_started: float = clock
	var body_start: Vector3 = boss.global_position
	var serial_before_look: int = int(player.get("activity_serial"))
	var yaw_before: float = player.rotation.y
	var look: InputEventMouseMotion = InputEventMouseMotion.new()
	look.relative = Vector2(52, -17)
	Input.parse_input_event(look)
	Input.flush_buffered_events()
	var look_mode: String = "captured mouse input"
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# The headless display cannot capture a pointer. Still exercise independent
		# camera changes during speech; a rendered capture checks their visible use.
		look_mode = "camera rotation; headless pointer capture unavailable"
		player.rotate_y(-look.relative.x * float(player.get("sensitivity")))
		player.set("_pitch", float(player.get("_pitch")) - look.relative.y * float(player.get("sensitivity")))
	await _advance(0.15)
	check(absf(player.rotation.y - yaw_before) > 0.03, "view movement did not change the free camera")
	check(int(player.get("activity_serial")) == serial_before_look and bool(world.get("boss_lecture_active")), "looking at the speaker interrupted the lecture")

	# Pause the actual menu, including its player enable/disable path.
	var remaining: float = float(world.get("_boss_lecture_remaining"))
	var caption_remaining: float = float(game.get("_caption_timer"))
	var gesture_before: String = str(boss.get("boss_lecture_gesture"))
	game.call("_open_menu", false)
	await create_timer(0.35, true, false, true).timeout
	check(is_equal_approx(remaining, float(world.get("_boss_lecture_remaining"))), "lecture timer advanced while the pause menu was open")
	check(is_equal_approx(caption_remaining, float(game.get("_caption_timer"))), "caption expired while paused")
	check(str(boss.get("boss_lecture_gesture")) == gesture_before and boss.global_position.distance_to(body_start) < 0.001, "paused boss changed its active gesture or root position")
	game.call("_resume")
	check(bool(world.get("boss_lecture_active")), "resuming the pause menu discarded the active sentence")

	# A flat static stop behind the player isolates blocked input from the loose
	# desk props. Its position leaves the boss/player sight line unobstructed.
	var stop: StaticBody3D = StaticBody3D.new()
	stop.collision_layer = 1
	stop.collision_mask = 8
	stop.position = player.global_position + Vector3(0, 1.05, 0.415)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.5, 2.2, 0.15)
	collision.shape = shape
	stop.add_child(collision)
	game.add_child(stop)
	player.rotation.y = 0.0
	Input.action_press("move_back")
	await _advance(2.0 * STEP)
	_check_interrupted("held movement")
	await _advance(0.8)
	var blocked_at: Vector3 = player.global_position
	await _advance(1.2)
	var blocked_drift: float = player.global_position.distance_to(blocked_at)
	var blocked_end: Vector3 = player.global_position
	check(blocked_drift < 0.02, "blocked-input scenario did not actually stop at the static barrier")
	check(not bool(player.call("is_idle_for_boss_lecture")), "held movement against a solid barrier was treated as idle")
	check(int(world.get("boss_lecture_index")) == 1 and not bool(world.get("boss_lecture_active")), "boss resumed while a blocked movement key remained held")
	Input.action_press("move_forward")
	await _advance(0.2)
	check(not bool(player.call("is_idle_for_boss_lecture")), "opposing held movement keys were treated as idle")
	Input.action_release("move_forward")
	Input.action_release("move_back")
	stop.queue_free()
	var stopped_input_at: float = clock
	if not await _wait_for_line(2):
		return
	check(clock - stopped_input_at >= 0.90, "interrupted lecture resumed before a fresh quiet interval")
	check(_lecture_texts() == [LECTURE[0], LECTURE[1]], "moving made the boss replay a consumed sentence")

	# Aim the real player up into empty air. Accepted attack input must interrupt
	# immediately, even though its delayed contact check will report a miss.
	player.set("_pitch", 1.1)
	await _advance(0.10)
	var health_before: float = float(boss.get("health"))
	var serial_before_attack: int = int(player.get("activity_serial"))
	_tap_action("punch")
	check(int(player.get("activity_serial")) == serial_before_attack + 1, "real punch input was not accepted")
	_check_interrupted("accepted missed punch before contact")
	await _advance(0.35)
	check(action_results.has("swing") and is_equal_approx(float(boss.get("health")), health_before), "attack interruption scenario did not actually miss")
	if not await _wait_for_line(3):
		return
	check(_lecture_texts() == LECTURE, "quiet return did not continue with each unsaid sentence exactly once")
	await _advance(3.2)
	check(bool(world.get("boss_lecture_finished")), "finite lecture did not finish after its third sentence")
	_check_interrupted("completed lecture")
	var completed_lines: Array[String] = _texts()
	await _advance(4.0)
	check(_texts() == completed_lines and int(world.get("boss_lecture_index")) == 3, "continued idling restarted the completed lecture")
	check(is_equal_approx(float(game.get("composure")), 100.0), "ordinary lecture damaged the player")
	observations["idle_look_pause_blocked_move_missed_punch_resume"] = {
		"first_lecture_started_at": first_started,
		"blocked_player_drift_metres": blocked_drift,
		"blocked_sample_start": [blocked_at.x, blocked_at.y, blocked_at.z],
		"blocked_sample_end": [blocked_end.x, blocked_end.y, blocked_end.z],
		"look_verification": look_mode,
		"dialogue": spoken.duplicate(true),
		"action_results": action_results.duplicate(),
		"completed_without_repeat": _texts() == completed_lines,
		"player_composure": game.get("composure"),
	}

func _test_cancellation(mode: String) -> void:
	await _new_fixture()
	if not await _first_lecture():
		return
	var original_id: int = boss.get_instance_id()
	var old_lines: Array[String] = _texts()
	match mode:
		"hit":
			boss.call("receive_hit", Vector3(0.2, 0, -0.3), boss.global_position, 20.0)
		"down":
			boss.call("receive_hit", Vector3(0.2, 0, -0.3), boss.global_position, 100.0)
		"escalation":
			# Direct world escalation also has to invalidate its current speaker;
			# this catches callers other than the main score/phase path.
			world.call("escalate", 2)
		"end":
			game.call("_end_run")
			check(bool(game.get("ended")) and paused, "actual end-run hook did not pause the result screen")
			# Deliberately resume simulation to expose stale scheduled speech.
			paused = false
		"reset":
			world.call("reset_world")
	await _advance(0.10)
	if mode == "reset":
		boss = world.get("opening_boss") as CharacterBody3D
		check(boss.get_instance_id() != original_id, "world reset retained the previous lecture actor")
		check(not bool(world.get("opening_started")) and int(world.get("boss_lecture_index")) == 0 and not bool(world.get("boss_lecture_finished")), "reset did not restore a fresh, unconsumed lecture")
		check(not bool(game.get("_caption_is_scene")), "reset retained the discarded actor's caption")
	else:
		_check_interrupted(mode)
		check(bool(world.get("boss_lecture_finished")), mode + ": pending lecture did not permanently cancel")
	await _advance(4.0)
	check(_texts() == old_lines, mode + ": discarded lecture spoke a later sentence")
	observations[mode + "_cancellation"] = {"delayed_dialogue_count": _texts().size() - old_lines.size(), "new_actor_after_reset": boss.get_instance_id() != original_id}
	if mode == "reset":
		# A real new first slam must be able to start the fresh lecture again.
		spoken.clear()
		check(await _first_lecture(), "reset lecture could not run in a new opening")
		observations[mode + "_cancellation"]["fresh_opening_dialogue"] = spoken.duplicate(true)

func _run() -> void:
	await _test_idle_interrupt_resume()
	for mode: String in ["hit", "down", "escalation", "end", "reset"]:
		await _test_cancellation(mode)
	await _dispose_fixture()
	observations["failures"] = failures
	print(JSON.stringify(observations, "\t"))
	print("BOSS_LECTURE_REGRESSION_OK" if failures.is_empty() else "BOSS_LECTURE_REGRESSION_FAILED")
	quit(0 if failures.is_empty() else 1)
