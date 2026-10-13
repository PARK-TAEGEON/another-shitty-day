extends SceneTree
## Native replay: camera/player placement is staged; all hits, carry and drops use gameplay.
const MainScript = preload("res://scripts/main.gd")
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

func _look(at: Vector3) -> void:
	var offset: Vector3 = at - player.camera.global_position
	player.rotation.y = atan2(-offset.x, -offset.z)
	player.set("_pitch", atan2(offset.y, Vector2(offset.x, offset.z).length()))
	player.call("_update_viewmodel", 0.0)

func _place(at: Vector3, look: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	_look(look)

func _still(label: String) -> void:
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory.path_join(label + ".png"))
	evidence.append({"label": label, "status": world.office_route.status, "attitude": world.office_route.attitude,
		"outcome": world.office_route.outcome, "chaos": game.chaos.breakdown(), "money": game.score,
		"ceo": str(world.office_route.ceo.global_position), "caption": game.get("_caption_label").text})

func _walk(at: Vector3, seconds: float) -> void:
	for i: int in range(ceili(seconds * 30)):
		var offset: Vector3 = at - player.global_position
		offset.y = 0.0
		if offset.length() > 0.18:
			player.rotation.y = atan2(-offset.x, -offset.z)
			Input.action_press("move_forward")
		else:
			Input.action_release("move_forward")
		await process_frame
	Input.action_release("move_forward")

func _fixture() -> void:
	paused = false
	if is_instance_valid(game):
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

func _check(ok: bool, text: String) -> void:
	if not ok:
		failures.append(text)
		push_error("SCENARIO_CAPTURE: " + text)

func _run() -> void:
	directory = "user://office-scenario"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size() - 1):
		if args[i] == "--capture-dir":
			directory = args[i + 1]
	DirAccess.make_dir_recursive_absolute(directory)
	await _fixture()
	player.perform_action("slam")
	await _wait(2.4)
	await _still("01-golden-opening")
	await _wait(4.8)
	_place(Vector3(12.0, 0.05, -2.5), Vector3(12.7, 1.4, -2.8))
	await _wait(0.6)
	player.perform_action("slam")
	await _wait(3.0)
	await _still("02-ceo-confrontation")
	var plaque: Node3D = world.office_route.authority_props[0]
	_look(plaque.global_position)
	await _wait(0.2)
	player.call("_pickup_or_drop")
	_check(player.held_prop == plaque, "A replay failed actual plaque pickup")
	await _walk(Vector3(9.1, 0.05, 0.1), 2.0)
	_look(Vector3(10.0, 1.05, -0.8))
	await _wait(0.8)
	player.call("_pickup_or_drop")
	await _wait(3.0)
	_look(world.office_route.ceo.global_position + Vector3.UP * 1.0)
	await _still("03-route-A")
	_check(world.office_route.outcome == "A", "A replay did not resolve from actual drop/arrival")
	await _wait(2.0)
	# Separate fresh round for the other player-driven result.
	await _fixture()
	_place(Vector3(13.5, 0.05, -1.2), Vector3(13.5, 0.6, -2.8))
	var chair: Node3D = world.office_route.command_prop
	for i: int in range(3):
		_look(chair.global_position + Vector3.UP * 0.5)
		player.perform_action("kick")
		await _wait(0.65)
	await _wait(3.0)
	_look(world.office_route.ceo.global_position + Vector3.UP)
	await _still("04-route-B")
	_check(world.office_route.outcome == "B", "B replay did not resolve from actual chair kicks/retreat")
	await _wait(2.0)
	# Explicit dispatch fixture shows the existing spawned police signal integration.
	game.call("_set_phase", 3)
	await _wait(0.5)
	await _still("05-police-arrival")
	await _wait(2.0)
	await _still("06-camera-restored")
	var police: Node3D = world.npcs[-1]
	_place(police.global_position + Vector3(0, 0.1, -1.0), police.global_position + Vector3.UP)
	for i: int in range(600):
		if game.ended:
			break
		await process_frame
	_check(game.ended, "replay did not reach actual security subdual")
	await _still("07-result")
	await _wait(3.0)
	var output: Dictionary = {"capture": "native automated gameplay replay with staged starting positions and explicit police dispatch fixture", "evidence": evidence, "failures": failures}
	var file: FileAccess = FileAccess.open(directory.path_join("replay-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	print(JSON.stringify(output))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
