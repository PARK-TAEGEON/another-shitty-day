extends SceneTree
var camera: Camera3D
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,960)
	var world=Node3D.new()
	root.add_child(world)
	var env=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("303e48")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("d5e0eb")
	env.environment.ambient_light_energy=.6
	world.add_child(env)
	var light=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-30,-30,0)
	light.light_energy=1.0
	world.add_child(light)
	var model: Node3D
	if "--adapter" in OS.get_cmdline_user_args():
		model=load("res://scripts/office_npc.gd").new()
		model.role="boss"
		model.use_kim_rig=true
	else:
		model=load("res://assets/characters/boss_kim/boss_kim.glb").instantiate()
	world.add_child(model)
	model.set_physics_process(false)
	if "--adapter" in OS.get_cmdline_user_args():
		model._animate_pose(1.0,0.0)
		model._rig_adapter.update_pose(.2)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=2.65
	world.add_child(camera)
	camera.position=Vector3(0,1.10,5)
	camera.look_at(Vector3(0,1.10,0))
	camera.make_current()
	var output=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	for i in range(3):
		model.rotation.y=[0,PI*.5,PI][i]
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("kim-%d.png"%i))
	print("MODEL_CAPTURE_OK")
	quit()
