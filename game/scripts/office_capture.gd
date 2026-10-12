extends RefCounted
## Opt-in review replay for --capture-office at --fixed-fps 30.
## Camera cuts select review angles; actions, collisions, damage and subdual use
## the real input/physics path. No NPC pose, ledger entry or health is staged.

var game: Node3D
var player: CharacterBody3D
var world: Node3D
var directory: String
var failures: Array[String] = []
var moments: Array[Dictionary] = []
var hits: Array[Dictionary] = []
var cuts: Array[Dictionary] = []
var _first_frame: int
var _headless: bool

func run(owner: Node3D) -> void:
	game = owner
	player = game.get("player") as CharacterBody3D
	world = game.get("world") as Node3D
	_headless = DisplayServer.get_name() == "headless"
	directory = "user://office-review"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	# A fast re-render of the entry/contact section still simulates every input.
	# Earlier sections retain UI rendering; only the expensive 3D draw is skipped.
	var guard_tail: bool = args.has("--capture-guard-tail")
	if guard_tail:
		game.get_viewport().disable_3d = true
	for index: int in range(args.size() - 1):
		if args[index] == "--capture-dir":
			directory = args[index + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_first_frame = Engine.get_process_frames()
	world.connect("player_hit", _on_contact)
	game.call("_resume")
	player.set("shake_scale", 0.35)
	# Ordinary work and the expanded floor before the first disturbance.
	_cut("intern", Vector3(-2.38, 0.08, -4.10), Vector3(-4.10, 1.40, -3.25))
	await _wait(3.2)
	await _still("01-intern-working")
	_check(str(game.get("_caption_speaker").text) == "정 인턴", "intern's actual proximity work line did not appear")
	await _wait(1.0)
	_cut("meeting", Vector3(1.30, 0.08, 6.0), Vector3(4.65, 1.35, 2.65))
	await _wait(2.2)
	await _still("02-meeting-bay")
	_cut("copy", Vector3(-4.0, 0.08, -8.75), Vector3(-6.35, 1.45, -7.92))
	await _wait(2.0)
	await _still("03-copier-work")
	_cut("lounge", Vector3(-3.5, 0.08, 6.25), Vector3(-5.7, 1.38, 4.20))
	await _wait(2.8)
	await _still("04-coffee-colleague")
	_check(int(game.get("score")) == 0 and float(game.get("response_heat")) == 0.0, "normal office work generated a cost or an incident")

	# Preserve the approved first desk slam and complete boss lecture.
	_cut("opening", Vector3(0, 0.08, 0.65), Vector3(0, 1.12, -3.7))
	player.set("_pitch", player.START_PITCH)
	await _wait(0.7)
	await _still("05-starting-desk")
	await _press("slam")
	await _wait(0.7)
	await _still("06-coworker-startle")
	await _wait(1.6)
	await _still("07-boss-peek")
	await _wait(2.0)
	await _still("08-boss-approach")
	var boss: Node3D = world.get("opening_boss") as Node3D
	var gestures: Dictionary = {}
	for frame: int in range(450):
		_aim(boss.global_position + Vector3.UP * 1.25, 0.10)
		await game.get_tree().process_frame
		if bool(world.get("boss_lecture_active")):
			var line_index: int = int(world.get("boss_lecture_index"))
			var beat: Dictionary = world.BOSS_LECTURE_LINES[line_index - 1]
			var age: float = float(beat["duration"]) - float(world.get("_boss_lecture_remaining"))
			if age >= 0.9 and not gestures.has(line_index):
				gestures[line_index] = true
				await _still("%02d-lecture-%s" % [8 + line_index, str(beat["gesture"])])
	_check(gestures.size() == 3 and bool(world.get("boss_lecture_finished")), "accepted boss lecture did not finish its three gestures")
	_check(int(game.get("phase")) == 1 and is_equal_approx(float(game.get("response_heat")), 0.75), "first desk splash unexpectedly escalated response heat")

	# Two real attacks, a monitor throw and a repeated desk slam earn dispatch.
	_mark("actions-begin")
	for attack: int in range(2):
		await _approach(boss, 1.25, 2.0)
		_aim(boss.global_position + Vector3.UP * 1.3)
		await _wait(0.12)
		await _press("punch")
		await _wait(0.48)
	await _still("12-boss-down")
	_check(str(boss.get("state")) == "down", "real punches did not knock the boss down")
	var monitor: RigidBody3D = _nearest_prop("monitor", Vector3(0, 1, -0.5))
	_cut("throws", Vector3(0, 0.08, 0.65), Vector3(-0.8, 1.6, -0.8))
	await _throw_at_wall(monitor, "13-held-monitor")
	await _still("14-monitor-damage")
	_check(is_instance_valid(monitor) and int(monitor.get("damage_stage")) == 2, "real monitor throw did not produce its terminal damage state")
	_aim(Vector3(0, 1.12, -3.7))
	player.set("_pitch", player.START_PITCH)
	await _wait(0.25)
	await _press("slam")
	await _wait(0.3)
	await _still("15-repeat-slam")
	await _wait(0.5)
	_check(int(game.get("phase")) == 2, "actual attacks, throw and repeat slam did not dispatch the guard")
	var guard: Node3D = _guard()
	_check(guard != null, "guard missing after qualifying incidents")
	if guard != null:
		game.get_viewport().disable_3d = false
		# This cut faces the entry while the same spawned guard continues navigating.
		_cut("guard", Vector3(0, 0.08, 3.1), guard.global_position + Vector3.UP * 1.3)
		var saved_warning: bool = false
		var saved_push: bool = false
		for frame: int in range(30 * 26):
			_aim(guard.global_position + Vector3.UP * 1.28, 0.16)
			await game.get_tree().process_frame
			if not saved_warning and str(game.get("_caption_speaker").text) == "사내 경비" and float(game.get("_caption_timer")) > 0.5:
				saved_warning = true
				await _still("16-guard-warning")
			if not saved_push and bool(guard.get("_guard_push_active")) and float(guard.get("_guard_push_age")) >= 0.23:
				saved_push = true
				await _still("17-guard-push")
			if bool(game.get("ended")):
				break
		_check(saved_warning, "guard warning never became visible during actual approach")
		_check(saved_push and not hits.is_empty(), "guard never completed a visible contact push")
	_check(bool(game.get("ended")), "actual guard did not naturally subdue the idle player")
	await _still("18-results")
	await _wait(2.4)
	var ledger: RefCounted = game.get("damage_ledger") as RefCounted
	var report: Dictionary = {
		"passed": failures.is_empty(), "failures": failures,
		"capture": "actual game; scripted input, camera cuts and automatic framing only",
		"headless": _headless, "guard_tail_only": guard_tail, "fps": 30, "frames": Engine.get_process_frames() - _first_frame,
		"camera_cuts": cuts, "moments": moments, "guard_contacts": hits,
		"final_total": ledger.total(), "breakdown": ledger.breakdown(),
		"response_heat": game.get("response_heat"), "phase": game.get("phase"),
		"boss_gestures": gestures.size(), "department_count": game.call("_staff_count", "department"),
		"other_count": game.call("_staff_count", "other"), "natural_results": game.get("ended")
	}
	var file: FileAccess = FileAccess.open(directory.path_join("review.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	else:
		_check(false, "could not save review report")
	print(JSON.stringify(report, "  "))
	print("OFFICE_CAPTURE_OK" if failures.is_empty() else "OFFICE_CAPTURE_FAILED")
	game.get("sound").stop_all()
	await game.get_tree().process_frame
	game.get_tree().quit(0 if failures.is_empty() else 1)

func _time() -> float:
	return float(Engine.get_process_frames() - _first_frame) / 30.0

func _mark(label: String) -> void:
	moments.append({"label": label, "seconds": _time(), "score": game.get("score")})

func _still(label: String) -> void:
	_mark(label)
	if not _headless:
		await game.call("_save_frame", directory.path_join(label + ".png"))

func _check(condition: bool, detail: String) -> void:
	if not condition:
		failures.append(detail)
		push_error("OFFICE_CAPTURE: " + detail)

func _wait(seconds: float) -> void:
	for frame: int in range(ceili(seconds * 30.0)):
		await game.get_tree().process_frame

func _cut(label: String, at: Vector3, target: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.set("_security_push_velocity", Vector3.ZERO)
	_aim(target)
	cuts.append({"label": label, "seconds": _time(), "position": [at.x, at.y, at.z]})

func _aim(target: Vector3, blend: float = 1.0) -> void:
	var camera: Camera3D = player.get("camera") as Camera3D
	var direction: Vector3 = target - camera.global_position
	player.rotation.y = lerp_angle(player.rotation.y, atan2(-direction.x, -direction.z), blend)
	var pitch: float = atan2(direction.y, Vector2(direction.x, direction.z).length())
	player.set("_pitch", lerpf(float(player.get("_pitch")), clampf(pitch, -1.2, 1.15), blend))

func _press(action: String) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await game.get_tree().process_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await game.get_tree().process_frame

func _approach(target: Node3D, range_m: float, timeout: float) -> void:
	for frame: int in range(ceili(timeout * 30.0)):
		var offset: Vector3 = target.global_position - player.global_position
		offset.y = 0.0
		if offset.length() <= range_m:
			break
		_aim(target.global_position + Vector3.UP * 1.3)
		Input.action_press("move_forward")
		await game.get_tree().process_frame
	Input.action_release("move_forward")
	await _wait(0.15)

func _nearest_prop(kind: String, near_at: Vector3) -> RigidBody3D:
	var closest: RigidBody3D
	var distance: float = INF
	for prop: Node3D in world.get("props"):
		if is_instance_valid(prop) and str(prop.get("kind")) == kind:
			var next_distance: float = prop.global_position.distance_to(near_at)
			if next_distance < distance:
				distance = next_distance
				closest = prop as RigidBody3D
	return closest

func _prop_center(prop: RigidBody3D) -> Vector3:
	for child: Node in prop.get_children():
		if child is CollisionShape3D:
			return (child as CollisionShape3D).global_position
	return prop.global_position

func _throw_at_wall(prop: RigidBody3D, label: String) -> void:
	if not is_instance_valid(prop):
		_check(false, "missing prop for " + label)
		return
	_aim(_prop_center(prop))
	await _wait(0.2)
	await _press("pickup")
	await _wait(0.55)
	_check(player.get("held_prop") == prop, "camera-ray pickup failed for " + label)
	await _still(label)
	_aim(Vector3(-7.85, 1.35, 0.25))
	await _wait(0.45)
	await _press("punch")
	await _wait(1.2)

func _guard() -> Node3D:
	for actor: Node3D in world.get("npcs"):
		if is_instance_valid(actor) and str(actor.get("role")) == "guard":
			return actor
	return null

func _on_contact(damage: float) -> void:
	hits.append({"seconds": _time(), "damage": damage, "composure": game.get("composure")})
