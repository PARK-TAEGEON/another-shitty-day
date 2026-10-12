extends Node3D
## Original 3D motion study v2. First B, then A twice.
## Procedural poses, shortened arm silhouette and clenched-fist cue. Not a playable build.

const FPS: int = 30
const TOTAL_FRAMES: int = 240
const DESK_TOP: float = 0.76
const START_FRAMES: Array[int] = [30, 96, 162]
const SHOT_VARIANTS: Array[String] = ["B", "A", "A"]
const PHASES: Dictionary = {
	"A": {"lift": 6, "down": 3, "hold": 2, "recover": 9},
	"B": {"lift": 8, "down": 3, "hold": 4, "recover": 13}
}

var variant: String = "SEQUENCE"
var capture_dir: String = ""
var preview_frame: int = -1
var smoke: bool = false
var camera: Camera3D
var camera_position: Vector3 = Vector3(0, 1.17, 0.49)
var camera_rotation: Vector3
var desk: Node3D
var monitor: Node3D
var mug: Node3D
var keyboard: Node3D
var paper: Node3D
var hands: Array[Node3D] = []
var contact_positions: Array[Vector3] = []
var contact_bases: Array[Basis] = []
var rest_positions: Array[Vector3] = []
var lift_positions: Array[Vector3] = []
var caption: Label
var counter: Label
var phase_label: Label
var progress: ColorRect
var contact_flash: ColorRect
var matte: StandardMaterial3D

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--variant="):
			variant = arg.get_slice("=", 1)
		elif arg.begins_with("--capture="):
			capture_dir = arg.trim_prefix("--capture=")
		elif arg.begins_with("--preview-frame="):
			preview_frame = int(arg.get_slice("=", 1))
		elif arg == "--preview-keyframes":
			preview_frame = -2
		elif arg == "--smoke-test":
			smoke = true
	if variant != "SEQUENCE" and not PHASES.has(variant):
		push_error("Unknown timing variant")
		get_tree().quit(2)
		return
	_build_world()
	_build_hands()
	_build_hud()
	_pose_frame(0)
	if smoke:
		_write_timeline()
		print("MOTION_STUDY_SMOKE_OK: ", JSON.stringify(_timeline()))
		get_tree().quit()
	elif not capture_dir.is_empty():
		_capture.call_deferred()
	else:
		_play_loop.call_deferred()

