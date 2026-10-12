extends SceneTree
## Fixed-camera Godot evidence for procedural character changes. This fixture
## does not change gameplay models, physics, lighting or camera configuration.
## Run a rendered Godot process with --script <this path> -- --output-dir <dir>.

const NPC: Script = preload("res://scripts/office_npc.gd")
const FONT: Font = preload("res://assets/fonts/KoreanUI.ttf")
const PROFILES: Array[Dictionary] = [
	{"name": "김 팀장", "role": "boss", "opening": "boss", "personality": "boss", "color": Color("e7dfcc")},
	{"name": "박 대리", "role": "observer", "opening": "coworker", "personality": "sarcastic", "color": Color("6f9995")},
	{"name": "이 사원", "role": "coward", "opening": "", "personality": "rude", "color": Color("789079")},
	{"name": "최 과장", "role": "observer", "opening": "", "personality": "dumping", "color": Color("4e747d")},
	{"name": "정 인턴", "role": "observer", "opening": "", "personality": "intern", "color": Color("c48754")},
]

var stage: Node3D
var camera: Camera3D
var actors: Array[Node3D] = []
var title: Label
var subtitle: Label
var output_dir: String = "/tmp/desk-breaker-character-lineup"

func _initialize() -> void:
	call_deferred("_run")

func _box(size: Vector3, at: Vector3, color: Color) -> void:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var shape: BoxMesh = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	mesh.material_override = material
	mesh.position = at
	stage.add_child(mesh)

func _label(text_value: String, at: Vector2, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.position = at
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("eae1cf"))
	root.add_child(label)
	return label

func _save(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	var error: Error = picture.save_png(output_dir.path_join(file_name))
	if error != OK:
		push_error("Character capture failed: " + str(error))
		quit(1)
	print("CHARACTER_RENDER " + output_dir.path_join(file_name))

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output_index: int = args.find("--output-dir")
	if output_index >= 0 and output_index + 1 < args.size():
		output_dir = args[output_index + 1]
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1600, 900)
	root.msaa_3d = Viewport.MSAA_4X
	stage = Node3D.new()
	root.add_child(stage)
	var atmosphere: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("263d42")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dbe3dc")
	environment.ambient_light_energy = 0.48
	atmosphere.environment = environment
	stage.add_child(atmosphere)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -28, 0)
	key.light_color = Color("fff1da")
	key.light_energy = 0.55
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 16.0
	stage.add_child(key)
	var fill: OmniLight3D = OmniLight3D.new()
	fill.position = Vector3(4, 3, 3)
	fill.light_color = Color("d4e3e6")
	fill.light_energy = 0.12
	fill.omni_range = 12.0
	stage.add_child(fill)
	_box(Vector3(16, 0.16, 12), Vector3(0, -0.16, 0), Color("6e8583"))
	for index: int in range(PROFILES.size()):
		var data: Dictionary = PROFILES[index]
		var actor: CharacterBody3D = NPC.new() as CharacterBody3D
		actor.position = Vector3((float(index) - 2.0) * 1.45, 0, 0)
		actor.set("display_name", data["name"])
		actor.set("role", data["role"])
		actor.set("opening_role", data["opening"])
		actor.set("personality", data["personality"])
		actor.set("suit_color", data["color"])
		actor.set("work_activity", "idle")
		if data["role"] == "coward":
			actor.set("skin_color", Color("ab795b"))
		stage.add_child(actor)
		actor.set_physics_process(false)
		actor.set("opening_cancelled", true)
		actor.set("opening_phase", "released")
		actor.set("_pose_height", 0.0)
		actor.set("_head_drop", 0.0)
		actor.call("_animate_pose", 1.0, 0.0)
		actors.append(actor)
		_box(Vector3(1.32, 0.032, 0.88), actor.position + Vector3(0, -0.043, 0), Color("78918c") if index % 2 == 0 else Color("69827f"))
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.98, 9.3)
	camera.fov = 25.0
	stage.add_child(camera)
	camera.look_at(Vector3(0, 1.15, 0))
	camera.make_current()
	title = _label("캐릭터 외형 · 실제 Godot 렌더", Vector2(44, 28), 34)
	subtitle = _label("같은 카메라·조명 · 김 팀장 / 박 대리 / 이 사원 / 최 과장 / 정 인턴", Vector2(46, 80), 22)
	await _save("lineup.png")
	root.size = Vector2i(1600, 640)
	for index: int in range(actors.size()):
		actors[index].position.x = (float(index) - 2.0) * 0.85
	camera.position = Vector3(0, 1.89, 4.1)
	camera.fov = 24.0
	camera.look_at(Vector3(0, 1.62, 0))
	await _save("faces.png")
	root.size = Vector2i(1600, 900)
	for index: int in range(actors.size()):
		actors[index].position.x = (float(index) - 2.0) * 1.45
	for index: int in range(actors.size()):
		for other: int in range(actors.size()):
			actors[other].visible = other == index
		var at: Vector3 = actors[index].global_position
		camera.position = at + Vector3(0.37, 1.90, 2.52)
		camera.fov = 34.0
		camera.look_at(at + Vector3(0, 1.51, 0.04))
		title.text = str(PROFILES[index]["name"])
		subtitle.text = "절차적 3D 캐릭터 · 동일 조명과 카메라의 외형 비교"
		await _save("portrait-%02d.png" % (index + 1))
	# Close studies use the production cue/pose functions to expose the wide
	# eyes, raised brows and open mouth. They are pose studies, not a substitute
	# for the integrated opening and lecture regression or an in-game capture.
	for index: int in [1, 0]:
		for other: int in range(actors.size()):
			actors[other].visible = other == index
		var actor: Node3D = actors[index]
		actor.set("opening_cancelled", false)
		actor.call("opening_cue", "startle" if index == 1 else "peek")
		for frame: int in range(24):
			actor.set("_cue_age", float(frame) / 60.0)
			actor.call("_animate_pose", 1.0 / 60.0, 0.0)
		var head: Node3D = actor.get("_head") as Node3D
		camera.position = head.global_position + Vector3(0.24, 0.21, 1.95)
		camera.fov = 34.0
		camera.look_at(head.global_position + Vector3(0, -0.14, 0.04))
		title.text = "박 대리 · 놀람" if index == 1 else "김 팀장 · 빼꼼"
		subtitle.text = "실제 게임의 반응 포즈 · 눈·눈썹·입 가독성 확인"
		await _save("expression-coworker.png" if index == 1 else "expression-boss.png")
	quit(0)
