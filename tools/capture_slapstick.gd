extends SceneTree
## Slapstick hit-reaction STUDY (PROPOSED, not gameplay). Uses the real office,
## procedural staff, first-person hands/foot, mug prop and synthesized sounds,
## then hand-animates comic launches: punch, kick and a thrown mug.
## Nothing here changes game code; NPC AI is paused for the staged actors.
##
## Record with Godot's Movie Maker so frames and audio are deterministic:
##   godot --path game --write-movie out.avi --fixed-fps 30 \
##         --script res://../tools/capture_slapstick.gd   (or an absolute path)

const WorldScript = preload("res://scripts/world.gd")
const PlayerScript = preload("res://scripts/player.gd")
const SoundScript = preload("res://scripts/audio.gd")
const FONT: Font = preload("res://assets/fonts/KoreanUI.ttf")

const GRAVITY: float = 9.8
const LANE_Z: float = 0.9
const PLAYER_X: float = -3.9
const WALL_X: float = -7.99
const PIVOT: float = 1.1 # Body centre above the feet, used as the tumble pivot.

var world: Node3D
var player: CharacterBody3D
var sound: Node
var caption_panel: PanelContainer
var caption_speaker: Label
var caption_line: Label
var shot_label: Label
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var shot: int = -1
var t: float = 0.0
var hitstop: float = 0.0
var events: Dictionary = {}
var actor: CharacterBody3D
var actor_yaw: float = PI * 0.5
var center: Vector3
var velocity: Vector3
var tilt: float = 0.0
var spin: float = 0.0
var spin_rate: float = 0.0
var squash: float = 0.0
var squash_anchor: float = PIVOT
var phase: String = "talk"
var phase_t: float = 0.0
var bounce_v: float = 0.0
var bounces: int = 0
var mug: RigidBody3D
var mug_from: Vector3
var mug_to: Vector3
var cup: Node3D
var cup_velocity: Vector3
var cup_spin: Vector3
var puffs: Array[Dictionary] = []
var stars: Array[Node3D] = []
var look_target: Vector3
var timer_total: float = 0.0
var plank_foot_x: float = 0.0

const SHOTS: Array[Dictionary] = [
	{"label": "1 · 주먹", "who": "김 팀장", "line": "내가 말하고 있잖아. 대답 안 해?", "x": -5.3, "length": 5.0},
	{"label": "2 · 발차기", "who": "박 대리", "line": "오, 오늘은 제시간에 끝내게?", "x": -5.15, "length": 5.4},
	{"label": "3 · 던지기", "who": "최 과장", "line": "네가 제일 빠르잖아. 이것도 부탁할게.", "x": -5.85, "length": 6.6},
]

var ready_to_run: bool = false

func _initialize() -> void:
	call_deferred("_setup")

func _setup() -> void:
	rng.seed = 2026
	world = WorldScript.new()
	root.add_child(world)
	player = PlayerScript.new()
	player.position = Vector3(PLAYER_X, 0.08, LANE_Z)
	player.rotation.y = PI * 0.5
	root.add_child(player)
	world.set("player_target", player)
	player.set("enabled", true)
	player.set("shake_scale", 0.9)
	sound = SoundScript.new()
	root.add_child(sound)
	_build_ui()
	_start_shot(0)
	ready_to_run = true

# --- UI matching the game's caption style ---------------------------------