func _mat(color: String, roughness: float = 0.72, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = roughness
	m.metallic = metallic
	return m

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	parent.add_child(node)
	return node

func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(parent, b, pos, material)

func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 32
	return _mesh(parent, c, pos, material)

func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("a7b7bd")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c7d9e0")
	env.environment.ambient_light_energy = 0.32
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-43, -28, 0)
	sun.light_color = Color("fff0d9")
	sun.light_energy = 0.62
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 12
	add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.3, 2.6, 1.0)
	fill.light_color = Color("dceaf4")
	fill.light_energy = 0.16
	fill.omni_range = 6
	add_child(fill)
	var floor_mat := _mat("535e65")
	var wall_mat := _mat("bdc5c4")
	var steel_mat := _mat("35434b", 0.38, 0.3)
	var trim_mat := _mat("889b9d", 0.58)
	var fabric_mat := _mat("637d88", 0.98)
	var wood_mat := _mat("a68966", 0.64)
	var dark_mat := _mat("28363c", 0.72)
	var paper_mat := _mat("e9e5d7", 0.97)
	_box(self, Vector3(7, 0.1, 7), Vector3(0, -0.05, -1.8), floor_mat)
	_box(self, Vector3(7, 3.2, 0.14), Vector3(0, 1.6, -4), wall_mat)
	for x: float in [-3.4, 3.4]:
		_box(self, Vector3(0.15, 3.2, 7), Vector3(x, 1.6, -1.8), wall_mat)
	# Two quiet background desks and low partitions establish office scale.
	for x: float in [-1.52, 1.52]:
		_box(self, Vector3(1.35, 0.045, 0.72), Vector3(x, 0.735, -2.13), wood_mat)
		_box(self, Vector3(1.4, 0.78, 0.075), Vector3(x, 0.9, -2.58), fabric_mat)
		_box(self, Vector3(1.44, 0.025, 0.095), Vector3(x, 1.302, -2.58), trim_mat)
		for leg: float in [-0.56, 0.56]:
			_box(self, Vector3(0.045, 0.7, 0.62), Vector3(x + leg, 0.35, -2.14), steel_mat)
		_box(self, Vector3(0.43, 0.27, 0.04), Vector3(x, 1.00, -2.33), dark_mat)
		_box(self, Vector3(0.06, 0.19, 0.05), Vector3(x, 0.8, -2.33), steel_mat)
		_box(self, Vector3(0.39, 0.48, 0.08), Vector3(x + 0.12, 0.68, -1.55), dark_mat)
		_box(self, Vector3(0.43, 0.07, 0.43), Vector3(x + 0.12, 0.44, -1.51), dark_mat)
	# Rear pinboard and daylight stripe: restrained background, no characters.
	_box(self, Vector3(1.52, 0.81, 0.04), Vector3(0.01, 1.6, -3.90), fabric_mat)
	for i: int in range(4):
		var p := _box(self, Vector3(0.22, 0.29, 0.005), Vector3(-0.51 + i * 0.33, 1.61 + (i % 2) * 0.04, -3.868), paper_mat)
		p.rotation.z = float(i - 2) * 0.023
	# Desk pivot is at the top plane so impulses do not move hands separately.
	desk = Node3D.new()
	desk.name = "Desk"
	add_child(desk)
	_box(desk, Vector3(1.6, 0.052, 1.12), Vector3(0, DESK_TOP - 0.026, -0.52), wood_mat)
	_box(desk, Vector3(1.60, 0.012, 1.125), Vector3(0, DESK_TOP - 0.049, -0.52), _mat("776347"))
	for x: float in [-0.7, 0.7]:
		_box(desk, Vector3(0.052, 0.71, 0.92), Vector3(x, 0.355, -0.52), steel_mat)
	_box(desk, Vector3(1.38, 0.3, 0.025), Vector3(0, 0.43, -0.96), _mat("657074"))
	# Thin desk pad and notepad indicate depth at the contact area.
	_box(desk, Vector3(0.89, 0.004, 0.40), Vector3(0, DESK_TOP + 0.002, -0.30), _mat("627172", 0.93))
	keyboard = Node3D.new()
	keyboard.position = Vector3(0, DESK_TOP + 0.018, -0.52)
	desk.add_child(keyboard)
	_box(keyboard, Vector3(0.43, 0.025, 0.145), Vector3.ZERO, dark_mat)
	for row: int in range(4):
		for col: int in range(14):
			_box(keyboard, Vector3(0.025, 0.008, 0.022), Vector3(-0.191 + col * 0.0292, 0.015, -0.054 + row * 0.030), _mat("b9c4c5"))
	_box(keyboard, Vector3(0.17, 0.008, 0.025), Vector3(-0.004, 0.015, 0.070), _mat("b9c4c5"))
	monitor = Node3D.new()
	monitor.position = Vector3(0, DESK_TOP, -0.87)
	desk.add_child(monitor)
	_box(monitor, Vector3(0.24, 0.018, 0.17), Vector3(0, 0.012, 0), dark_mat)
	_box(monitor, Vector3(0.048, 0.15, 0.043), Vector3(0, 0.089, -0.01), steel_mat)
	_box(monitor, Vector3(0.59, 0.346, 0.040), Vector3(0, 0.31, -0.015), dark_mat)
	_box(monitor, Vector3(0.557, 0.305, 0.001), Vector3(0, 0.317, 0.006), _mat("a1b0b4", 0.99))
	# Screen represents an ordinary work document, not a fake finished UI.
	_box(monitor, Vector3(0.547, 0.032, 0.002), Vector3(0, 0.454, 0.008), _mat("3b5965"))
	_box(monitor, Vector3(0.21, 0.228, 0.002), Vector3(0.082, 0.307, 0.008), _mat("d2d8d6"))
	for i: int in range(7):
		_box(monitor, Vector3(0.161 - (i % 3) * 0.02, 0.004, 0.003), Vector3(0.08, 0.395 - i * 0.025, 0.010), _mat("819394"))
	for i: int in range(4):
		_box(monitor, Vector3(0.158, 0.012, 0.003), Vector3(-0.143, 0.39 - i * 0.042, 0.010), _mat("788f96"))
	mug = Node3D.new()
	mug.position = Vector3(0.54, DESK_TOP, -0.48)
	desk.add_child(mug)
	var ceramic := _mat("bdc5b4", 0.28)
	_cylinder(mug, 0.046, 0.096, Vector3(0, 0.048, 0), ceramic)
	_cylinder(mug, 0.039, 0.002, Vector3(0, 0.097, 0), _mat("392d24", 0.3))
	var torus := TorusMesh.new()
	torus.inner_radius = 0.021
	torus.outer_radius = 0.030
	torus.rings = 24
	torus.ring_segments = 12
	var handle := _mesh(mug, torus, Vector3(0.048, 0.047, 0), ceramic)
	handle.rotation.x = PI / 2
	handle.rotation.y = PI / 2
	paper = Node3D.new()
	paper.position = Vector3(-0.54, DESK_TOP + 0.008, -0.54)
	paper.rotation.y = 0.12
	desk.add_child(paper)
	_box(paper, Vector3(0.20, 0.015, 0.28), Vector3.ZERO, paper_mat)
	for i: int in range(6):
		_box(paper, Vector3(0.135, 0.001, 0.004), Vector3(0, 0.008, -0.07 + 0.024 * i), _mat("82918d"))
	var pen := _cylinder(paper, 0.004, 0.16, Vector3(0.06, 0.015, 0.04), _mat("334950", 0.3))
	pen.rotation.z = PI / 2
	pen.rotation.y = 0.2
	camera = Camera3D.new()
	camera.position = camera_position
	camera.fov = 62
	camera.near = 0.025
	add_child(camera)
	camera.look_at(Vector3(0, 0.88, -0.64))
	camera_rotation = camera.rotation
	camera.current = true

