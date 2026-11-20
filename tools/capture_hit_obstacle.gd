extends SceneTree
## Side views of a kick into the east wall and a kick into a desk.
const MAIN = preload("res://scenes/main.tscn")
var directory: String
var frame_dir: String = "/tmp/hit-obstacle-frames"

func _initialize() -> void:
	call_deferred("run")

func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func _look(player: CharacterBody3D, at: Vector3) -> void:
	var direction: Vector3 = at - player.camera.global_position
	player.rotation.y = atan2(-direction.x, -direction.z)
	player._pitch = atan2(direction.y, Vector2(direction.x, direction.z).length())
	player.camera.rotation = Vector3(player._pitch, 0, 0)

func _boot() -> Node:
	var game: Node = MAIN.instantiate()
	root.add_child(game)
	current_scene = game
	game._automated_run = true
	game._resume()
	game.police_arrival.mode = "off"
	for _i in range(4):
		await process_frame
	return game

func _shot(game: Node, boss_at: Vector3, impulse: Vector3, camera_at: Vector3, look_at: Vector3, file_name: String, want: Callable) -> void:
	var boss: CharacterBody3D = game.world.opening_boss
	boss._cancel_opening()
	game.world.boss_lecture_finished = true
	boss.global_position = boss_at
	boss.velocity = Vector3.ZERO
	var player: CharacterBody3D = game.player
	player.set_process(false)
	player.global_position = camera_at
	player.camera.position.y = 1.7
	for _i in range(3):
		await physics_frame
	boss.receive_hit(impulse, boss.global_position + Vector3.UP * 1.2, 28.0, "kick")
	var saved := false
	for frame in range(90):
		player.global_position = camera_at
		player.camera.position.y = 1.7
		_look(player, look_at)
		await process_frame
		if frame >= 6 and frame <= 70 and frame % 2 == 0:
			await _save(frame_dir.path_join("%s-%02d.png" % [file_name.get_basename(), frame]))
		var pelvis := Vector3.ZERO
		if boss._rig_adapter != null and boss._rig_adapter.bodies.size() > 0:
			pelvis = boss._rig_adapter.pelvis_position()
		if not saved and want.call(pelvis, frame):
			await _save(directory.path_join(file_name))
			saved = true
	if not saved:
		await _save(directory.path_join(file_name))

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("A real renderer is required")
		quit(1)
		return
	directory = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(directory)
	DirAccess.make_dir_recursive_absolute(frame_dir)
	var game: Node = await _boot()
	# East wall inner face is near x=8. Kick him into that wall from the open aisle.
	await _shot(game, Vector3(6.2, 0.02, 1.6), Vector3(13, 2, 0), Vector3(6.8, 0.02, 4.4), Vector3(7.5, 1.35, 1.6), "kick-wall.png", func(pelvis: Vector3, frame: int) -> bool:
		return pelvis.x > 7.15 and pelvis.y > 0.85 and frame > 6
	)
	game.queue_free()
	await process_frame
	Engine.time_scale = 1.0
	game = await _boot()
	# Desk top is about y=1 at (4.15, 0, -5.5). Kick him south into the front edge.
	await _shot(game, Vector3(4.15, 0.02, -3.4), Vector3(0, 2, -13), Vector3(1.7, 0.02, -4.7), Vector3(4.15, 1.2, -5.1), "kick-desk.png", func(pelvis: Vector3, frame: int) -> bool:
		return pelvis.z < -4.55 and pelvis.y > 0.75 and frame > 6
	)
	print("HIT_OBSTACLE_CAPTURE_OK")
	quit(0)