func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	root.add_child(layer)
	caption_panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.09, 0.9)
	style.set_corner_radius_all(12)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 14
	style.content_margin_bottom = 16
	caption_panel.add_theme_stylebox_override("panel", style)
	caption_panel.position = Vector2(240, 560)
	caption_panel.size = Vector2(800, 104)
	layer.add_child(caption_panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	caption_panel.add_child(box)
	caption_speaker = _label(20, Color("e9a46f"))
	caption_line = _label(31, Color("f1e8d6"))
	box.add_child(caption_speaker)
	box.add_child(caption_line)
	shot_label = _label(26, Color("f1e8d6"))
	shot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var tag: PanelContainer = PanelContainer.new()
	var tag_style: StyleBoxFlat = style.duplicate()
	tag_style.content_margin_top = 8
	tag_style.content_margin_bottom = 8
	tag_style.content_margin_left = 18
	tag_style.content_margin_right = 18
	tag.add_theme_stylebox_override("panel", tag_style)
	tag.position = Vector2(28, 26)
	tag.add_child(shot_label)
	layer.add_child(tag)

func _label(size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

# --- Shot setup ---------------------------------------------------------------

func _npc(name_value: String) -> CharacterBody3D:
	for npc: Node3D in world.get("npcs"):
		if npc.get("display_name") == name_value:
			return npc as CharacterBody3D
	return null

func _start_shot(index: int) -> void:
	if is_instance_valid(actor):
		actor.visible = false
	for star: Node3D in stars:
		star.queue_free()
	stars.clear()
	shot = index
	t = 0.0
	phase = "talk"
	phase_t = 0.0
	events.clear()
	squash = 0.0
	tilt = 0.0
	spin = 0.0
	spin_rate = 0.0
	bounces = 0
	var data: Dictionary = SHOTS[index]
	shot_label.text = data["label"]
	caption_speaker.text = data["who"]
	caption_line.text = data["line"]
	caption_panel.visible = true
	actor = _npc(data["who"])
	actor.set_physics_process(false)
	actor.collision_layer = 0
	actor.collision_mask = 0
	actor.set("opening_cancelled", true)
	actor.set("opening_phase", "released")
	actor.set("state", "idle")
	actor.set("_pose_height", 0.0)
	actor.set("_head_drop", 0.0)
	actor.set("_head_base", Vector3(0, 1.78 if actor.get("_broad") else (1.80 if actor.get("_thin") else 1.70), 0.025))
	actor.set("work_activity", "coffee" if index == 2 else "idle")
	actor.set("_talk_time", 3.0)
	center = Vector3(float(data["x"]), PIVOT, LANE_Z)
	velocity = Vector3.ZERO
	_place()
	player.global_position = Vector3(PLAYER_X, 0.08, LANE_Z)
	player.rotation.y = PI * 0.5
	player.set("_pitch", -0.05)
	look_target = center + Vector3(0, 0.35, 0)
	for _warm: int in range(12):
		# Settle the authored pose before the cut so nobody stands up on camera.
		actor.call("_animate_pose", 0.1, 0.0)
	_place()
	_update_camera(1.0) # Hard cut: snap the view onto the new actor.
	if index == 0:
		# The boss wags a finger: the authored lecture pose, driven manually.
		actor.set("boss_lecture_gesture", "admonish")
		actor.set("_lecture_pose", "admonish")
		actor.set("_lecture_duration", 99.0)
		actor.set("_lecture_age", 0.0)
		actor.set("_lecture_blend", 1.0)
		_lecture_hands(true)
	if index == 2:
		mug = world.call("_prop", "mug", "머그컵", player.global_position + Vector3(-0.9, 1.4, 0), Color("dc8855")) as RigidBody3D
		mug.call("set_held", true)
		player.set("held_prop", mug)
		cup = actor.get("_work_prop") as Node3D

func _lecture_hands(on: bool) -> void:
	for wrist: Node3D in actor.get("_lecture_wrists"):
		wrist.visible = on
	for hand: Node3D in actor.get("_rest_hands"):
		hand.visible = not on

# --- Main loop ----------------------------------------------------------------

func _process(delta: float) -> bool:
	if not ready_to_run:
		return false
	timer_total += delta
	_update_puffs(delta)
	_update_stars(delta)
	_update_camera(delta)
	if hitstop > 0.0:
		hitstop -= delta
		_pose_actor(0.0)
		return false
	t += delta
	phase_t += delta
	match shot:
		0:
			_shot_punch(delta)
		1:
			_shot_kick(delta)
		2:
			_shot_throw(delta)
	_pose_actor(delta)
	if t >= float(SHOTS[shot]["length"]):
		if shot + 1 < SHOTS.size():
			_start_shot(shot + 1)
		else:
			quit(0)
	return false

func _once(key: String) -> bool:
	if events.has(key):
		return false
	events[key] = true
	return true

func _set_phase(value: String) -> void:
	phase = value
	phase_t = 0.0

func _hit(at: Vector3, power: float, kind: String = "impact") -> void:
	hitstop = 0.1 if power > 0.6 else 0.05
	player.call("add_shake", power)
	sound.call("play", kind, 0.9 + power * 0.6)
	_puff(at, 7 + int(power * 6), 0.9 + power)

# 1. Punch: the boss rockets back, whirls once, flattens on the wall, peels off.
func _shot_punch(delta: float) -> void:
	if phase == "talk" and t >= 1.55 and _once("swing"):
		player.call("perform_action", "punch")
		sound.call("play", "swing", 0.8)
	if phase == "talk" and t >= 1.665:
		caption_panel.visible = false
		actor.set("boss_lecture_gesture", "")
		actor.set("_lecture_blend", 0.0)
		_lecture_hands(false)
		actor.set("state", "stunned")
		_hit(_head_point() + Vector3(0.18, -0.05, 0), 1.0)
		var flight: float = 0.46
		var contact_center_x: float = WALL_X + 1.1
		velocity = Vector3((contact_center_x - center.x) / flight, (1.65 - PIVOT + 0.5 * GRAVITY * flight * flight) / flight, 0)
		spin_rate = (PI * 0.5 + TAU) / flight
		_set_phase("fly")
	elif phase == "fly":
		center += velocity * delta
		velocity.y -= GRAVITY * delta
		tilt += spin_rate * delta
		if center.x - 1.1 <= WALL_X:
			center.x = WALL_X + 1.1
			tilt = PI * 0.5 + TAU
			squash = 0.34
			squash_anchor = 2.2
			_hit(Vector3(WALL_X + 0.05, center.y, LANE_Z), 1.0, "slam")
			_set_phase("stuck")
	elif phase == "stuck":
		center.y -= delta * 0.12 # A slow, comic slide while pinned to the wall.
		if phase_t > 0.5:
			velocity = Vector3(0.6, 0, 0)
			_set_phase("drop")
	elif phase == "drop":
		_fall_to_back(delta, 0.30)
	elif phase == "rest":
		_rest(delta)

# 2. Kick: the coworker helicopters up, lands on his back and breakdance-spins.
func _shot_kick(delta: float) -> void:
	if phase == "talk" and t >= 1.45 and _once("kick"):
		player.call("perform_action", "kick")
		sound.call("play", "swing", 0.9)
	if phase == "talk" and t >= 1.565:
		caption_panel.visible = false
		actor.set("state", "stunned")
		_hit(center + Vector3(0.2, -0.05, 0), 1.0)
		var flight: float = 1.1
		velocity = Vector3((-6.3 - center.x) / flight, (0.22 - PIVOT + 0.5 * GRAVITY * flight * flight) / flight, 0)
		spin_rate = 17.0
		_set_phase("fly")
	elif phase == "fly":
		center += velocity * delta
		velocity.y -= GRAVITY * delta
		tilt = minf(tilt + delta * 4.5, PI * 0.5)
		spin += spin_rate * delta
		if center.y <= 0.22 and velocity.y < 0.0:
			center.y = 0.22
			velocity = Vector3(velocity.x * 0.55, 0, 0)
			bounce_v = 2.0
			squash = 0.22
			squash_anchor = PIVOT
			_hit(center + Vector3(0, -0.15, 0), 0.7)
			_set_phase("breakdance")
	elif phase == "breakdance":
		center.x += velocity.x * delta
		velocity.x = move_toward(velocity.x, 0.0, delta * 1.6)
		spin += spin_rate * delta
		spin_rate = move_toward(spin_rate, 0.0, delta * 8.5)
		_bounce(delta, 0.22)
		if spin_rate <= 0.0 and bounce_v <= 0.0:
			_set_phase("rest")
	elif phase == "rest":
		_rest(delta)

# 3. Throw: the mug hits the manager's head, he backflips, lands, wobbles, his
#    own coffee cup comes down on his head, and he falls flat like a plank.
func _shot_throw(delta: float) -> void:
	if phase == "talk" and t >= 1.7 and _once("throw"):
		player.call("perform_action", "throw")
		sound.call("play", "throw", 1.0)
		mug.freeze = true
		mug.collision_layer = 0
		mug.collision_mask = 0
		mug_from = mug.global_position
		mug_to = _head_point() + Vector3(0.16, -0.12, 0)
		_set_phase("mug")
	elif phase == "mug":
		var flight: float = 0.34
		var u: float = minf(phase_t / flight, 1.0)
		mug.global_position = mug_from.lerp(mug_to, u) + Vector3.UP * sin(u * PI) * 0.22
		mug.rotation = Vector3(u * 9.0, u * 3.0, -u * 6.0)
		if u >= 1.0:
			caption_panel.visible = false
			actor.set("state", "stunned")
			_hit(mug_to, 0.9)
			# The real prop takes the hit: it breaks and drops with real physics.
			mug.freeze = false
			mug.call("set_held", false)
			mug.call("receive_hit", Vector3(2.0, 2.5, 0.3), mug_to, 40.0)
			mug.linear_velocity = Vector3(2.4, 2.6, 0.6)
			if is_instance_valid(cup):
				var keep: Transform3D = cup.global_transform
				cup.get_parent().remove_child(cup)
				root.add_child(cup)
				cup.global_transform = keep
				cup_velocity = Vector3(-0.95, 7.4, 0.05)
				cup_spin = Vector3(7.0, 2.0, 5.0)
			var flight_b: float = 0.95
			velocity = Vector3(-1.0 / flight_b, 0.5 * GRAVITY * flight_b, 0)
			spin_rate = TAU / flight_b
			_set_phase("backflip")
	elif phase == "backflip":
		center += velocity * delta
		velocity.y -= GRAVITY * delta
		tilt = minf(tilt + spin_rate * delta, TAU)
		if center.y <= PIVOT and velocity.y < 0.0:
			center.y = PIVOT
			tilt = 0.0
			squash = 0.2
			squash_anchor = 0.0
			sound.call("play", "impact", 0.8)
			_puff(Vector3(center.x, 0.05, LANE_Z), 6, 0.8)
			_spawn_stars()
			_set_phase("wobble")
	elif phase == "wobble":
		tilt = sin(phase_t * 9.0) * 0.12 * (1.0 + phase_t)
		plank_foot_x = center.x
		if phase_t > 1.3:
			_set_phase("timber")
	elif phase == "timber":
		# Pivot at the feet: a stiff plank falling face-first toward the camera.
		var angle: float = minf(0.5 * 13.0 * phase_t * phase_t, PI * 0.5)
		tilt = -angle
		center = Vector3(plank_foot_x + sin(angle) * PIVOT, cos(angle) * PIVOT + sin(angle) * 0.22, LANE_Z)
		if angle >= PI * 0.5:
			center.y = 0.22
			squash = 0.25
			squash_anchor = PIVOT
			bounce_v = 1.4
			_hit(center, 0.8, "slam")
			_set_phase("settle")
	elif phase == "settle":
		_bounce(delta, 0.22)
		if bounce_v <= 0.0:
			_set_phase("rest")
	elif phase == "rest":
		_rest(delta)
	# The flying coffee cup.
	if is_instance_valid(cup) and cup.get_parent() == root:
		cup.global_position += cup_velocity * delta
		cup_velocity.y -= GRAVITY * delta
		cup.rotation += cup_spin * delta
		var head_top: Vector3 = _head_point() + Vector3(0, 0.16, 0)
		if not events.has("bonk") and cup_velocity.y < 0.0 and cup.global_position.y <= head_top.y and phase == "wobble":
			events["bonk"] = true
			cup.global_position.y = head_top.y
			cup_velocity = Vector3(1.6, 2.4, 0.4)
			cup_spin = Vector3(-9.0, 3.0, 6.0)
			sound.call("play", "score", 1.4)
			_puff(head_top, 4, 0.35)
			_set_phase("timber")
		if cup.global_position.y < 0.06:
			cup.global_position.y = 0.06
			cup_velocity = Vector3.ZERO
			cup_spin = Vector3.ZERO
			cup.rotation = Vector3(PI * 0.5, 0.4, 0)

func _fall_to_back(delta: float, rest_height: float) -> void:
	center += velocity * delta
	velocity.y -= GRAVITY * delta
	velocity.x = move_toward(velocity.x, 0.0, delta * 1.5)
	if center.y <= rest_height:
		center.y = rest_height
		velocity = Vector3.ZERO
		bounce_v = 1.6
		squash = 0.25
		squash_anchor = PIVOT
		_hit(center, 0.75, "slam")
		_spawn_stars()
		_set_phase("settle_any")
	if phase == "settle_any":
		pass

func _bounce(delta: float, rest_height: float) -> void:
	if bounce_v <= 0.0:
		return
	center.y += bounce_v * delta
	bounce_v -= GRAVITY * delta
	if center.y <= rest_height:
		center.y = rest_height
		bounces += 1
		bounce_v = 0.0 if bounces >= 2 else 1.2 / float(bounces + 1)
		sound.call("play", "impact", 0.5)
		if bounces == 1 and stars.is_empty():
			_spawn_stars()

func _rest(_delta: float) -> void:
	pass

# --- Body placement and comic pose ----------------------------------------

func _orientation() -> Basis:
	# World-space tumble (about Z, backwards for a victim facing +X), then yaw spin.
	return Basis(Vector3.UP, spin) * Basis(Vector3.BACK, tilt) * Basis(Vector3.UP, actor_yaw)

func _place() -> void:
	var basis: Basis = _orientation()
	actor.global_transform = Transform3D(basis, center - basis * Vector3(0, PIVOT, 0))

func _head_point() -> Vector3:
	return (actor.get("_head") as Node3D).global_position

func _pose_actor(delta: float) -> void:
	if phase == "settle_any":
		_bounce(delta, 0.30)
		if bounce_v <= 0.0:
			_set_phase("rest")
	actor.set("_clock", float(actor.get("_clock")) + delta)
	if shot == 0 and phase == "talk":
		actor.set("_lecture_age", float(actor.get("_lecture_age")) + delta)
	actor.call("_animate_pose", maxf(delta, 0.0001), 0.0)
	_place()
	var visual: Node3D = actor.get("_visual") as Node3D
	squash = move_toward(squash, 0.0, delta * 1.1)
	var wobble: float = sin(timer_total * 38.0) * squash * 0.35
	var s: float = squash + wobble
	visual.scale = Vector3(1.0 + s * 0.55, 1.0 - s, 1.0 + s * 0.55)
	visual.position = Vector3(0, squash_anchor * s, 0)
	visual.rotation = Vector3.ZERO
	if phase == "talk" or phase == "mug":
		return
	# Flailing while airborne, splayed starfish once down.
	var left_arm: Node3D = actor.get("_left_arm") as Node3D
	var right_arm: Node3D = actor.get("_right_arm") as Node3D
	var left_leg: Node3D = actor.get("_left_leg") as Node3D
	var right_leg: Node3D = actor.get("_right_leg") as Node3D
	var airborne: bool = phase in ["fly", "stuck", "drop", "backflip", "breakdance"]
	var rate: float = 26.0 if airborne else 3.0
	var amount: float = 1.0 if airborne else 0.12
	var a: float = timer_total * rate
	left_arm.rotation = Vector3(sin(a) * 0.9 * amount - 0.2, 0, -1.75 - sin(a * 1.3) * 0.5 * amount)
	right_arm.rotation = Vector3(-sin(a + 1.4) * 0.9 * amount - 0.2, 0, 1.75 + sin(a * 1.1 + 0.6) * 0.5 * amount)
	(actor.get("_left_elbow") as Node3D).rotation.x = -0.5 - absf(sin(a * 0.8)) * 0.8 * amount
	(actor.get("_right_elbow") as Node3D).rotation.x = -0.5 - absf(sin(a * 0.9 + 1.0)) * 0.8 * amount
	var twitch: float = 0.0
	if phase == "rest":
		twitch = maxf(sin(timer_total * 2.2), 0.0) * 0.5
	left_leg.rotation = Vector3(sin(a * 0.9) * 0.7 * amount - 0.15, 0, -0.38)
	right_leg.rotation = Vector3(-sin(a * 0.9) * 0.7 * amount - 0.15 - twitch, 0, 0.38)
	(actor.get("_left_knee") as Node3D).rotation.x = 0.25 + absf(sin(a)) * 0.6 * amount
	(actor.get("_right_knee") as Node3D).rotation.x = 0.25 + absf(sin(a + 2.0)) * 0.6 * amount + twitch
	var head: Node3D = actor.get("_head") as Node3D
	head.rotation = Vector3(sin(a * 0.7) * 0.25 * amount, sin(a * 0.5) * 0.3 * amount, sin(timer_total * 4.0) * 0.12)
	if is_instance_valid(cup) and cup.get_parent() != root and shot == 2:
		cup.visible = true

# --- Camera ---------------------------------------------------------------------

func _update_camera(delta: float) -> void:
	if not is_instance_valid(actor):
		return
	var goal: Vector3 = center + Vector3(0, 0.25 if phase == "talk" else 0.0, 0)
	if phase == "talk":
		goal = center + Vector3(0, 0.35, 0)
	look_target = look_target.lerp(goal, minf(delta * 7.0, 1.0))
	var camera: Camera3D = player.get("camera") as Camera3D
	var to: Vector3 = look_target - camera.global_position
	var flat: float = Vector2(to.x, to.z).length()
	player.rotation.y = lerp_angle(player.rotation.y, atan2(-to.x, -to.z), minf(delta * 6.0, 1.0))
	player.set("_pitch", lerpf(float(player.get("_pitch")), clampf(atan2(to.y, flat), -0.5, 0.25), minf(delta * 6.0, 1.0)))

# --- Comic effects ------------------------------------------------------------

func _unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _puff(at: Vector3, count: int, power: float) -> void:
	for index: int in range(count):
		var node: MeshInstance3D = MeshInstance3D.new()
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		mesh.radial_segments = 10
		mesh.rings = 5
		node.mesh = mesh
		node.material_override = _unshaded(Color(1, 0.98, 0.92, 0.9))
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
		node.global_position = at
		var direction: Vector3 = Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 1), rng.randf_range(-1, 1)).normalized()
		puffs.append({"node": node, "velocity": direction * rng.randf_range(1.2, 2.6) * power, "age": 0.0, "life": rng.randf_range(0.28, 0.45), "size": rng.randf_range(0.05, 0.11) * power})

