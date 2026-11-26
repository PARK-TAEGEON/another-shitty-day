extends SceneTree
## Run against the playable main scene. Freeze one office tick for paired pixel masks.
var out := ""
var game
var p
var mug

func _initialize() -> void:
	call_deferred("run")

func shot(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(out.path_join(label + ".png"))

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		if arg == "--setting-on":
			ProjectSettings.set_setting("asd/assets/player_arms_v2_enabled", true)
	assert(not out.is_empty())
	DirAccess.make_dir_recursive_absolute(out)
	seed(1124)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game._automated_run = true
	game._resume()
	game.police_arrival.mode = "off"
	p = game.player
	# Ignore hardware pointer motion while comparing the same spawn camera.
	p.set_process_input(false)
	p.set_process_unhandled_input(false)
	for prop in game.world.props:
		if prop.kind == "mug":
			mug = prop
			break
	for i in 20:
		await process_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	paused = true
	p._update_viewmodel(0.0)
	var guard_wrist: Vector2 = p.camera.unproject_position(p._left.global_position)
	await shot("guard")
	p._hands.hide()
	await shot("background")
	p._hands.show()
	# Hold the real asset using the same placement, sweep and wrist solver as gameplay.
	p.held_prop = mug
	mug.set_held(true)
	mug.global_basis = Basis.IDENTITY
	mug.global_position = p.camera.to_global(Vector3(0,0,-0.65))
	for i in 35:
		p._update_held(1.0/30.0)
	p._update_viewmodel(0.0)
	if p._rig_study:
		p._right.pose_sleeve(p.camera, 1.0, clampf((p._right_home.z-p._right.position.z)/0.30,0.0,1.0))
	await shot("carry")
	p._hands.hide()
	await shot("mug_only")
	mug.hide()
	await shot("no_mug")
	print("CAMERA ",p.camera.global_transform, " GUARD ",p._left_home," WRIST ",guard_wrist," CAPTION ",game._caption_panel.position," CARRY ",p.camera.to_local(mug.global_position))
	if p._rig_study:
		p.held_prop = null
		p._update_viewmodel(0.0)
		p._right.pose_sleeve(p.camera,1.0,0.0)
		p._hands.show()
		game._hud.hide()
		var inspect := Camera3D.new()
		game.add_child(inspect)
		inspect.projection = Camera3D.PROJECTION_ORTHOGONAL
		inspect.size = 0.34
		inspect.cull_mask = 1 << 18
		for mesh in p._right.meshes:
			mesh.set_layer_mask_value(19, true)
		var target: Vector3 = p._right.to_global(Vector3(0,0.080,-0.019))
		inspect.global_position = target + p._right.global_basis * Vector3(-0.44,0.07,-0.10)
		inspect.look_at(target, p._right.global_basis.y.normalized())
		# A separate inspection camera and soft key only affect this paused QA shot.
		var key := DirectionalLight3D.new()
		game.add_child(key)
		key.layers = inspect.cull_mask
		key.light_cull_mask = inspect.cull_mask
		key.light_energy = 1.15
		key.global_position = target + p._right.global_basis * Vector3(-0.50,0.58,0.42)
		key.look_at(target)
		var fill := DirectionalLight3D.new()
		game.add_child(fill)
		fill.layers = inspect.cull_mask
		fill.light_cull_mask = inspect.cull_mask
		fill.light_energy = 0.53
		fill.global_position = target + p._right.global_basis * Vector3(-0.12,-0.12,-0.80)
		fill.look_at(target)
		inspect.current = true
		await shot_grips("thumb")
		inspect.global_position = target + p._right.global_basis * Vector3(0.12,0.16,-0.55)
		inspect.look_at(target, p._right.global_basis.y.normalized())
		await shot_grips("palm")
	quit()


func shot_grips(view: String) -> void:
	for pose in [["open", 0.0], ["guard", 0.55], ["tight", 1.0]]:
		p._right.set_grip(pose[1])
		await shot(view + "_" + pose[0])
