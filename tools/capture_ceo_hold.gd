extends SceneTree
## Native rendered replay. Only starting positions and dispatch are staged.
## E, movement, police witness/push, damage and results use production gameplay.
const MainScript = preload("res://scripts/main.gd")
const Office = preload("res://scripts/world.gd")
var game: Node3D
var player: CharacterBody3D
var world: Node3D
var directory: String
var evidence: Array[Dictionary] = []
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _wait(seconds: float) -> void:
	for i: int in range(ceili(seconds * 30)):
		await process_frame

func _tap(action: String) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _look(at: Vector3) -> void:
	var offset: Vector3 = at - player.camera.global_position
	player.rotation.y = atan2(-offset.x, -offset.z)
	player.set("_pitch", atan2(offset.y, Vector2(offset.x, offset.z).length()))
	player.call("_update_viewmodel", 0.0)

func _still(label: String) -> void:
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory.path_join(label + ".png"))
	var witnessed: bool = false
	for npc: Node3D in world.npcs:
		if npc.role == "police":
			witnessed = witnessed or npc.witnessed_hold
	evidence.append({"label": label, "held": game.ceo_hold.active, "hold_age": game.ceo_hold.age,
		"money": game.score, "holder": str(player.global_position), "ceo": str(world.ceo.global_position),
		"police_witness": witnessed, "caption": game.get("_caption_label").text, "ended": game.ended})

func _move(action: String, seconds: float) -> void:
	Input.action_press(action)
	await _wait(seconds)
	Input.action_release(action)
	await _wait(0.08)

func _turn_to(at: Vector3, seconds: float) -> void:
	for i: int in range(ceili(seconds * 30)):
		var offset: Vector3 = at - player.global_position
		var yaw: float = atan2(-offset.x, -offset.z)
		var event: InputEventMouseMotion = InputEventMouseMotion.new()
		event.relative = Vector2(wrapf(player.rotation.y - yaw, -PI, PI) / player.sensitivity, player.get("_pitch") / player.sensitivity)
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame

func _fixture() -> void:
	paused = false
	if is_instance_valid(game):
		game.sound.stop_all()
		game.queue_free()
		await process_frame
		await process_frame
	game = MainScript.new()
	root.add_child(game)
	game.set("_automated_run", true)
	game.call("_resume")
	player = game.player
	world = game.world
	await _wait(0.2)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("CEO_HOLD_CAPTURE: " + message)

func _run() -> void:
	directory = "user://ceo-hold-v03"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size() - 1):
		if args[i] == "--capture-dir":
			directory = args[i + 1]
	DirAccess.make_dir_recursive_absolute(directory)
	await _fixture()
	_tap("slam")
	await _wait(2.4)
	await _still("01-golden-opening")
	await _wait(4.8)
	_tap("slam")
	await _wait(1.4)
	await _still("01b-repeat-desk-A")
	# Use the default CEO and furniture, rather than relocating the target.
	await _fixture()
	player.global_position = Vector3(2.7, Office.EXECUTIVE_ELEVATION + 0.05, -1.85)
	player.velocity = Vector3.ZERO
	_look(world.ceo.global_position + Vector3.UP * 1.1)
	await _wait(4.0)
	# Window activation can deliver a mouse recenter event; restage only the
	# initial Free view before E. Held rotation still uses constrained input.
	_look(world.ceo.global_position + Vector3.UP * 1.1)
	await _wait(0.1)
	await _still("02-ceo-E-prompt")
	_tap("pickup")
	await _wait(0.65)
	_check(game.ceo_hold.active, "default CEO room failed real E grab")
	await _still("03-real-E-held")
	# Keep the pair aligned as they step through the executive-floor doorway.
	await _move("move_back", 0.66)
	await _move("move_right", 1.52)
	_check(game.ceo_hold.active and player.global_position.x > 5.95 and world.ceo.global_position.x > 5.95,
		"held pair did not enter the executive corridor")
	await _still("04-pair-crossed-doorway")
	# Existing finite dispatcher, presentation and accounting. Actor placement is
	# staged after the cut to make its individual LOS observable within this clip.
	game.police_arrival.mode = "full"
	game.call("_set_phase", 3)
	await _wait(0.5)
	await _still("05-first-police-full")
	await _wait(2.8)
	var police: CharacterBody3D
	for npc: CharacterBody3D in world.npcs:
		if npc.role == "police":
			police = npc
		elif npc.role == "guard":
			# Stage the guard away from the police-only witness demonstration.
			npc.global_position = Vector3(-1.0, Office.EXECUTIVE_ELEVATION + 0.08, -4.5)
			npc.velocity = Vector3.ZERO
	_check(is_instance_valid(police), "existing dispatch did not create police")
	if is_instance_valid(police):
		police.global_position = player.global_position + Vector3(0, 0.04, 2.55)
		police.velocity = Vector3.ZERO
		police.set("_cooldown", 0.0)
		police.set("_guard_push_active", false)
		await _turn_to(police.global_position, 0.75)
		await _wait(1.2)
		_check(police.witnessed_hold and not game.ended and game.ceo_hold.active, "visible held relation did not change real police behavior")
		await _still("06-police-witness-standoff")
		await _wait(1.2)
		_tap("pickup")
		await _wait(0.1)
		_check(not game.ceo_hold.active and not police.witnessed_hold, "E release did not immediately restore normal police")
		await _still("07-E-release-normal-response")
		game.composure = 14.0
		for i: int in range(450):
			if game.ended:
				break
			await process_frame
		_check(game.ended, "normal physical police push did not reach results")
	await _still("08-social-damage-result")
	await _wait(6.5)
	var output: Dictionary = {"capture": "native Windows automated gameplay replay; round starting position and police placement/dispatch staged; E and paired traversal/police response/physical subdual are production systems", "evidence": evidence, "failures": failures}
	var file: FileAccess = FileAccess.open(directory.path_join("replay-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	print(JSON.stringify(output))
	game.sound.stop_all()
	game.queue_free()
	paused = false
	await process_frame
	quit(0 if failures.is_empty() else 1)
