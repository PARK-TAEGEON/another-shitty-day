extends SceneTree
const NPC=preload("res://scripts/office_npc.gd")
const FONT=preload("res://assets/fonts/KoreanUI.ttf")
var stage: Node3D
var models: Array[Node3D]=[]
var directory: String
func _initialize() -> void:
	call_deferred("run")
func label(text_value: String, at: Vector2, size_value: int) -> Label:
	var node=Label.new()
	node.text=text_value
	node.position=at
	node.add_theme_font_override("font",FONT)
	node.add_theme_font_size_override("font_size",size_value)
	node.add_theme_color_override("font_color",Color("e8dfd0"))
	root.add_child(node)
	return node
func save(name_value: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name_value+".png"))
func run() -> void:
	directory=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(directory)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1600,900)
	stage=Node3D.new()
	root.add_child(stage)
	var env=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("283740")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("e9e6db")
	env.environment.ambient_light_energy=.65
	stage.add_child(env)
	var light=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-32,-25,0)
	light.light_energy=.9
	stage.add_child(light)
	var camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=2.85
	camera.position=Vector3(.2,1.13,6)
	stage.add_child(camera)
	camera.look_at(Vector3(.2,1.13,0))
	camera.make_current()
	var title=label("김 팀장 / 승인 시안 → 실제 Godot 모델",Vector2(38,28),32)
	var subtitle=label("Windows · Godot 4.7.2 · Compatibility · 동일 모델과 조명 / 최종 외형 승인 전",Vector2(40,76),18)
	for i in range(3):
		var actor=NPC.new()
		actor.role="boss"
		actor.use_kim_rig=true
		stage.add_child(actor)
		actor.set_physics_process(false)
		actor._animate_pose(1.0,0.0)
		actor._rig_adapter.update_pose(.15)
		actor.position=Vector3([-.40,.78,1.96][i],0,0)
		actor.rotation.y=[0,PI*.5,PI][i]
		models.append(actor)
	label("승인 그림 · 김 팀장",Vector2(38,135),19)
	var image_texture=ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://../art/references/approved/five-staff-unlikable-approved.png")))
	var reference=Sprite2D.new()
	reference.texture=image_texture
	reference.region_enabled=true
	reference.region_rect=Rect2(0,0,485,870)
	reference.centered=false
	reference.position=Vector2(35,175)
	reference.scale=Vector2.ONE*(290.0/485.0)
	root.add_child(reference)
	var captions: Array[Label]=[]
	for i in range(3):captions.append(label(["정면 / Front","측면 / Side","후면 / Back"][i],Vector2(530+i*370,802),22))
	await save("kim-turnaround-comparison")
	reference.hide()
	title.text="김 팀장 / 리그 변형 · 실제 Godot 렌더"
	subtitle.text="팔 올리기 / 고개 60° 회전 / 무릎 90° 굽힘 · 렌더 검수 후보"
	camera.size=3.6
	camera.position.x=0
	for i in range(3):
		captions[i].text=["어깨 · 팔 올리기","목 · 고개 회전","다리 · 무릎 굽힘"][i]
		captions[i].position.x=270+i*450
		models[i].position.x=-1.8+i*1.8
		models[i].rotation.y=0
		models[i]._rig_adapter.animation.play(["QA_Arms_Raised","QA_Head_Turn","QA_Knees_90"][i])
		models[i]._rig_adapter.animation.advance(0.0)
	await save("kim-deformation-check")
	print("KIM_GALLERY_CAPTURE_OK")
	quit()