func _build_hands() -> void:
	var script: Script = load("res://hand_model.gd")
	for i: int in range(2):
		var hand: Node3D = script.new()
		add_child(hand)
		hand.call("build", "left" if i == 0 else "right")
		hands.append(hand)
		var sign_side: float = -1.0 if i == 0 else 1.0
		# +Y along the fist, +X thumb for right hand. Hammer-fist ulnar edge faces desk.
		var forward := Vector3(0, -0.18, -0.984).normalized()
		var thumb := Vector3(0, 0.984, -0.18).normalized() * sign_side
		var basis := Basis(thumb, forward, thumb.cross(forward)).orthonormalized()
		contact_bases.append(basis)
		var points: PackedVector3Array = hand.call("get_geometry_points")
		var min_y: float = INF
		for p: Vector3 in points:
			min_y = minf(min_y, (basis * p).y)
		# Pad top is 4 mm above desktop; exact transformed geometry keeps it above pad.
		var contact := Vector3(sign_side * 0.245, DESK_TOP + 0.004 - min_y + 0.001, -0.130)
		contact_positions.append(contact)
		rest_positions.append(Vector3(sign_side * 0.30, contact.y + 0.058, 0.110))
		lift_positions.append(Vector3(sign_side * 0.245, contact.y + 0.225, 0.008))
		print("HAND_", i, "_CONTACT_WRIST=", contact, " geometry_min_y=", min_y)

func _label(text_value: String, font_size: int, pos: Vector2, color: Color, parent: Node) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.add_theme_font_override("font", load("res://assets/KoreanUI.ttf"))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := ColorRect.new()
	top.color = Color(0.035, 0.062, 0.074, 0.91)
	top.size = Vector2(960, 84)
	layer.add_child(top)
	_label("INTRO B  /  PLAY A", 26, Vector2(26, 15), Color("e8ebe6"), layer)
	_label("첫 동작은 묵직하게 · 이후에는 빠르게", 14, Vector2(27, 50), Color("aebfc1"), layer)
	_label("MOTION STUDY 02", 14, Vector2(768, 22), Color("d0dbd8"), layer)
	_label("연출 적용 순서 시연", 13, Vector2(771, 46), Color("aebfc1"), layer)
	var bottom := ColorRect.new()
	bottom.color = Color(0.035, 0.062, 0.074, 0.90)
	bottom.position = Vector2(0, 473)
	bottom.size = Vector2(960, 67)
	layer.add_child(bottom)
	phase_label = _label("READY", 19, Vector2(26, 485), Color("e9ebe5"), layer)
	caption = _label("", 14, Vector2(196, 488), Color("d1d9d4"), layer)
	counter = _label("", 13, Vector2(862, 488), Color("b8c8c8"), layer)
	var bar := ColorRect.new()
	bar.color = Color("35474a")
	bar.position = Vector2(26, 520)
	bar.size = Vector2(908, 3)
	layer.add_child(bar)
	progress = ColorRect.new()
	progress.color = Color("e9c188")
	progress.position = bar.position
	progress.size = Vector2(1, 3)
	layer.add_child(progress)
	contact_flash = ColorRect.new()
	contact_flash.color = Color("ebbe81")
	contact_flash.position = Vector2(166, 490)
	contact_flash.size = Vector2(7, 17)
	layer.add_child(contact_flash)

func _ease(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)

func _shot_variant(index: int) -> String:
	return SHOT_VARIANTS[index] if variant == "SEQUENCE" else variant

