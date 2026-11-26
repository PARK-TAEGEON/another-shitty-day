extends SceneTree
## Paired 30 fps first-person replays. Each mode photographs the same three beats.
const MAIN := preload("res://scenes/main.tscn")
const PARK := "res://assets/rig_slice/park_office.glb"
var player
var world
var park
var output := ""
var pictures: Array[String] = []
var errors: Array[String] = []
var first_line := ""
var hits: Array[String] = []

func _initialize() -> void:
	_capture.call_deferred()

func _track_park() -> void:
	var target: Vector3 = park.global_position + Vector3.UP * (1.25 if hits.is_empty() else 1.0)
	var delta: Vector3 = target - player.camera.global_position
	player.rotation.y = atan2(-delta.x, -delta.z)
	player._pitch = atan2(delta.y, Vector2(delta.x, delta.z).length())

func _walk_to(goal: Vector3) -> bool:
	for frame in 180:
		var offset: Vector3 = goal - player.global_position
		if Vector2(offset.x, offset.z).length() < 0.15:
			Input.action_release("move_forward")
			for tick in 5:
				await process_frame
			return true
		var path: PackedVector3Array = world.find_navigation_path(player.global_position, goal)
		if path.is_empty():
			break
		var next: Vector3 = path[0]
		if path.size() > 1 and player.global_position.distance_to(next) < 0.15:
			next = path[1]
		var d: Vector3 = next - player.global_position
		player.rotation.y = atan2(-d.x, -d.z)
		Input.action_press("move_forward", 0.8)
		await process_frame
	Input.action_release("move_forward")
	errors.append("Could not walk to " + str(goal) + " from " + str(player.global_position))
	return false

func _save(label_name: String) -> void:
	RenderingServer.force_draw(false, 1.0 / 30.0)
	var image: Image = root.get_texture().get_image()
	if image.save_jpg(output.path_join(label_name + ".jpg"), 0.96) != OK:
		errors.append("Unable to write " + label_name)
	else:
		pictures.append(label_name)
	print("PARK_FRAME ", label_name, " state=", park.state, " phase=", park.opening_phase,
		" at=", park.global_position, " camera=", player.camera.global_position)

func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--park-frames="):
			output = arg.trim_prefix("--park-frames=")
	if output.is_empty() or DisplayServer.get_name() == "headless":
		push_error("Use a real display and --park-frames=/absolute/output.")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Cannot create capture directory " + output)
		quit(1)
		return
	# The still replay renders only photographed frames. Simulation always runs.
	RenderingServer.render_loop_enabled = false
	seed(1124)
	change_scene_to_packed(MAIN)
	await scene_changed
	var game = current_scene
	player = game.player
	world = game.world
	park = game.world.opening_coworker
	var rig: Node = park.find_child("ParkVisualAdapter", true, false)
	var model := "procedural"
	if rig != null:
		model = rig.loaded_model.scene_file_path
	var v2 := "--park-v2" in args and not "--park-legacy" in args
	if (v2 and (model != PARK or not rig.loaded_model.is_visible_in_tree())) or (not v2 and rig != null):
		push_error("Unexpected office Park selection: " + model)
		quit(1)
		return
	game._automated_run = true
	game._resume()
	game.world.scene_dialogue.connect(func(_who, line, _duration, source):
		if source == park and first_line.is_empty():
			first_line = line)
	player.contact_finished.connect(func(kind, target):
		if target == park:
			hits.append(kind))
	var punch_frame := -1
	var start_position: Vector3 = park.global_position
	# Photograph the desk from the open aisle, then walk back to the player's desk.
	if await _walk_to(Vector3(4.55, 0, -1.35)):
		_track_park()
		for i in 4: await process_frame
		if park.is_working(): _save("work")
	if not await _walk_to(Vector3(1.35, 0, 0.65)):
		push_error(str(errors))
		quit(1)
		return
	_track_park()
	for i in 10: await process_frame
	player.perform_action("slam")
	for frame in range(440):
		_track_park()
		if frame == 35 and park.opening_phase == "startle" and first_line == "왜 그래?":
			_save("startle")
		if frame == 125:
			await _walk_to(Vector3(2.04, 0, -0.05))
		if park.opening_phase == "released" and punch_frame < 0:
			if player._ray(1.87).get("collider") == park:
				punch_frame = frame
				Input.action_release("move_forward")
				player.perform_action("punch")
			else:
				Input.action_press("move_forward")
		if (park.state == "flee" and start_position.distance_to(park.global_position) > 1.15
			and not hits.is_empty() and Vector2(park.velocity.x, park.velocity.z).length() > 1.4
			and player._ray(12.0).get("collider") == park):
			_save("move")
			break
		await process_frame
	Input.action_release("move_forward")
	Input.action_release("move_right")
	var valid := pictures == ["work", "startle", "move"] and errors.is_empty()
	print("PARK_OFFICE_CAPTURE ", JSON.stringify({"model":model, "frames":pictures,
		"opening_line":first_line, "player_contacts":hits, "punch_frame":punch_frame,
		"movement_m":start_position.distance_to(park.global_position), "valid":valid}))
	game.sound.stop_all()
	quit(0 if valid else 1)