func _update_puffs(delta: float) -> void:
	for index: int in range(puffs.size() - 1, -1, -1):
		var puff: Dictionary = puffs[index]
		var node: MeshInstance3D = puff["node"]
		puff["age"] = float(puff["age"]) + delta
		var u: float = float(puff["age"]) / float(puff["life"])
		if u >= 1.0:
			node.queue_free()
			puffs.remove_at(index)
			continue
		node.global_position += (puff["velocity"] as Vector3) * delta * (1.0 - u)
		node.scale = Vector3.ONE * float(puff["size"]) * (0.6 + u * 1.2)
		(node.material_override as StandardMaterial3D).albedo_color.a = 0.9 * (1.0 - u)

func _star_mesh() -> ArrayMesh:
	var points: PackedVector3Array = PackedVector3Array()
	for index: int in range(10):
		var angle: float = PI * 0.5 + float(index) * TAU / 10.0
		var radius: float = 0.075 if index % 2 == 0 else 0.032
		points.append(Vector3(cos(angle) * radius, sin(angle) * radius, 0))
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(10):
		surface.add_vertex(Vector3.ZERO)
		surface.add_vertex(points[index])
		surface.add_vertex(points[(index + 1) % 10])
	return surface.commit()

func _spawn_stars() -> void:
	if not stars.is_empty():
		return
	var mesh: ArrayMesh = _star_mesh()
	for index: int in range(4):
		var node: MeshInstance3D = MeshInstance3D.new()
		node.mesh = mesh
		var material: StandardMaterial3D = _unshaded(Color("f6cf4e"))
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
		stars.append(node)

func _update_stars(_delta: float) -> void:
	if stars.is_empty() or not is_instance_valid(actor):
		return
	var head: Vector3 = _head_point()
	var upright: float = maxf((actor.get("_head") as Node3D).global_basis.y.normalized().dot(Vector3.UP), 0.0)
	var ring_center: Vector3 = head + Vector3.UP * lerpf(0.3, 0.46, upright)
	for index: int in range(stars.size()):
		var angle: float = timer_total * 4.2 + float(index) * TAU / float(stars.size())
		stars[index].global_position = ring_center + Vector3(cos(angle) * 0.3, sin(angle * 2.0) * 0.03, sin(angle) * 0.3)
		stars[index].scale = Vector3.ONE * (1.0 + sin(timer_total * 9.0 + index) * 0.15)