func _pose_frame(frame: int) -> void:
	var local_frame: int = -1
	var shot: int = 0
	var current_variant: String = _shot_variant(0)
	for index: int in range(START_FRAMES.size()):
		if frame >= START_FRAMES[index]:
			local_frame = frame - START_FRAMES[index]
			shot = index + 1
			current_variant = _shot_variant(index)
	var config: Dictionary = PHASES[current_variant]
	var lift_f: int = config["lift"]
	var down_f: int = config["down"]
	var hold_f: int = config["hold"]
	var recover_f: int = config["recover"]
	var phase := "READY"
	var lift_amount: float = 0.0
	var down_amount: float = 0.0
	var reset_amount: float = 0.0
	if local_frame >= 0 and local_frame < lift_f:
		phase = "LIFT"
		lift_amount = _ease(float(local_frame) / float(lift_f))
	elif local_frame >= lift_f and local_frame < lift_f + down_f:
		phase = "DOWN"
		lift_amount = 1
		down_amount = pow(float(local_frame - lift_f) / float(down_f), 1.65)
	elif local_frame >= lift_f + down_f and local_frame < lift_f + down_f + hold_f:
		phase = "CONTACT"
		down_amount = 1
	elif local_frame >= lift_f + down_f + hold_f and local_frame < lift_f + down_f + hold_f + recover_f:
		phase = "RESET"
		reset_amount = _ease(float(local_frame - lift_f - down_f - hold_f) / float(recover_f))
		down_amount = 1
	var impact_time: float = -1
	for index: int in range(START_FRAMES.size()):
		var event_config: Dictionary = PHASES[_shot_variant(index)]
		var t: float = float(frame - START_FRAMES[index] - event_config["lift"] - event_config["down"]) / float(FPS)
		if t >= 0:
			impact_time = t
	var shock: float = 0.0
	var body_follow: float = 0.0
	if impact_time >= 0 and impact_time < 1.3:
		shock = sin(impact_time * TAU * 9.5) * exp(-impact_time * 10.5)
		body_follow = sin(minf(impact_time / 0.28, 1.0) * PI) * exp(-impact_time * 3.0)
	# Props react only at or after geometric contact, using the v1 impulse functions.
	desk.position.y = -absf(shock) * 0.003
	monitor.rotation.x = shock * 0.035
	monitor.rotation.z = shock * 0.014
	mug.rotation.z = shock * 0.09
	mug.position.y = DESK_TOP + maxf(0, shock) * 0.009
	keyboard.position.y = DESK_TOP + 0.018 + maxf(0, shock) * 0.004
	paper.rotation.z = shock * 0.035
	paper.position.y = DESK_TOP + 0.008 + maxf(0, shock) * 0.006
	var brace: float = lift_amount * (1.0 - down_amount)
	camera.position = camera_position + Vector3(0, shock * 0.004 - body_follow * 0.008 - brace * 0.003, shock * 0.002 + brace * 0.004)
	camera.rotation = camera_rotation + Vector3(shock * 0.008 - body_follow * 0.006, 0, 0)
	for i: int in range(2):
		var sign_side: float = -1.0 if i == 0 else 1.0
		var rest: Vector3 = rest_positions[i]
		var lifted: Vector3 = lift_positions[i]
		var contact: Vector3 = contact_positions[i] + Vector3(0, desk.position.y, 0)
		var basis: Basis = contact_bases[i]
		var rest_basis: Basis = Basis(Vector3.RIGHT, -0.13) * basis
		var lift_basis: Basis = Basis(Vector3.UP, -sign_side * 0.08) * Basis(Vector3.RIGHT, 0.62) * Basis(Vector3.BACK, sign_side * 0.04) * basis
		var position_value: Vector3 = rest
		var rotation_value: Quaternion = rest_basis.get_rotation_quaternion()
		var grip: float = 0.55
		if phase == "LIFT":
			position_value = rest.lerp(lifted, lift_amount)
			position_value.x += sign_side * sin(lift_amount * PI) * 0.014
			position_value.z += sin(lift_amount * PI) * 0.021
			rotation_value = rotation_value.slerp(lift_basis.get_rotation_quaternion(), lift_amount)
			grip = lerpf(0.55, 1.0, minf(lift_amount * 2.0, 1.0))
		elif phase == "DOWN":
			position_value = lifted.lerp(contact, down_amount)
			rotation_value = lift_basis.get_rotation_quaternion().slerp(basis.get_rotation_quaternion(), down_amount)
			grip = 1.0
		elif phase == "CONTACT":
			position_value = contact
			rotation_value = basis.get_rotation_quaternion()
			grip = 1.0
		elif phase == "RESET":
			position_value = contact.lerp(rest, reset_amount)
			position_value.y += sin(reset_amount * PI) * 0.044
			position_value.x += sign_side * sin(reset_amount * PI) * 0.014
			rotation_value = basis.get_rotation_quaternion().slerp(rest_basis.get_rotation_quaternion(), reset_amount)
			grip = lerpf(1.0, 0.55, reset_amount)
		hands[i].position = position_value
		hands[i].quaternion = rotation_value
		hands[i].call("set_grip", grip)
	phase_label.text = current_variant + " · " + phase
	var phase_text: Dictionary = {"READY": "연출 적용 순서: 첫 B → 이후 A · 자동 재생 시연", "LIFT": "준비 · 손을 몸 가까이 들고 주먹에 힘 주기", "DOWN": "내려침 · 짧은 궤적으로 가속", "CONTACT": "접촉 · 새끼손가락 쪽으로 상판 타격", "RESET": "복귀 · 손목과 팔꿈치를 회수"}
	caption.text = phase_text[phase]
	counter.text = "%02d / 03" % mini(shot, 3)
	progress.size.x = 908.0 * float(frame) / float(TOTAL_FRAMES - 1)
	contact_flash.visible = phase == "CONTACT"

