extends SceneTree
## Renders the punch stagger, the kick launch, and the impact. Capture only.
const MAIN = preload("res://scenes/main.tscn")
var directory: String

func _initialize() -> void:
	call_deferred("run")

func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(path)

func _aim(player: CharacterBody3D, at: Vector3) -> void:
	var direction: Vector3 = at - player.camera.global_position
	player.rotation.y = atan2(-direction.x, -direction.z)
	player._pitch = atan2(direction.y, Vector2(direction.x, direction.z).length())
	player._shake = 0.0
	player.camera.rotation = Vector3(player._pitch, 0.0, 0.0)

func _wall(parent: Node) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(0.0, 1.2, -0.35)
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 2.3, 0.18)
	collision.shape = shape
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c4563a")
	mesh.material_override = material
	body.add_child(mesh)

func _hits_boss(player: CharacterBody3D, boss: CharacterBody3D, reach: float) -> bool:
	var hit: Dictionary = player._ray(reach)
	var collider: Object = hit.get("collider")
	if collider == boss:
		return true
	return collider != null and collider.get("actor") == boss

func _place(game: Node) -> CharacterBody3D:
	var boss: CharacterBody3D = game.world.opening_boss
	boss._cancel_opening()
	game.world.opening_started = true
	game.world.boss_lecture_finished = true
	boss.global_position = Vector3(0.0, 0.02, 4.0)
	boss.velocity = Vector3.ZERO
	game.player.global_position = Vector3(0.0, 0.02, 5.15)
	game.player.velocity = Vector3.ZERO
	# Physics bodies keep their old pose until a few ticks. Step in after that sync.
	for _step in range(10):
		for _frame in range(2):
			await physics_frame
		_aim(game.player, boss.global_position + Vector3.UP * 1.15)
		if _hits_boss(game.player, boss, 1.9):
			break
		game.player.global_position.z -= 0.1
	print("HIT_CAPTURE_RANGE ", game.player.global_position, " ", _hits_boss(game.player, boss, 1.9))
	return boss

func _boot() -> Node:
	var game: Node = MAIN.instantiate()
	root.add_child(game)
	current_scene = game
	game._automated_run = true
	game._resume()
	game.police_arrival.mode = "off"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for _i in range(5):
		await process_frame
	_wall(game)
	return game

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("A real renderer is required")
		quit(1)
		return
	var args: PackedStringArray = OS.get_cmdline_user_args()
	directory = args[0] if not args.is_empty() else "/tmp/hit-001"
	DirAccess.make_dir_recursive_absolute(directory)
	var frame_dir := "/tmp/hit-001-frames"
	DirAccess.make_dir_recursive_absolute(frame_dir)
	var game: Node = await _boot()
	var boss: CharacterBody3D = await _place(game)
	var stand: Vector3 = game.player.global_position
	var punch_line := {"text": ""}
	boss.said.connect(func(text: String) -> void: punch_line.text = text)
	game.player.perform_action("punch")
	var punch_frames := 0
	while punch_frames < 50 and str(punch_line.text).find("꾸엑") < 0:
		game.player.global_position = stand
		game.player.velocity = Vector3.ZERO
		_aim(game.player, boss.global_position + Vector3.UP * 1.15)
		await process_frame
		punch_frames += 1
	for _extra in range(8):
		game.player.global_position = stand
		game.player.velocity = Vector3.ZERO
		_aim(game.player, boss.global_position + Vector3.UP * 1.2)
		await process_frame
	await _save(directory.path_join("punch-stagger.png"))
	var punch_state: String = str(boss.state)
	game.sound.stop_all()
	game.queue_free()
	await process_frame
	Engine.time_scale = 1.0
	game = await _boot()
	boss = await _place(game)
	stand = game.player.global_position
	boss.set_physics_process(false)
	var seen_contact: int = 0
	game.player.perform_action("kick")
	var fly_saved := false
	var impact_saved := false
	var launch_base_y: float = -1.0
	var best_rise: float = 0.0
	for frame in range(180):
		var launched: bool = boss.state == "down"
		game.player.velocity = Vector3.ZERO
		if launched:
			game.player.set_process(false)
			game.player.global_position = Vector3(5.4, 0.02, 3.2)
			game.player.camera.position.y = 2.55
			_aim(game.player, Vector3(0.0, 1.55, 2.0))
		else:
			game.player.global_position = stand
			_aim(game.player, boss.global_position + Vector3.UP * 1.15)
		await process_frame
		if frame >= 8 and frame <= 140:
			await _save(frame_dir.path_join("kick-%03d.png" % frame))
		if boss.state == "down" and is_instance_valid(boss._rig_adapter) and boss._rig_adapter.bodies.size() > 0:
			var pelvis: Vector3 = boss._rig_adapter.pelvis_position()
			if launch_base_y < 0.0:
				launch_base_y = pelvis.y
			var rise: float = pelvis.y - launch_base_y
			if rise > best_rise and rise > 1.0:
				best_rise = rise
				await _save(directory.path_join("kick-fly.png"))
				fly_saved = true
			var contacts: int = boss._rig_adapter.contact_sound_count
			if not impact_saved and fly_saved and rise < best_rise - 0.35 and contacts > seen_contact:
				await _save(directory.path_join("kick-impact.png"))
				impact_saved = true
				seen_contact = contacts
	var report: Dictionary = {
		"punch_state": punch_state,
		"punch_line": punch_line.text,
		"kick_state": str(boss.state),
		"fly_saved": fly_saved,
		"impact_saved": impact_saved,
		"contact_sounds": boss._rig_adapter.contact_sound_count if is_instance_valid(boss._rig_adapter) else 0,
		"ragdoll": boss._rig_adapter.ragdoll_active if is_instance_valid(boss._rig_adapter) else false,
	}
	var file := FileAccess.open(directory.path_join("capture-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	game.sound.stop_all()
	print("HIT_CAPTURE ", JSON.stringify(report))
	quit(0 if punch_state != "down" and fly_saved and impact_saved and "꾸엑" in str(punch_line.text) else 1)