func _timeline() -> Dictionary:
	var events: Array = []
	for index: int in range(START_FRAMES.size()):
		var timing: String = _shot_variant(index)
		var config: Dictionary = PHASES[timing]
		var start: int = START_FRAMES[index]
		var cursor: int = start
		var phases: Array = []
		for key: String in ["lift", "down", "hold", "recover"]:
			var duration: int = config[key]
			phases.append({"phase": key, "start_frame": cursor, "end_frame_exclusive": cursor + duration, "start_s": float(cursor) / FPS, "duration_s": float(duration) / FPS})
			cursor += duration
		events.append({"timing": timing, "role": "intro" if index == 0 else "repeat_action", "input_frame": start, "input_s": float(start) / FPS, "contact_frame": start + config["lift"] + config["down"], "contact_s": float(start + config["lift"] + config["down"]) / FPS, "total_motion_frames": cursor - start, "phases": phases})
	return {"variant": variant, "fps": FPS, "total_frames": TOTAL_FRAMES, "duration_s": float(TOTAL_FRAMES) / FPS, "events": events, "provenance": "Original procedural hand geometry and scripted poses. Revision of motion-study based on user feedback; no reference motion extracted.", "changes": ["Outward elbow bend shortens the straight sleeve silhouette", "Contact moved 12.5 cm closer to camera, lift reduced by 6.5 cm", "Compact thumb and curled fingers with a 2 mm grip cue", "Small wrist turn, curved preparation and controlled body follow", "First B 28f, next two A 20f; original timing preserved"], "world_fov_deg": 62, "desk_top_m": DESK_TOP, "desk_pad_top_m": DESK_TOP + 0.004, "contact_wrists_m": [str(contact_positions[0]), str(contact_positions[1])], "limitations": ["Motion study, character art direction not selected", "Pose interpolation and procedural meshes, not a production skeletal rig", "Scripted props and automatic sequence; not playable controls", "Audio added during encoding"]}

func _write_timeline() -> void:
	var dir: String = capture_dir if not capture_dir.is_empty() else ProjectSettings.globalize_path("res://renders")
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("timeline_" + variant + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_timeline(), "\t"))

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(capture_dir)
	_write_timeline()
	for i: int in range(6):
		await get_tree().process_frame
	if preview_frame >= 0 or preview_frame == -2:
		var selected: Array = [preview_frame] if preview_frame >= 0 else [20, 38, 40, 41, 46, 102, 105, 110]
		for frame: int in selected:
			_pose_frame(frame)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var result: Error = get_viewport().get_texture().get_image().save_png(capture_dir.path_join("preview_%04d.png" % frame))
			print("PREVIEW_RESULT=", result, " frame=", frame)
	else:
		for frame: int in range(TOTAL_FRAMES):
			_pose_frame(frame)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var result: Error = get_viewport().get_texture().get_image().save_png(capture_dir.path_join("frame_%04d.png" % frame))
			if result != OK:
				push_error("Failed to save rendered frame")
				get_tree().quit(3)
				return
			if frame % 30 == 0:
				print("CAPTURE_", variant, " frame=", frame)
	print("CAPTURE_COMPLETE_", variant)
	get_tree().quit()

func _play_loop() -> void:
	var frame: int = 0
	while is_inside_tree():
		_pose_frame(frame)
		await get_tree().create_timer(1.0 / float(FPS)).timeout
		frame = (frame + 1) % TOTAL_FRAMES
