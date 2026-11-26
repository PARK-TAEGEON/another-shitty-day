extends CharacterBody3D
## Procedural caricature study: articulated poses, readable eyes, and a single-body fall.
## This is an in-engine first pass, not the finished sculpted/rigged character asset.
signal scored(kind: String, points: int, at: Vector3)
signal said(text: String)
signal player_hit(damage: float)
signal noise(at: Vector3, strength: float)
signal damage_assessed(category: String, total: int, label: String)
signal incident(kind: String, weight: float, at: Vector3)

var display_name: String = "Coworker"
var role: String = "observer"
# Adult cast identity, independent of work, personality and reaction behavior.
# 이 사원 (rude junior) and 정 인턴 are the two women in the core department.
var character_gender: String = "male"
@export var affiliation: String = "department"
@export var personality: String = ""
@export var work_activity: String = "idle"
@export var work_line: String = ""
@export var reaction_line: String = ""
var suit_color: Color = Color("427c7a")
var skin_color: Color = Color("dca881")
var hair_color: Color = Color("393229")
var player_target: Node3D
var navigation_provider: Callable
const OFFICE_FLIGHT_BOUNDS: Array[Rect2] = [
	Rect2(-7.995, -9.995, 15.99, 17.99),
	Rect2(-1.51, 7.995, 3.02, 2.055),
]
const OFFICE_FLEE_POINTS: Array[Vector2] = [
	Vector2(-6.2, 5.5), Vector2(6.2, 5.5), Vector2(-6.2, -6.2), Vector2(6.2, -6.2),
]
var flight_bounds: Array[Rect2] = OFFICE_FLIGHT_BOUNDS
var flee_points: Array[Vector2] = OFFICE_FLEE_POINTS
var floor_height: float = 0.0
var response_exit: Vector3 = Vector3.INF
var state: String = "idle"
var health: float = 40.0
# The world owns cue timing/dialogue. Assign opening_role before add_child().
var opening_role: String = ""
var opening_phase: String = "work"
var opening_cancelled: bool = false
# Dialogue scheduling belongs to the world; this is only the current pose cue.
var boss_lecture_gesture: String = ""
var opening_visual_height: float:
	get:
		return _visual.position.y if is_instance_valid(_visual) else 0.0
var opening_head_top: float:
	get:
		return global_position.y + _pose_height + _head_drop + _standing_height

var _visual: Node3D
var _rig_adapter: Node3D
@export var use_kim_rig: bool = false
var _upper_body: Node3D
var _head: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_elbow: Node3D
var _right_elbow: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_knee: Node3D
var _right_knee: Node3D
var _left_ankle: Node3D
var _right_ankle: Node3D
var _tie: Node3D
var _mouth: Node3D
var _lower_lip: Node3D
var _eyes: Array[Node3D] = []
var _pupils: Array[Node3D] = []
var _brows: Array[Node3D] = []
var _upper_lids: Array[Node3D] = []
var _lower_lids: Array[Node3D] = []
var _face_eye_y: float = 0.04
var _face_eye_height: float = 0.10
var _face_brow_bias: float = 0.0
var _face_brow_z: float = 0.17
var _collision: CollisionShape3D
var _capsule: CapsuleShape3D
var _materials: Dictionary = {}
var _clock: float = 0.0
var _cooldown: float = 1.5
var _home: Vector3
var _reaction_spoken: bool = false
var _fall_side: float = 1.0
var _down_rotation: float = 0.0
var _path: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _path_target: Vector3 = Vector3.INF
var _repath_time: float = 0.0
var _cue_age: float = 0.0
var _pose_height: float = 0.0
var _head_drop: float = 0.0
var _head_base: Vector3
var _eye_open: float = 0.48
var _mouth_open: float = 0.12
var _standing_height: float = 2.18
var _hip_height: float = 0.78
var _broad: bool = false
var _thin: bool = false
var _arrived: bool = false
var _lecture_pose: String = ""
var _lecture_age: float = 0.0
var _lecture_duration: float = 0.0
var _lecture_blend: float = 0.0
var _lecture_wrists: Array[Node3D] = []
var _lecture_fingers: Array[Node3D] = []
var _rest_hands: Array[Node3D] = []
var _work_prop: Node3D
var _work_interrupted: bool = false
var _work_line_spoken: bool = false
var _talk_time: float = 0.0
var _reaction_pending: bool = false
var _reaction_delay: float = 0.0
var _pending_target: Vector3 = Vector3.ZERO
var _pending_intensity: float = 0.0
var _reaction_target: Vector3 = Vector3.ZERO
var _reaction_intensity: float = 0.0
var _reaction_age: float = 0.0
var _freeze_time: float = 0.0
var _after_freeze: String = "concern"
var _flee_destination: Vector3 = Vector3.INF
var _guard_warning_spoken: bool = false
var _guard_push_active: bool = false
var _guard_push_age: float = 0.0
var _guard_push_contact: bool = false
var _guard_palm_blend: float = 0.0
# The short-legged boss needs a brisk cadence, with each cycle advanced by real
# post-collision travel. A blocked character must not keep marching in place.
const BOSS_APPROACH_SPEED: float = 1.95
const BOSS_CYCLE_DISTANCE: float = 1.10
const BOSS_STANCE_FRACTION: float = 0.54
const BOSS_STEP_REACH: float = BOSS_CYCLE_DISTANCE * BOSS_STANCE_FRACTION * 0.5
const THIGH_LENGTH: float = 0.36
const SHIN_LENGTH: float = 0.31
var _walk_speed: float = 0.0
var _walk_distance: float = 0.0
var _walk_phase: float = BOSS_STANCE_FRACTION * 0.5
var _walk_blend: float = 0.0
var _walk_pelvis_offset: float = 0.0
var _walk_previous_yaw: float = 0.0
var _gait_initialized: bool = false
var _foot_positions: Array[Vector3] = []
var _foot_swing_origins: Array[Vector3] = []
var _foot_swing_start_phases: Array[float] = []
var _foot_yaws: Array[float] = []
var _foot_swing_yaws: Array[float] = []
var _foot_planted: Array[bool] = []
const HitFeelScript = preload("res://scripts/hit_feel.gd")
var _last_player_strike_msec: int = -1000000
var _launch_time: float = 0.0
var _launch_airborne: bool = false
var _launch_bounced: bool = false
var _flight_active: bool = false
var _flight_elapsed: float = 0.0
var _flight_origin: Vector3 = Vector3.ZERO
var _flight_dir: Vector3 = Vector3.FORWARD
var _flight_distance: float = 4.5
var _flight_peak: float = 1.45
var _flight_duration: float = 0.70
var _flight_saved_mask: int = 15
var _clamp_flight_to_room: bool = false
var impact_thuds: int = 0
var _thud_audio: AudioStreamPlayer3D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 15
	floor_snap_length = 0.3
	_home = global_position
	_broad = role == "boss"
	_thin = opening_role == "coworker"
	character_gender = "female" if affiliation == "department" and personality in ["rude", "intern"] and not _broad and not _thin and not _is_responder() else "male"
	if _broad:
		suit_color = Color("e7dfcd")
		skin_color = Color("cc9870")
		hair_color = Color("392f28")
	elif _thin:
		suit_color = Color("698f8d")
		skin_color = Color("d4a37b")
		hair_color = Color("382f2a")
	elif personality == "intern":
		skin_color = Color("d8ad89")
		hair_color = Color("453a32")
	elif personality == "dumping":
		hair_color = Color("686159")
	elif affiliation == "other" and personality == "fearful":
		hair_color = Color("463128")
	_visual = Node3D.new()
	_visual.name = "CaricatureVisual"
	add_child(_visual)
	_build_person()
	_collision = CollisionShape3D.new()
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.34 if _broad else 0.27
	_capsule.height = _standing_height
	_collision.shape = _capsule
	_collision.position.y = _standing_height * 0.5
	add_child(_collision)
	if opening_role == "boss":
		_pose_height = -0.58
		_head_drop = -0.24
	elif opening_role == "coworker":
		_pose_height = -0.24
	elif work_activity == "typing":
		_pose_height = -0.24
	_update_height_collision()
	_visual.position.y = _pose_height
	_head.position = _head_base + Vector3(0, _head_drop, 0)
	if _is_responder():
		affiliation = "security"
		state = "pursue"
		health = 65.0 if role == "police" else 48.0
	add_to_group("office_npc")
	# The explicit procedural model wins over both rig flags, including build settings.
	if _broad:
		var args := OS.get_cmdline_user_args()
		var explicit_rig := "--kim-rig" in args
		var v2 := "--kim-v2" in args or (not explicit_rig and bool(ProjectSettings.get_setting("asd/characters/kim_visual_v2_enabled", false)))
		var rig := use_kim_rig or explicit_rig or bool(ProjectSettings.get_setting("asd/characters/kim_rig_enabled", false))
		if not "--kim-legacy" in args:
			if v2 and _attach_kim_visual(true):
				return
			if rig and _attach_kim_visual(false):
				return
		print("KIM_VISUAL model=procedural motion=office_npc")
	elif opening_role == "coworker":
		var args := OS.get_cmdline_user_args()
		var park_v2 := "--park-v2" in args or bool(ProjectSettings.get_setting("asd/characters/park_visual_v2_enabled", false))
		if park_v2 and not "--park-legacy" in args:
			var adapter := preload("res://scripts/characters/park_visual_adapter.gd").new()
			if adapter.attach_to(self):
				return
			adapter.free()
		print("PARK_VISUAL model=procedural motion=office_npc")

func _attach_kim_visual(v2: bool) -> bool:
	_rig_adapter = load("res://scripts/characters/kim_visual_adapter.gd").new()
	_rig_adapter.name = "KimVisualAdapter"
	_rig_adapter.actor = self
	_rig_adapter.visual_v2 = v2
	add_child(_rig_adapter)
	if _rig_adapter.simulator == null:
		remove_child(_rig_adapter)
		_rig_adapter.queue_free()
		_rig_adapter = null
		return false
	_visual.hide()
	_rig_adapter.update_pose(0.0)
	return true

func _is_responder() -> bool:
	return affiliation == "security" or role in ["guard", "police"]

func is_working() -> bool:
	if _is_responder() or _work_interrupted or state in ["down", "flee", "pursue"]:
		return false
	if opening_role != "" and not opening_cancelled:
		return opening_phase in ["work", "listen"]
	return state == "idle" and work_activity != "idle"

func interrupt_work() -> void:
	# The world calls this at the visible interruption of the authored opening.
	# Accounting must not change the boss's seated/listening pose or cue timing.
	if not is_working():
		return
	_work_interrupted = true
	_talk_time = 0.0
	damage_assessed.emit("work", 10000, "%s 업무 중단" % display_name)

func speak_work_line() -> bool:
	if affiliation != "department" or work_line.is_empty() or _work_line_spoken or not is_working() or _reaction_pending:
		return false
	_work_line_spoken = true
	_talk_time = 2.5
	said.emit("%s  |  %s" % [display_name, work_line])
	return true

func _mat(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.metallic_specular = 0.06
	_materials[key] = mat
	return mat

func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _mat(color)
	node.position = at
	parent.add_child(node)
	return node

func _sphere(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 6
	node.mesh = mesh
	node.material_override = _mat(color)
	node.scale = size
	node.position = at
	parent.add_child(node)
	return node

func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Godot renders clockwise front faces, so this order gives outward normals.
	var normal: Vector3 = (c - a).cross(b - a).normalized()
	for point: Vector3 in [a, b, c]:
		surface.set_normal(normal)
		surface.add_vertex(point)

func _form(parent: Node3D, rings: Array[Vector3], at: Vector3, color: Color, forward_offsets: PackedFloat32Array = PackedFloat32Array()) -> MeshInstance3D:
	# Each ring is (width, height, depth). Eight-sided rings retain broad flat planes.
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[PackedVector3Array] = []
	for ring_index: int in range(rings.size()):
		var ring: Vector3 = rings[ring_index]
		var x: float = ring.x * 0.5
		var z: float = ring.z * 0.5
		var forward: float = forward_offsets[ring_index] if forward_offsets.size() == rings.size() else 0.0
		points.append(PackedVector3Array([
			Vector3(-x * 0.65, ring.y, z + forward), Vector3(x * 0.65, ring.y, z + forward),
			Vector3(x, ring.y, z * 0.65 + forward), Vector3(x, ring.y, -z * 0.65 + forward),
			Vector3(x * 0.65, ring.y, -z + forward), Vector3(-x * 0.65, ring.y, -z + forward),
			Vector3(-x, ring.y, -z * 0.65 + forward), Vector3(-x, ring.y, z * 0.65 + forward)
		]))
	for band: int in range(points.size() - 1):
		for edge: int in range(8):
			var next: int = (edge + 1) % 8
			_triangle(surface, points[band][edge], points[band + 1][edge], points[band + 1][next])
			_triangle(surface, points[band][edge], points[band + 1][next], points[band][next])
	for edge: int in range(8):
		var next: int = (edge + 1) % 8
		_triangle(surface, Vector3(0, rings[0].y, forward_offsets[0] if forward_offsets.size() == rings.size() else 0.0), points[0][edge], points[0][next])
		_triangle(surface, Vector3(0, rings[-1].y, forward_offsets[-1] if forward_offsets.size() == rings.size() else 0.0), points[-1][next], points[-1][edge])
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = surface.commit()
	node.material_override = _mat(color)
	node.position = at
	parent.add_child(node)
	return node

func _chunk(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	return _form(parent, [
		Vector3(size.x * 0.78, -size.y * 0.5, size.z * 0.78),
		Vector3(size.x, -size.y * 0.28, size.z),
		Vector3(size.x, size.y * 0.30, size.z),
		Vector3(size.x * 0.78, size.y * 0.5, size.z * 0.78)
	], at, color)

func _panel(parent: Node3D, outline: PackedVector2Array, at: Vector3, color: Color, depth: float = 0.008) -> MeshInstance3D:
	# Thin, closed polygon shapes sit on the face or cloth. Eyes and collars use
	# broad matte planes instead of detached spheres and thick rectangular blocks.
	var points: PackedVector2Array = outline.duplicate()
	if Geometry2D.is_polygon_clockwise(points):
		points.reverse()
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(points)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(0, indices.size(), 3):
		var a: Vector2 = points[indices[index]]
		var b: Vector2 = points[indices[index + 1]]
		var c: Vector2 = points[indices[index + 2]]
		_triangle(surface, Vector3(a.x, a.y, depth * 0.5), Vector3(c.x, c.y, depth * 0.5), Vector3(b.x, b.y, depth * 0.5))
		_triangle(surface, Vector3(a.x, a.y, -depth * 0.5), Vector3(b.x, b.y, -depth * 0.5), Vector3(c.x, c.y, -depth * 0.5))
	for index: int in range(points.size()):
		var a: Vector2 = points[index]
		var b: Vector2 = points[(index + 1) % points.size()]
		_triangle(surface, Vector3(a.x, a.y, depth * 0.5), Vector3(b.x, b.y, depth * 0.5), Vector3(b.x, b.y, -depth * 0.5))
		_triangle(surface, Vector3(a.x, a.y, depth * 0.5), Vector3(b.x, b.y, -depth * 0.5), Vector3(a.x, a.y, -depth * 0.5))
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = surface.commit()
	node.material_override = _mat(color)
	node.position = at
	parent.add_child(node)
	return node

func _oval(parent: Node3D, size: Vector2, at: Vector3, color: Color, depth: float = 0.004) -> MeshInstance3D:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(12):
		var angle: float = float(index) * TAU / 12.0
		points.append(Vector2(cos(angle) * size.x * 0.5, sin(angle) * size.y * 0.5))
	var node: MeshInstance3D = _panel(parent, points, at, color, depth)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _cloth_seam(parent: Node3D, from: Vector3, to: Vector3, width: float, color: Color) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge: Vector3 = Vector3(width * 0.5, 0, 0)
	_triangle(surface, from - edge, from + edge, to + edge)
	_triangle(surface, from - edge, to + edge, to - edge)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = surface.commit()
	node.material_override = _mat(color)
	parent.add_child(node)

func _make_arm(side: float) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.position = Vector3(side * (0.48 if _broad else (0.255 if _thin else (0.295 if personality == "intern" else 0.34))), 1.43 if _broad else 1.38, 0)
	_visual.add_child(pivot)
	var width: float = 0.235 if _broad else (0.13 if _thin else 0.17)
	var cardigan: bool = not _broad and not _thin and personality in ["rude", "dumping"]
	_chunk(pivot, Vector3(width, 0.31, width * 1.02), Vector3(0, -0.13, 0), suit_color)
	if not cardigan:
		_chunk(pivot, Vector3(width * 1.09, 0.062, width * 1.07), Vector3(0, -0.263, 0), suit_color.lightened(0.12))
		_box(pivot, Vector3(width * 0.80, 0.008, 0.004), Vector3(0, -0.247, width * 0.55), suit_color.darkened(0.18))
	var elbow: Node3D = Node3D.new()
	elbow.position.y = -0.285
	pivot.add_child(elbow)
	_chunk(elbow, Vector3(width * (0.85 if cardigan else 0.77), 0.28, width * (0.83 if cardigan else 0.75)), Vector3(0, -0.125, 0), suit_color if cardigan else skin_color)
	if cardigan:
		_chunk(elbow, Vector3(width * 0.90, 0.048, width * 0.87), Vector3(0, -0.243, 0), suit_color.darkened(0.13))
		_chunk(elbow, Vector3(width * 0.77, 0.025, width * 0.75), Vector3(0, -0.266, 0), Color("e4ddc9"))
	var hand: Node3D = _chunk(elbow, Vector3(width * 0.93, 0.145, width * 0.90), Vector3(0, -0.295, 0.009), skin_color.lightened(0.02))
	var thumb: Node3D = _chunk(elbow, Vector3(width * 0.30, 0.092, width * 0.44), Vector3(-side * width * 0.43, -0.27, 0.025), skin_color)
	if _broad or _is_responder():
		_rest_hands.append(hand)
		_rest_hands.append(thumb)
		_make_lecture_hand(elbow, side)
	if side < 0.0:
		_left_elbow = elbow
	else:
		_right_elbow = elbow
	return pivot

func _make_lecture_hand(elbow: Node3D, side: float) -> void:
	# Keep the approved resting/walking fists. A separate articulated palm is
	# exposed as the raised hand opens, with real finger silhouettes for pointing.
	var wrist: Node3D = Node3D.new()
	wrist.name = "LectureLeftHand" if side < 0.0 else "LectureRightHand"
	wrist.position = Vector3(0, -0.237, 0.009)
	wrist.visible = false
	elbow.add_child(wrist)
	_lecture_wrists.append(wrist)
	_chunk(wrist, Vector3(0.183, 0.123, 0.073), Vector3(0, -0.055, 0), skin_color.lightened(0.02))
	for index: int in range(4):
		# Index is nearest the inward-facing thumb on both anatomical hands.
		var finger: Node3D = Node3D.new()
		finger.position = Vector3(-side * (0.063 - float(index) * 0.042), -0.106, 0)
		finger.rotation.z = side * (float(index) - 1.5) * 0.045
		wrist.add_child(finger)
		var length: float = [0.111, 0.125, 0.113, 0.087][index]
		_chunk(finger, Vector3(0.033, length, 0.044), Vector3(0, -length * 0.45, 0.002), skin_color)
		_lecture_fingers.append(finger)
	var thumb: Node3D = _chunk(wrist, Vector3(0.060, 0.103, 0.059), Vector3(-side * 0.108, -0.042, 0.022), skin_color)
	thumb.rotation.z = -side * 0.62

func _make_leg(side: float, trouser: Color) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.position = Vector3(side * (0.20 if _broad else 0.125), _hip_height, 0)
	_visual.add_child(pivot)
	var width: float = 0.27 if _broad else (0.15 if _thin else 0.19)
	_chunk(pivot, Vector3(width, 0.38, width * 1.08), Vector3(0, -0.17, 0), trouser)
	var knee: Node3D = Node3D.new()
	knee.position.y = -0.36
	pivot.add_child(knee)
	_chunk(knee, Vector3(width * 0.91, 0.33, width * 0.95), Vector3(0, -0.145, 0), trouser)
	# Same shoe mesh and rest position; the ankle can now keep its sole level
	# while the articulated knee bends during a step.
	var ankle: Node3D = Node3D.new()
	ankle.position.y = -SHIN_LENGTH
	knee.add_child(ankle)
	_chunk(ankle, Vector3(width * 1.07, 0.14, 0.36), Vector3(0, 0, 0.06), Color("303537"))
	if side < 0.0:
		_left_knee = knee
		_left_ankle = ankle
	else:
		_right_knee = knee
		_right_ankle = ankle
	return pivot

func _make_tie_tail(color: Color) -> void:
	# Follow the chest/belly instead of cutting a straight slab through the shirt.
	# Rows contain width, height below the knot, and forward offset from the knot.
	var rows: Array = [
		Vector3(0.082, -0.045, 0.014), Vector3(0.10, -0.235, 0.064),
		Vector3(0.16, -0.440, 0.082), Vector3(0.004, -0.540, 0.033)
	] if _broad else [
		Vector3(0.052, -0.045, 0.010), Vector3(0.063, -0.250, 0.020),
		Vector3(0.096, -0.460, 0.025), Vector3(0.004, -0.540, 0.018)
	]
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band: int in range(rows.size() - 1):
		var top: Vector3 = rows[band]
		var bottom: Vector3 = rows[band + 1]
		var a: Vector3 = Vector3(-top.x * 0.5, top.y, top.z)
		var b: Vector3 = Vector3(top.x * 0.5, top.y, top.z)
		var c: Vector3 = Vector3(bottom.x * 0.5, bottom.y, bottom.z)
		var d: Vector3 = Vector3(-bottom.x * 0.5, bottom.y, bottom.z)
		_triangle(surface, a, b, c)
		_triangle(surface, a, c, d)
		var back: Vector3 = Vector3(0, 0, -0.014)
		_triangle(surface, a + back, c + back, b + back)
		_triangle(surface, a + back, d + back, c + back)
		_triangle(surface, a, d, d + back)
		_triangle(surface, a, d + back, a + back)
		_triangle(surface, b, b + back, c + back)
		_triangle(surface, b, c + back, c)
	var tail: MeshInstance3D = MeshInstance3D.new()
	tail.mesh = surface.commit()
	tail.material_override = _mat(color)
	_tie.add_child(tail)

func _build_outfit() -> void:
	var layered: bool = personality in ["rude", "dumping", "intern"] and not _thin and not _broad
	var shirt: Color = Color("e4ddc9") if layered else suit_color
	if layered:
		_form(_visual, [Vector3(0.005, 1.115, 0.007), Vector3(0.155, 1.31, 0.007), Vector3(0.25, 1.49, 0.007)], Vector3.ZERO, shirt, PackedFloat32Array([0.195, 0.177, 0.149] if personality == "dumping" else [0.156, 0.155, 0.149]))
		for side: float in [-1.0, 1.0]:
			_cloth_seam(_visual, Vector3(side * 0.143, 1.49, 0.159), Vector3(side * 0.025, 1.115, 0.170), 0.018, suit_color.darkened(0.23))
	# Thin collar leaves follow the slope of the chest. Their outlines have a
	# collar point and a folded edge, rather than a pair of detached solid blocks.
	for side: float in [-1.0, 1.0]:
		var collar_width: float = 0.116 if _broad else (0.071 if _thin else (0.068 if character_gender == "female" else 0.074))
		var collar_point: float = -0.092 if character_gender == "female" else -0.104
		var collar: Node3D = _panel(_visual, PackedVector2Array([
			Vector2(side * -collar_width * 0.66, 0.078), Vector2(side * collar_width * 0.62, 0.068),
			Vector2(side * collar_width, -0.042), Vector2(side * -collar_width * 0.11, collar_point)
		]), Vector3(side * (0.122 if _broad else 0.072), 1.435, 0.267 if _broad else 0.170), shirt.lightened(0.09), 0.014)
		collar.rotation.x = -0.32 if _broad else -0.12
		_cloth_seam(_visual, Vector3(side * (0.29 if _broad else 0.175), 1.385, 0.264 if _broad else 0.148), Vector3(side * (0.32 if _broad else 0.187), 1.285, 0.302 if _broad else 0.155), 0.012, suit_color.darkened(0.13))
	_tie = Node3D.new()
	_tie.position = Vector3(0, 1.405, 0.276 if _broad else 0.181)
	_visual.add_child(_tie)
	var tie_color: Color = Color("a77735") if _broad else Color("384548")
	_chunk(_tie, Vector3(0.107 if _broad else 0.065, 0.095, 0.029), Vector3.ZERO, tie_color)
	_make_tie_tail(tie_color)
	_tie.visible = not layered
	if _broad:
		var placket: Array[Vector3] = [Vector3(0.018, 1.43, 0.254), Vector3(0.018, 1.25, 0.299), Vector3(0.018, 1.10, 0.322), Vector3(0.018, 0.97, 0.301), Vector3(0.018, 0.88, 0.270)]
		for index: int in range(placket.size() - 1):
			_cloth_seam(_visual, placket[index], placket[index + 1], 0.030, suit_color.darkened(0.075))
		_panel(_visual, PackedVector2Array([Vector2(-0.080, 0.060), Vector2(-0.074, -0.057), Vector2(0, -0.077), Vector2(0.074, -0.057), Vector2(0.080, 0.060)]), Vector3(0.235, 1.292, 0.300), suit_color.darkened(0.055))
		_box(_visual, Vector3(0.151, 0.011, 0.007), Vector3(0.235, 1.348, 0.307), suit_color.darkened(0.19))
		for button: Vector3 in [Vector3(0.04, 1.265, 0.309), Vector3(0.04, 1.015, 0.317), Vector3(0.04, 0.899, 0.282)]:
			_oval(_visual, Vector2(0.019, 0.019), button, Color("b9af96"), 0.007)
	else:
		_cloth_seam(_visual, Vector3(0.009, 1.10 if layered else 1.38, 0.163), Vector3(0.009, 0.89, 0.151), 0.021, suit_color.darkened(0.10))
		for button_y: float in [1.23, 1.07, 0.925]:
			_oval(_visual, Vector2(0.017, 0.017), Vector3(0.012, button_y, 0.175 if personality == "dumping" else 0.163), Color("a8a18a") if personality == "dumping" else suit_color.darkened(0.35), 0.006)
		if personality == "dumping":
			for side: float in [-1.0, 1.0]:
				_box(_visual, Vector3(0.127, 0.021, 0.012), Vector3(side * 0.166, 0.99, 0.191), suit_color.darkened(0.22))
		elif personality == "intern":
			_panel(_visual, PackedVector2Array([Vector2(-0.046, 0.052), Vector2(-0.042, -0.042), Vector2(0, -0.055), Vector2(0.042, -0.042), Vector2(0.046, 0.052)]), Vector3(0.142, 1.282, 0.159), suit_color.darkened(0.09))
			_box(_visual, Vector3(0.010, 0.065, 0.009), Vector3(0.155, 1.329, 0.167), Color("415967"))

func _build_head_shape() -> void:
	if _broad:
		# A continuous jutting jaw is part of the head, not a second chin block.
		_form(_head, [Vector3(0.41, -0.29, 0.33), Vector3(0.64, -0.16, 0.43), Vector3(0.57, 0.005, 0.43), Vector3(0.51, 0.15, 0.38), Vector3(0.43, 0.25, 0.33)], Vector3.ZERO, skin_color, PackedFloat32Array([0.026, 0.023, 0, 0, -0.01]))
		_form(_head, [Vector3(0.105, -0.132, 0.045), Vector3(0.170, -0.083, 0.075), Vector3(0.115, 0.027, 0.058), Vector3(0.063, 0.145, 0.028)], Vector3(0, 0.018, 0.218), skin_color.lightened(0.04), PackedFloat32Array([0.053, 0.095, 0.055, 0]))
	elif _thin:
		_form(_head, [Vector3(0.205, -0.33, 0.23), Vector3(0.270, -0.22, 0.29), Vector3(0.31, -0.065, 0.285), Vector3(0.35, 0.17, 0.305), Vector3(0.285, 0.27, 0.26)], Vector3.ZERO, skin_color, PackedFloat32Array([0.020, 0.009, 0, 0, -0.006]))
		_form(_head, [Vector3(0.075, -0.168, 0.030), Vector3(0.105, -0.128, 0.060), Vector3(0.075, 0.020, 0.041), Vector3(0.047, 0.150, 0.023)], Vector3(0, 0.014, 0.148), skin_color.lightened(0.04), PackedFloat32Array([0.048, 0.088, 0.043, 0]))
	elif personality == "dumping":
		_form(_head, [Vector3(0.32, -0.23, 0.30), Vector3(0.49, -0.10, 0.38), Vector3(0.49, 0.055, 0.36), Vector3(0.41, 0.20, 0.31), Vector3(0.32, 0.25, 0.27)], Vector3.ZERO, skin_color, PackedFloat32Array([0.017, 0.008, 0, -0.010, -0.025]))
		_form(_head, [Vector3(0.112, -0.072, 0.035), Vector3(0.158, -0.042, 0.059), Vector3(0.110, 0.046, 0.047), Vector3(0.055, 0.095, 0.020)], Vector3(0, -0.006, 0.176), skin_color.lightened(0.025), PackedFloat32Array([0.023, 0.069, 0.020, 0]))
	elif personality == "intern":
		_form(_head, [Vector3(0.205, -0.248, 0.23), Vector3(0.30, -0.15, 0.29), Vector3(0.40, 0.025, 0.335), Vector3(0.425, 0.145, 0.33), Vector3(0.35, 0.245, 0.28)], Vector3.ZERO, skin_color, PackedFloat32Array([0.025, 0.011, 0, 0, -0.01]))
		_form(_head, [Vector3(0.066, -0.073, 0.028), Vector3(0.086, -0.033, 0.048), Vector3(0.052, 0.071, 0.025)], Vector3(0, 0.004, 0.169), skin_color.lightened(0.025), PackedFloat32Array([0.022, 0.052, 0]))
	elif personality == "rude":
		_form(_head, [Vector3(0.24, -0.24, 0.25), Vector3(0.32, -0.16, 0.305), Vector3(0.40, -0.015, 0.34), Vector3(0.405, 0.16, 0.32), Vector3(0.33, 0.245, 0.27)], Vector3.ZERO, skin_color, PackedFloat32Array([0.018, 0.007, 0, 0, -0.016]))
		_form(_head, [Vector3(0.074, -0.069, 0.028), Vector3(0.089, -0.030, 0.050), Vector3(0.050, 0.090, 0.025)], Vector3(0, -0.005, 0.169), skin_color.lightened(0.035), PackedFloat32Array([0.020, 0.049, 0]))
	else:
		_form(_head, [Vector3(0.28, -0.235, 0.26), Vector3(0.38, -0.08, 0.35), Vector3(0.39, 0.16, 0.33), Vector3(0.31, 0.235, 0.28)], Vector3.ZERO, skin_color)
		_form(_head, [Vector3(0.075, -0.082, 0.03), Vector3(0.11, -0.030, 0.055), Vector3(0.059, 0.092, 0.025)], Vector3(0, 0, 0.17), skin_color.lightened(0.04), PackedFloat32Array([0.025, 0.067, 0]))

func _build_person() -> void:
	var trouser: Color = Color("45423d") if _broad else Color("344148")
	if personality == "rude":
		trouser = Color("39433d")
	elif personality == "dumping":
		trouser = Color("414342")
	_hip_height = 0.78
	if _broad:
		_form(_visual, [Vector3(0.63, -0.40, 0.40), Vector3(0.92, -0.08, 0.59), Vector3(0.90, 0.20, 0.48), Vector3(0.64, 0.38, 0.35)], Vector3(0, 1.17, 0.025), suit_color)
	elif personality == "dumping":
		_form(_visual, [Vector3(0.45, -0.33, 0.29), Vector3(0.60, -0.10, 0.38), Vector3(0.61, 0.17, 0.32), Vector3(0.49, 0.31, 0.26)], Vector3(0, 1.16, 0), suit_color)
	else:
		var chest_width: float = 0.40 if _thin else (0.47 if personality == "intern" else (0.60 if personality == "dumping" else 0.55))
		_form(_visual, [Vector3(0.38 if _thin else 0.45, -0.33, 0.28), Vector3(chest_width, 0.19, 0.29), Vector3(chest_width * 0.875, 0.31, 0.26)], Vector3(0, 1.16, 0), suit_color)
	_chunk(_visual, Vector3(0.58 if _broad else 0.37, 0.21, 0.35 if _broad else 0.28), Vector3(0, 0.78, 0), trouser)
	_box(_visual, Vector3(0.64 if _broad else 0.38, 0.056, 0.34), Vector3(0, 0.85, 0.025), Color("393733"))
	_box(_visual, Vector3(0.095, 0.062, 0.027), Vector3(0.025, 0.852, 0.212), Color("b9b2a0"))
	_box(_visual, Vector3(0.055, 0.034, 0.032), Vector3(0.025, 0.852, 0.219), Color("393733"))
	_chunk(_visual, Vector3(0.24 if _broad else (0.108 if character_gender == "female" else 0.12), 0.23, 0.22 if _broad else 0.12), Vector3(0, 1.54, 0.012), skin_color)
	_build_outfit()
	_head = Node3D.new()
	_head.name = "ExpressiveHead"
	_head_base = Vector3(0, 1.78 if _broad else (1.80 if _thin else 1.70), 0.025)
	_head.position = _head_base
	_visual.add_child(_head)
	_build_head_shape()
	_build_face()
	_build_hair()
	for side: float in [-1.0, 1.0]:
		var ear: MeshInstance3D = _chunk(_head, Vector3(0.110 if _thin else (0.087 if character_gender == "female" else 0.105), 0.20 if _thin else (0.143 if character_gender == "female" else 0.155), 0.075), Vector3(side * (0.211 if _thin else (0.29 if _broad else (0.251 if personality == "dumping" else 0.211))), -0.005, -0.012), skin_color)
		ear.rotation.z = side * 0.17
		_panel(ear, PackedVector2Array([Vector2(-0.017, 0.040), Vector2(-0.024, -0.024), Vector2(0.011, -0.035), Vector2(0.020, 0.026)]), Vector3(0, 0.005, 0.040), skin_color.darkened(0.16), 0.005)
		if character_gender == "female":
			_oval(ear, Vector2(0.017, 0.017), Vector3(0, -0.050, 0.041), Color("b4a386"), 0.008)
	if role == "guard" or role == "police":
		_chunk(_head, Vector3(0.44, 0.13, 0.39), Vector3(0, 0.25, 0), suit_color.darkened(0.28))
		_box(_head, Vector3(0.36, 0.028, 0.18), Vector3(0, 0.196, 0.23), suit_color.darkened(0.46))
		_box(_visual, Vector3(0.08, 0.11, 0.025), Vector3(0.15, 1.28, 0.18), Color("e3bc6a"))
	_left_arm = _make_arm(-1.0)
	_right_arm = _make_arm(1.0)
	_build_work_accessories()
	_left_leg = _make_leg(-1.0, trouser)
	_right_leg = _make_leg(1.0, trouser)
	_standing_height = 2.20 if _broad else (2.19 if _thin else 2.02)
	if _broad:
		# The small conversational lean pivots above the hips. Legs stay on the
		# original visual root, leaving the approved foot planting and gait intact.
		_upper_body = Node3D.new()
		_upper_body.name = "LectureUpperBody"
		var body_parts: Array[Node] = _visual.get_children()
		_visual.add_child(_upper_body)
		for part: Node in body_parts:
			if part != _left_leg and part != _right_leg:
				part.reparent(_upper_body, false)

func _build_work_accessories() -> void:
	# The trainee is an adult office worker. Her orange pass and document board
	# retain the same attachment points and authored paper-reading movement.
	if personality == "intern" or affiliation == "other":
		var pass_color: Color = Color("d47b39") if personality == "intern" else Color("486773")
		for side: float in [-1.0, 1.0]:
			var strap: Node3D = _box(_visual, Vector3(0.022, 0.34, 0.014), Vector3(side * 0.060, 1.29, 0.180), pass_color)
			strap.rotation.z = side * -0.31
		var badge: Node3D = _chunk(_visual, Vector3(0.14, 0.19, 0.028), Vector3(0, 1.105, 0.187), Color("efe9d9"))
		_box(badge, Vector3(0.12, 0.045, 0.012), Vector3(0, 0.053, 0.021), pass_color)
		_box(badge, Vector3(0.046, 0.061, 0.011), Vector3(-0.026, -0.016, 0.021), suit_color.darkened(0.1))
		_box(badge, Vector3(0.042, 0.013, 0.011), Vector3(0.032, -0.002, 0.021), Color("807f73"))
		_box(badge, Vector3(0.042, 0.010, 0.011), Vector3(0.032, -0.028, 0.021), Color("807f73"))
		if personality == "intern":
			_tie.visible = false
	if opening_role != "" or _is_responder():
		return
	if work_activity in ["papers", "copy"]:
		_work_prop = Node3D.new()
		_work_prop.name = "WorkingDocument"
		_left_elbow.add_child(_work_prop)
		_work_prop.position = Vector3(0, -0.285, 0.095)
		_work_prop.rotation = Vector3(-0.42, 0, -0.10)
		_box(_work_prop, Vector3(0.255, 0.335, 0.032), Vector3.ZERO, Color("716355"))
		_box(_work_prop, Vector3(0.225, 0.302, 0.009), Vector3(0, -0.002, 0.022), Color("ede8db"))
		for line_index: int in range(5):
			_box(_work_prop, Vector3(0.155 - float(line_index % 2) * 0.035, 0.009, 0.004), Vector3(-0.009, 0.098 - float(line_index) * 0.038, 0.029), Color("8d9793"))
		_box(_work_prop, Vector3(0.071, 0.030, 0.016), Vector3(0, 0.158, 0.025), Color("9caaa8"))
	elif work_activity == "coffee":
		_work_prop = Node3D.new()
		_work_prop.name = "WorkingCoffee"
		_right_elbow.add_child(_work_prop)
		_work_prop.position = Vector3(0, -0.315, 0.045)
		var cup: MeshInstance3D = MeshInstance3D.new()
		var cup_mesh: CylinderMesh = CylinderMesh.new()
		cup_mesh.top_radius = 0.061
		cup_mesh.bottom_radius = 0.050
		cup_mesh.height = 0.14
		cup_mesh.radial_segments = 12
		cup.mesh = cup_mesh
		cup.material_override = _mat(Color("c9d8cb"))
		cup.position.y = 0.055
		_work_prop.add_child(cup)
		var coffee: MeshInstance3D = MeshInstance3D.new()
		var coffee_mesh: CylinderMesh = CylinderMesh.new()
		coffee_mesh.top_radius = 0.054
		coffee_mesh.bottom_radius = 0.054
		coffee_mesh.height = 0.004
		coffee_mesh.radial_segments = 12
		coffee.mesh = coffee_mesh
		coffee.material_override = _mat(Color("594738"))
		coffee.position.y = 0.126
		_work_prop.add_child(coffee)
		_box(_work_prop, Vector3(0.080, 0.022, 0.022), Vector3(0.068, 0.103, 0), Color("c9d8cb"))
		_box(_work_prop, Vector3(0.080, 0.022, 0.022), Vector3(0.068, 0.025, 0), Color("c9d8cb"))
		_box(_work_prop, Vector3(0.021, 0.09, 0.022), Vector3(0.098, 0.064, 0), Color("c9d8cb"))

func _build_face() -> void:
	var eye_x: float = 0.126 if _broad else (0.099 if _thin else (0.117 if personality == "dumping" else 0.092))
	_face_eye_y = 0.10 if _broad else (0.085 if _thin else (0.071 if personality == "intern" else 0.044))
	_face_eye_height = 0.108 if _broad else (0.140 if _thin else (0.095 if personality == "dumping" else 0.110))
	_face_brow_bias = 0.10 if personality == "rude" else (-0.13 if personality == "intern" or _thin else 0.0)
	_face_brow_z = 0.204 if _broad else (0.162 if _thin else (0.174 if personality == "dumping" else 0.172))
	var eye_z: float = 0.208 if _broad else (0.158 if _thin else (0.191 if personality == "dumping" else 0.173))
	var eye_width: float = 0.130 if _broad else (0.122 if _thin else (0.123 if personality == "dumping" else 0.112))
	for side: float in [-1.0, 1.0]:
		var eye: Node3D = Node3D.new()
		eye.position = Vector3(side * eye_x, _face_eye_y, eye_z)
		eye.rotation.y = side * 0.10
		_head.add_child(eye)
		_oval(eye, Vector2(eye_width, _face_eye_height), Vector3.ZERO, Color("e7e1cf"), 0.004)
		_eyes.append(eye)
		var pupil: Node3D = _oval(eye, Vector2(0.028 if _broad else 0.027, 0.033), Vector3(-side * 0.006, -0.001, 0.004), Color("30352f"), 0.003)
		_pupils.append(pupil)
		var lid: MeshInstance3D = _panel(_head, PackedVector2Array([Vector2(-eye_width * 0.51, -0.006), Vector2(-eye_width * 0.43, 0.004), Vector2(eye_width * 0.39, 0.005), Vector2(eye_width * 0.51, -0.006)]), Vector3(side * eye_x, _face_eye_y + 0.03, eye_z + 0.006), skin_color.darkened(0.19), 0.004)
		lid.rotation.y = eye.rotation.y
		lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_upper_lids.append(lid)
		var lower_lid: MeshInstance3D = _panel(_head, PackedVector2Array([Vector2(-eye_width * 0.42, 0.004), Vector2(-eye_width * 0.28, -0.002), Vector2(eye_width * 0.30, -0.002), Vector2(eye_width * 0.43, 0.005)]), Vector3(side * eye_x, _face_eye_y - 0.03, eye_z + 0.004), skin_color.darkened(0.10), 0.003)
		lower_lid.rotation.y = eye.rotation.y
		lower_lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_lower_lids.append(lower_lid)
		var brow_width: float = 0.165 if _broad else (0.142 if _thin else 0.129)
		var brow_height: float = 0.047 if _broad else (0.026 if personality == "dumping" else (0.023 if character_gender == "female" else 0.030))
		var brow: MeshInstance3D = _panel(_head, PackedVector2Array([Vector2(-brow_width * 0.50, -brow_height * 0.21), Vector2(-brow_width * 0.46, brow_height * 0.27), Vector2(-brow_width * 0.18, brow_height * 0.57), Vector2(brow_width * 0.46, brow_height * 0.24), Vector2(brow_width * 0.50, -brow_height * 0.12), Vector2(brow_width * 0.19, -brow_height * 0.39)]), Vector3(side * eye_x, _face_eye_y + 0.080, _face_brow_z), hair_color, 0.007)
		brow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_brows.append(brow)
		if _thin:
			# Open frames preserve the widening eye whites; no opaque tinted lenses.
			for frame_side: float in [-1.0, 1.0]:
				_box(_head, Vector3(0.012, 0.16, 0.013), Vector3(side * eye_x + frame_side * 0.077, _face_eye_y, eye_z + 0.027), Color("30332f"))
				_box(_head, Vector3(0.158, 0.014, 0.013), Vector3(side * eye_x, _face_eye_y + frame_side * 0.073, eye_z + 0.027), Color("30332f"))
			_box(_head, Vector3(0.013, 0.013, 0.20), Vector3(side * (eye_x + 0.078), _face_eye_y + 0.04, eye_z - 0.061), Color("30332f"))
	if _thin:
		_box(_head, Vector3(0.056, 0.018, 0.016), Vector3(0, _face_eye_y + 0.023, eye_z + 0.027), Color("30332f"))
	elif affiliation == "other" and personality == "spectator":
		# A wider, low brow frame gives the watching employee a different face
		# from the accepted long-faced colleague, without concealing the eyes.
		for side: float in [-1.0, 1.0]:
			for edge: float in [-1.0, 1.0]:
				_box(_head, Vector3(0.013, 0.131, 0.014), Vector3(side * eye_x + edge * 0.062, _face_eye_y, eye_z + 0.026), Color("5e4030"))
				_box(_head, Vector3(0.135, 0.014, 0.014), Vector3(side * eye_x, _face_eye_y + edge * 0.061, eye_z + 0.026), Color("5e4030"))
		_box(_head, Vector3(0.052, 0.015, 0.018), Vector3(0, _face_eye_y + 0.017, eye_z + 0.026), Color("5e4030"))
	_mouth = Node3D.new()
	_mouth.position = Vector3(0, -0.149 if _broad else (-0.216 if _thin else -0.130), 0.247 if _broad else (0.163 if _thin else (0.202 if personality == "dumping" else 0.172)))
	_head.add_child(_mouth)
	var mouth_width: float = 0.219 if _broad else (0.120 if _thin else (0.140 if personality == "dumping" else 0.112))
	_panel(_mouth, PackedVector2Array([Vector2(-mouth_width * 0.49, 0.016), Vector2(-mouth_width * 0.31, 0.043), Vector2(mouth_width * 0.35, 0.030), Vector2(mouth_width * 0.50, 0.003), Vector2(mouth_width * 0.33, -0.040), Vector2(-mouth_width * 0.28, -0.045)]), Vector3.ZERO, Color("614936"), 0.004)
	_mouth.rotation.z = -0.07 if personality == "intern" else (0.06 if personality == "rude" else 0.0)
	_lower_lip = _panel(_head, PackedVector2Array([Vector2(-mouth_width * 0.35, 0.008), Vector2(-mouth_width * 0.23, -0.005), Vector2(mouth_width * 0.25, -0.005), Vector2(mouth_width * 0.37, 0.007)]), _mouth.position + Vector3(0, -0.018, 0.001), skin_color.darkened(0.075), 0.003)

func _build_female_hair() -> void:
	# Only the two newly assigned adult women use these silhouettes. Hair follows
	# the existing head pivot; there is no new body rig, hair physics or collider.
	var hair: Node3D = Node3D.new()
	hair.name = "JuniorAsymmetricBob" if personality == "rude" else "InternTiedHair"
	_head.add_child(hair)
	if personality == "rude":
		# A chin-length bob is fuller on the left. The right side is tucked back,
		# leaving the ear and the angular cheek visible from an office aisle.
		_form(hair, [Vector3(0.37, -0.225, 0.22), Vector3(0.46, -0.14, 0.26), Vector3(0.47, 0.16, 0.31), Vector3(0.35, 0.28, 0.26)], Vector3(0, 0, -0.10), hair_color)
		_form(hair, [Vector3(0.40, -0.025, 0.31), Vector3(0.46, 0.070, 0.34), Vector3(0.34, 0.115, 0.27)], Vector3(0, 0.22, -0.037), hair_color)
		_form(hair, [Vector3(0.092, -0.218, 0.17), Vector3(0.135, -0.13, 0.27), Vector3(0.120, 0.13, 0.27), Vector3(0.100, 0.225, 0.20)], Vector3(-0.218, -0.007, -0.020), hair_color)
		_form(hair, [Vector3(0.057, -0.16, 0.17), Vector3(0.084, 0.065, 0.20), Vector3(0.064, 0.20, 0.17)], Vector3(0.213, 0.033, -0.115), hair_color)
		_panel(hair, PackedVector2Array([Vector2(-0.23, -0.05), Vector2(-0.245, 0.035), Vector2(-0.19, 0.115), Vector2(-0.02, 0.125), Vector2(0.19, 0.055), Vector2(0.21, 0.022), Vector2(0.105, 0.025), Vector2(-0.015, 0.057), Vector2(-0.13, -0.008)]), Vector3(0, 0.210, 0.157), hair_color, 0.031)
		_panel(hair, PackedVector2Array([Vector2(-0.19, 0.047), Vector2(-0.07, 0.099), Vector2(0.096, 0.053), Vector2(-0.012, 0.054), Vector2(-0.13, 0.007)]), Vector3(0, 0.232, 0.176), hair_color.lightened(0.045), 0.009)
	else:
		# The intern has a narrow jaw, a side-swept fringe and one tied, tapered
		# tail. The small off-centre tie makes the back silhouette readable too.
		_form(hair, [Vector3(0.39, -0.038, 0.29), Vector3(0.43, 0.065, 0.335), Vector3(0.33, 0.122, 0.27)], Vector3(0, 0.212, -0.032), hair_color)
		_panel(hair, PackedVector2Array([Vector2(-0.202, -0.028), Vector2(-0.18, 0.080), Vector2(-0.045, 0.115), Vector2(0.12, 0.095), Vector2(0.215, 0.022), Vector2(0.18, -0.020), Vector2(0.091, 0.013), Vector2(0.006, 0.046), Vector2(-0.098, -0.018)]), Vector3(0, 0.216, 0.159), hair_color, 0.032)
		_panel(hair, PackedVector2Array([Vector2(-0.16, 0.042), Vector2(-0.042, 0.101), Vector2(0.105, 0.079), Vector2(0.025, 0.052), Vector2(-0.078, 0.036)]), Vector3(0, 0.222, 0.180), hair_color.lightened(0.045), 0.009)
		for side: float in [-1.0, 1.0]:
			_form(hair, [Vector3(0.029, -0.087, 0.10), Vector3(0.053, 0.055, 0.20), Vector3(0.040, 0.135, 0.18)], Vector3(side * 0.188, 0.082, -0.033), hair_color)
		_chunk(hair, Vector3(0.205, 0.18, 0.15), Vector3(-0.072, 0.135, -0.169), hair_color)
		var ponytail: Node3D = Node3D.new()
		ponytail.name = "TiedPonytail"
		ponytail.position = Vector3(-0.145, 0.128, -0.235)
		ponytail.rotation.z = -0.33
		hair.add_child(ponytail)
		_form(ponytail, [Vector3(0.045, -0.36, 0.075), Vector3(0.12, -0.26, 0.13), Vector3(0.16, -0.06, 0.17), Vector3(0.135, 0.045, 0.15)], Vector3.ZERO, hair_color)
		_chunk(ponytail, Vector3(0.142, 0.040, 0.156), Vector3(0, -0.005, 0), Color("486965"))

func _build_hair() -> void:
	if character_gender == "female":
		_build_female_hair()
		return
	if _broad:
		_form(_head, [Vector3(0.46, -0.050, 0.32), Vector3(0.48, 0.070, 0.34), Vector3(0.37, 0.137, 0.29)], Vector3(0, 0.22, -0.017), hair_color)
		_panel(_head, PackedVector2Array([Vector2(-0.24, 0.032), Vector2(-0.23, 0.087), Vector2(-0.14, 0.143), Vector2(-0.08, 0.099), Vector2(0.07, 0.158), Vector2(0.22, 0.096), Vector2(0.24, 0.027), Vector2(0.11, 0.030)]), Vector3(0, 0.213, 0.151), hair_color, 0.031)
		for side: float in [-1.0, 1.0]:
			_chunk(_head, Vector3(0.053, 0.17, 0.23), Vector3(side * 0.238, 0.157, -0.045), hair_color)
	elif _thin:
		_panel(_head, PackedVector2Array([Vector2(-0.158, -0.047), Vector2(-0.183, 0.093), Vector2(-0.225, 0.164), Vector2(-0.089, 0.269), Vector2(0.030, 0.244), Vector2(0.100, 0.187), Vector2(0.158, 0.228), Vector2(0.184, 0.071), Vector2(0.144, -0.069)]), Vector3(0, 0.159, -0.020), hair_color, 0.313)
		_panel(_head, PackedVector2Array([Vector2(-0.18, 0.076), Vector2(-0.094, 0.202), Vector2(0.031, 0.178), Vector2(0.115, 0.087), Vector2(-0.095, 0.025)]), Vector3(0, 0.200, 0.142), hair_color.lightened(0.06), 0.018)
		for side: float in [-1.0, 1.0]:
			_chunk(_head, Vector3(0.044, 0.185, 0.20), Vector3(side * 0.163, 0.133, -0.030), hair_color)
	elif personality == "dumping":
		# Receding sides leave a large uninterrupted forehead. A rear crown and
		# one broad comb-over shape replace the old skin-colored block on a quiff.
		_chunk(_head, Vector3(0.38, 0.105, 0.15), Vector3(0, 0.22, -0.135), hair_color)
		for side: float in [-1.0, 1.0]:
			_chunk(_head, Vector3(0.070, 0.238, 0.22), Vector3(side * 0.207, 0.141, -0.046), hair_color)
		_panel(_head, PackedVector2Array([Vector2(-0.17, 0.022), Vector2(-0.124, 0.081), Vector2(0.029, 0.092), Vector2(0.131, 0.054), Vector2(0.017, 0.060), Vector2(-0.095, 0.047)]), Vector3(0, 0.215, 0.101), hair_color.lightened(0.045), 0.025)
	elif personality == "intern":
		_form(_head, [Vector3(0.39, -0.055, 0.29), Vector3(0.43, 0.055, 0.33), Vector3(0.31, 0.127, 0.24)], Vector3(0, 0.223, -0.026), hair_color)
		_panel(_head, PackedVector2Array([Vector2(-0.210, -0.024), Vector2(-0.151, 0.101), Vector2(-0.049, 0.176), Vector2(0.078, 0.122), Vector2(0.204, 0.068), Vector2(0.184, -0.041), Vector2(0.076, 0.031), Vector2(-0.093, -0.032)]), Vector3(0, 0.200, 0.154), hair_color, 0.043)
		_panel(_head, PackedVector2Array([Vector2(-0.160, 0.035), Vector2(-0.051, 0.141), Vector2(0.040, 0.096), Vector2(-0.044, 0.023)]), Vector3(0, 0.220, 0.181), hair_color.lightened(0.06), 0.014)
		for side: float in [-1.0, 1.0]:
			_chunk(_head, Vector3(0.045, 0.17, 0.20), Vector3(side * 0.191, 0.143, -0.031), hair_color)
	else:
		var width: float = 0.414 if personality == "rude" else 0.395
		_form(_head, [Vector3(width, -0.044, 0.29), Vector3(width * 1.025, 0.080, 0.33), Vector3(width * 0.74, 0.136, 0.25)], Vector3(0, 0.200, -0.037), hair_color)
		_panel(_head, PackedVector2Array([Vector2(-0.202, -0.055), Vector2(-0.213, 0.067), Vector2(-0.120, 0.126), Vector2(0.155, 0.089), Vector2(0.196, 0.043), Vector2(0.070, 0.001), Vector2(-0.080, -0.017)]), Vector3(0, 0.191, 0.148), hair_color.lightened(0.025), 0.030)
		for side: float in [-1.0, 1.0]:
			_chunk(_head, Vector3(0.049, 0.185, 0.22), Vector3(side * 0.185, 0.12, -0.035), hair_color)
		if affiliation == "other" and personality == "fearful":
			for side: float in [-1.0, 1.0]:
				_chunk(_head, Vector3(0.102, 0.32, 0.24), Vector3(side * 0.188, 0.015, -0.059), hair_color)

func can_opening_react() -> bool:
	return opening_role != "" and not opening_cancelled and state not in ["down", "flee", "pursue"]

func can_boss_lecture() -> bool:
	if not _broad or opening_role != "boss" or not can_opening_react() or opening_phase != "approach":
		return false
	if not _arrived or not is_on_floor() or not is_instance_valid(player_target):
		return false
	if Vector2(velocity.x, velocity.z).length() > 0.12 or _walk_speed > 0.12:
		return false
	var offset: Vector3 = player_target.global_position - global_position
	offset.y = 0.0
	if offset.length_squared() > 2.18 * 2.18 or offset.length_squared() < 0.01:
		return false
	var facing_error: float = wrapf(atan2(offset.x, offset.z) - rotation.y, -PI, PI)
	return absf(facing_error) < 0.18 and _can_reach_player()

func begin_boss_lecture_gesture(kind: String, duration: float) -> void:
	if kind not in ["question", "admonish", "insist"] or duration <= 0.0 or not can_boss_lecture():
		return
	boss_lecture_gesture = kind
	_lecture_pose = kind
	_lecture_age = 0.0
	_lecture_duration = duration

func stop_boss_lecture_gesture() -> void:
	# Keep the outgoing pose for a short blend back to rest. No navigation,
	# arrival or opening phase is reset when a line ends or is interrupted.
	boss_lecture_gesture = ""
	_lecture_duration = 0.0

func _advance_boss_lecture_gesture(delta: float) -> void:
	if boss_lecture_gesture != "":
		if not can_boss_lecture():
			stop_boss_lecture_gesture()
		else:
			_lecture_age += delta
			if _lecture_age >= _lecture_duration:
				stop_boss_lecture_gesture()
	var blend_goal: float = 1.0 if boss_lecture_gesture != "" else 0.0
	if boss_lecture_gesture != "":
		blend_goal *= 1.0 - smoothstep(maxf(_lecture_duration - 0.24, 0.0), _lecture_duration, _lecture_age)
	_lecture_blend = move_toward(_lecture_blend, blend_goal, delta * (4.8 if blend_goal > _lecture_blend else 6.0))
	if _lecture_blend <= 0.001:
		_lecture_pose = ""
	for wrist: Node3D in _lecture_wrists:
		wrist.visible = _lecture_blend > 0.10
	for hand: Node3D in _rest_hands:
		hand.visible = _lecture_blend <= 0.10

func _opening_controlled() -> bool:
	return can_opening_react() and opening_phase in ["listen", "startle", "peek", "approach"]

func opening_cue(cue: String) -> void:
	if not can_opening_react():
		return
	if cue not in ["listen", "startle", "peek", "approach", "release"]:
		return
	stop_boss_lecture_gesture()
	_cue_age = 0.0
	_arrived = false
	_reaction_spoken = true
	if cue == "release":
		opening_phase = "released"
		state = "concern"
		return
	opening_phase = cue
	state = "opening"
	if cue == "startle":
		# Widen instantly at the impact; torso and head follow over the next frames.
		_eye_open = 1.0
		_mouth_open = 0.78
	if cue == "approach":
		_repath_time = 0.0
		_path = PackedVector3Array()
		_path_index = 0

func _cancel_opening() -> void:
	stop_boss_lecture_gesture()
	_talk_time = 0.0
	if opening_role == "":
		return
	opening_cancelled = true
	opening_phase = "cancelled"
	if state == "opening":
		state = "concern"
	_cue_age = 0.0
	_arrived = false

func react(where: Vector3, intensity: float = 1.0) -> void:
	if state == "down" or state == "pursue" or _opening_controlled():
		return
	var distance: float = global_position.distance_to(where)
	# World filtering uses sound radius and occlusion. This extra local guard
	# keeps a faint far event from stopping work when called independently.
	if intensity <= 0.0 or distance > 3.0 + intensity * 4.0:
		return
	if state == "flee":
		_reaction_target = where
		_reaction_intensity = maxf(_reaction_intensity, intensity)
		return
	var delay: float = clampf(0.10 + distance * 0.075 + absf(_home.x * 0.11 + _home.z * 0.04) * 0.15, 0.10, 1.20)
	var close_threat: bool = intensity >= 1.45 and distance < 3.15
	if close_threat:
		delay = minf(delay, 0.12)
	if not _reaction_pending or intensity >= _pending_intensity or close_threat:
		_pending_target = where
		_pending_intensity = intensity
	_reaction_delay = minf(_reaction_delay, delay) if _reaction_pending else delay
	_reaction_pending = true

func _apply_reaction(where: Vector3, intensity: float) -> void:
	if state in ["down", "pursue"] or _opening_controlled():
		return
	interrupt_work()
	if opening_role != "" and opening_phase == "work":
		_cancel_opening()
	_reaction_target = where
	_reaction_intensity = maxf(_reaction_intensity, intensity)
	_reaction_age = 0.0
	var distance: float = global_position.distance_to(where)
	var close_threat: bool = intensity >= 1.45 and distance < 3.15
	if role == "boss":
		state = "concern"
	elif close_threat:
		state = "flee"
		_flee_destination = Vector3.INF
	elif role == "coward" or personality == "fearful":
		state = "stunned"
		_freeze_time = 0.85 if personality == "rude" else 0.60
		_after_freeze = "flee" if intensity > 0.5 else "concern"
	elif affiliation == "other" and personality == "spectator":
		state = "spectate"
	elif personality == "intern":
		state = "stunned"
		_freeze_time = 0.80
		_after_freeze = "concern"
	else:
		state = "concern"
	if not _reaction_spoken:
		_reaction_spoken = true
		_talk_time = 1.8
		said.emit("%s  |  %s" % [display_name, _reaction_text()])

func _reaction_text() -> String:
	if not reaction_line.is_empty() and (state != "flee" or personality == "fearful"):
		return reaction_line
	if state == "flee":
		return "가까이 오지 마세요!" if affiliation == "other" else "잠깐, 왜 이래!"
	if personality == "intern":
		return "어… 제가 뭘 잘못했나요?"
	if state == "stunned":
		return "어… 뭐야?"
	if state == "spectate":
		return "저쪽 무슨 일이야?"
	if role == "boss":
		return "지금 뭐 하는 겁니까? 책상은 회사 거예요."
	if personality == "dumping":
		return "잠깐, 커피 쏟겠다. 그만해."
	return "뭐 하는 거예요?"

func _advance_reaction(delta: float) -> void:
	if _reaction_pending:
		_reaction_delay -= delta
		if _reaction_delay <= 0.0:
			_reaction_pending = false
			_apply_reaction(_pending_target, _pending_intensity)
	if state == "stunned":
		_freeze_time -= delta
		if _freeze_time <= 0.0:
			state = _after_freeze
			_flee_destination = Vector3.INF
	# Curiosity is not a combat role. An already watching outsider still gets
	# out of the way when the active threat physically comes close to them.
	if state in ["spectate", "stunned", "concern"] and affiliation == "other" and is_instance_valid(player_target):
		if player_target.global_position.distance_to(global_position) < 2.0 and _reaction_intensity >= 1.45:
			state = "flee"
			_reaction_target = player_target.global_position
			_flee_destination = Vector3.INF

func _choose_flee_destination() -> Vector3:
	var best: Vector3 = global_position
	var best_value: float = -INF
	var danger: Vector3 = player_target.global_position if is_instance_valid(player_target) else _reaction_target
	var to_danger: Vector3 = danger - global_position
	to_danger.y = 0.0
	for point: Vector2 in flee_points:
		var candidate: Vector3 = Vector3(point.x, floor_height, point.y)
		var travel: Vector3 = candidate - global_position
		travel.y = 0.0
		var value: float = candidate.distance_to(danger) - travel.length() * 0.50
		if to_danger.length() < 3.0 and travel.normalized().dot(to_danger.normalized()) > 0.3:
			value -= 12.0
		if value > best_value:
			best_value = value
			best = candidate
	return best

func receive_hit(impulse: Vector3, _point: Vector3, damage: float, kind: String = "") -> void:
	# Snapshot before cancellation: a hit still ends the beat, but that same hit
	# must not knock Kim out while the nagging opening is unfinished.
	var blocked: bool = opening_blocks_knockdown()
	interrupt_work()
	_cancel_opening()
	if state == "down":
		if is_instance_valid(_rig_adapter) and _rig_adapter.ragdoll_active:
			_rig_adapter.apply_hit(impulse, _point)
		else:
			velocity += impulse * 0.17
		return
	var combo: bool = kind == "punch" and _combo_ready()
	var launch: bool = _wants_launch(impulse, damage, kind, combo, blocked)
	_reaction_pending = false
	_guard_push_active = false
	incident.emit("ASSAULT", 3.0, global_position)
	noise.emit(global_position, 2.0)
	health -= maxf(damage, 18.0)
	if blocked:
		health = maxf(health, 1.0)
		launch = false
	elif launch or health <= 0.0:
		launch = true
		health = minf(health, 0.0)
	if (kind == "punch" or kind == "kick") and not launch:
		_mark_strike()
	if launch:
		state = "down"
		_talk_time = 0.0
		damage_assessed.emit("care", 300000, "%s 치료·수습" % display_name)
		if not _is_responder():
			damage_assessed.emit("work", 200000, "%s 업무 복귀 불가" % display_name)
		if is_instance_valid(_rig_adapter):
			_rig_adapter.launching = true
			_rig_adapter.start_ragdoll(impulse, _point)
		else:
			_begin_procedural_launch(impulse)
		scored.emit("KNOCKDOWN", 100 if role == "police" else (75 if role == "guard" else 50), global_position)
	else:
		velocity += impulse * 0.42
		velocity.y = maxf(velocity.y, 1.2)
		if is_instance_valid(_rig_adapter):
			_rig_adapter.react_to_hit(impulse, _point)
		_speak_stagger()
		_apply_reaction(global_position, 2.0)
		_cooldown = 1.0

func opening_blocks_knockdown() -> bool:
	if opening_role != "boss" or opening_cancelled:
		return false
	var host: Node = get_parent()
	if host == null or not bool(host.get("opening_started")) or bool(host.get("boss_lecture_finished")):
		return false
	return true

func _wants_launch(impulse: Vector3, damage: float, kind: String, combo: bool, blocked: bool) -> bool:
	if blocked:
		return false
	if health - maxf(damage, 18.0) <= 0.0:
		return true
	if is_instance_valid(_rig_adapter) and _rig_adapter.should_knock_down(impulse):
		return true
	if kind != "kick" and not combo:
		return false
	# Kim's legacy mesh and the health-only comparison keep the old one-kick result.
	if _broad and not is_instance_valid(_rig_adapter):
		return false
	if is_instance_valid(_rig_adapter) and "--kim-health-only" in OS.get_cmdline_user_args():
		return false
	return true

func _combo_ready() -> bool:
	var window_ms: int = int(round(_hit_feel().second_hit_window * 1000.0))
	return Time.get_ticks_msec() - _last_player_strike_msec <= window_ms

func _mark_strike() -> void:
	_last_player_strike_msec = Time.get_ticks_msec()

func _hit_feel() -> Resource:
	return HitFeelScript.load_settings()

func _speak_stagger() -> void:
	_talk_time = 1.5
	_reaction_spoken = true
	said.emit("%s  |  %s" % [display_name, _hit_feel().stagger_line])

func _begin_procedural_launch(impulse: Vector3) -> void:
	_fall_side = -1.0 if impulse.x > 0.0 else 1.0
	var fallen: BoxShape3D = BoxShape3D.new()
	fallen.size = Vector3(1.75, 0.42, 0.66 if _broad else 0.48)
	_collision.set_deferred("shape", fallen)
	_collision.set_deferred("position", Vector3(-_fall_side * 0.72, 0.24, 0))
	var feel: Resource = _hit_feel()
	var horizontal: Vector3 = Vector3(impulse.x, 0.0, impulse.z)
	if horizontal.length_squared() < 0.0001:
		horizontal = -global_basis.z
	_flight_dir = horizontal.normalized()
	_flight_origin = global_position
	_clamp_flight_to_room = clamp_to_room(_flight_origin).distance_squared_to(_flight_origin) < 0.0004
	_flight_peak = feel.flight_peak
	_flight_duration = maxf(feel.flight_time, 0.2)
	_flight_distance = _flight_clearance(global_position, _flight_dir, feel.flight_distance)
	_flight_elapsed = 0.0
	_flight_active = true
	_flight_saved_mask = collision_mask
	collision_mask = 0
	velocity = Vector3.ZERO

func _flight_clearance(origin: Vector3, direction: Vector3, wanted: float) -> float:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = origin + Vector3.UP * 1.05
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + direction * wanted, 3)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return wanted
	return maxf(origin.distance_to(hit.position) - 0.42, 0.05)

func clamp_to_room(point: Vector3) -> Vector3:
	var best: Vector3 = point
	var best_distance: float = INF
	for bounds: Rect2 in flight_bounds:
		var candidate: Vector2 = Vector2(point.x, point.z).clamp(bounds.position, bounds.end)
		var distance: float = candidate.distance_squared_to(Vector2(point.x, point.z))
		if distance < best_distance:
			best = Vector3(candidate.x, point.y, candidate.y)
			best_distance = distance
	return best

func _advance_procedural_flight(delta: float) -> void:
	_flight_elapsed += delta
	var u: float = clampf(_flight_elapsed / _flight_duration, 0.0, 1.0)
	var desired: Vector3 = _flight_origin + _flight_dir * (_flight_distance * u) + Vector3.UP * (4.0 * _flight_peak * u * (1.0 - u))
	desired.y = maxf(desired.y, floor_height + 0.02)
	if _clamp_flight_to_room:
		desired = clamp_to_room(desired)
	var motion: Vector3 = desired - global_position
	var blocked: Dictionary = _sweep_body(global_position + Vector3.UP * 1.0, motion)
	if not blocked.is_empty():
		global_position += motion * float(blocked.fraction) + (blocked.normal as Vector3) * 0.08
		global_position.y = maxf(global_position.y, floor_height + 0.02)
		if _clamp_flight_to_room:
			global_position = clamp_to_room(global_position)
		_finish_procedural_flight(blocked.normal)
		return
	global_position = desired
	velocity = Vector3.ZERO
	_down_rotation = _fall_side * lerpf(0.2, PI * 0.42, smoothstep(0.55, 1.0, u))
	_visual.rotation.z = _down_rotation
	_visual.position.y = absf(sin(_down_rotation)) * 0.22
	if u < 1.0:
		return
	_finish_procedural_flight(-Vector3.UP)

func _sweep_body(from: Vector3, motion: Vector3) -> Dictionary:
	if motion.length_squared() < 0.000001:
		return {}
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.38
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, from)
	params.motion = motion
	params.collision_mask = 3
	params.exclude = [get_rid()]
	var fractions: PackedFloat32Array = space.cast_motion(params)
	if fractions.size() < 1 or fractions[0] >= 0.995:
		return {}
	var probe_from: Vector3 = from + motion * maxf(fractions[0] - 0.2, 0.0)
	var ray := PhysicsRayQueryParameters3D.create(probe_from, probe_from + motion.normalized() * 0.5, 3)
	ray.exclude = [get_rid()]
	var hit: Dictionary = space.intersect_ray(ray)
	var normal: Vector3 = -motion.normalized()
	if not hit.is_empty():
		normal = hit.normal
	if normal.y > 0.72 and motion.y >= -0.05:
		return {}
	return {"fraction": maxf(fractions[0] - 0.05, 0.0), "normal": normal}

func _finish_procedural_flight(normal: Vector3) -> void:
	_flight_active = false
	collision_mask = _flight_saved_mask if _flight_saved_mask != 0 else 15
	if normal.length_squared() < 0.0001:
		normal = Vector3.UP
	velocity = (normal * 0.4 + Vector3.DOWN * 1.6).limit_length(6.0)
	_thud(6.0)

func _thud(speed: float) -> void:
	impact_thuds += 1
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0].has_method("add_shake"):
		players[0].add_shake(_hit_feel().shake_impact)
	if DisplayServer.get_name() == "headless":
		return
	if not is_instance_valid(_thud_audio):
		_thud_audio = AudioStreamPlayer3D.new()
		_thud_audio.max_distance = 18.0
		_thud_audio.stream = preload("res://assets/audio/kenney/impactSoft_heavy_000.ogg")
		add_child(_thud_audio)
	_thud_audio.global_position = global_position
	_thud_audio.volume_db = clampf(-3.0 + speed * 0.25, -6.0, -1.0)
	_thud_audio.play()

func enter_response_floor(at: Vector3) -> void:
	global_position = at
	_home = at
	velocity = Vector3.ZERO
	_repath_time = 0.0
	_path = PackedVector3Array()
	_guard_push_active = false
	response_exit = Vector3.INF
	reset_physics_interpolation()

func _path_direction(destination: Vector3, delta: float) -> Vector3:
	_repath_time -= delta
	if navigation_provider.is_valid() and (_repath_time <= 0.0 or destination.distance_squared_to(_path_target) > 0.64):
		_path = navigation_provider.call(global_position, destination)
		_path_index = 0
		_path_target = destination
		_repath_time = 0.6
	while _path_index < _path.size():
		var offset: Vector3 = _path[_path_index] - global_position
		offset.y = 0.0
		if offset.length() > 0.17:
			return offset.normalized()
		_path_index += 1
	return Vector3.ZERO

func _can_reach_player() -> bool:
	if not is_instance_valid(player_target):
		return false
	var start: Vector3 = global_position + Vector3.UP
	var end: Vector3 = player_target.global_position + Vector3.UP
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, end, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _update_height_collision() -> void:
	if state == "down":
		return
	var height: float = maxf(0.85, _standing_height + _pose_height + _head_drop)
	_capsule.height = height
	_collision.position.y = height * 0.5

func _turn_to_player(delta: float, body_speed: float, head_speed: float) -> void:
	if not is_instance_valid(player_target):
		return
	_turn_toward(player_target.global_position, delta, body_speed, head_speed)

func _turn_toward(target: Vector3, delta: float, body_speed: float, head_speed: float) -> void:
	var offset: Vector3 = target - global_position
	offset.y = 0.0
	if offset.length_squared() < 0.01:
		return
	var target_yaw: float = atan2(offset.x, offset.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * body_speed, 1.0))
	var head_yaw: float = clampf(wrapf(target_yaw - rotation.y, -PI, PI), -1.05, 1.05)
	_head.rotation.y = lerp_angle(_head.rotation.y, head_yaw, minf(delta * head_speed, 1.0))

func _advance_security(delta: float, distance: float, offset: Vector3) -> void:
	if not _is_responder() or state != "pursue":
		_guard_push_active = false
		return
	if not _guard_warning_spoken and distance <= 6.0:
		_guard_warning_spoken = true
		_talk_time = 2.0
		var warning: String = reaction_line if not reaction_line.is_empty() else "그만하시고 뒤로 물러나세요."
		said.emit("%s  |  %s" % [display_name, warning])
	if not _guard_push_active and _cooldown <= 0.0 and distance <= 1.10 and _can_reach_player():
		_guard_push_active = true
		_guard_push_age = 0.0
		_guard_push_contact = false
		_cooldown = 1.55
	if not _guard_push_active:
		return
	_guard_push_age += delta
	if _guard_push_age >= 0.22 and not _guard_push_contact:
		_guard_push_contact = true
		# Contact, not the start of a windup, is the moment a push can subdue.
		# Moving away or putting a solid desk between the hands and player works.
		if distance <= 1.42 and _can_reach_player():
			if player_target.has_method("receive_security_push"):
				player_target.call("receive_security_push", offset.normalized(), 2.8 if role == "police" else 2.4)
			player_hit.emit(14.0 if role == "police" else 10.0)
	if _guard_push_age >= 0.58:
		_guard_push_active = false

func _security_push_extension() -> float:
	if not _guard_push_active:
		return 0.0
	if _guard_push_age < 0.12:
		return -0.18 * smoothstep(0.0, 0.12, _guard_push_age)
	if _guard_push_age < 0.25:
		return lerpf(-0.18, 1.0, smoothstep(0.12, 0.25, _guard_push_age))
	return 1.0 - smoothstep(0.30, 0.58, _guard_push_age)

func _pose_security_hands(delta: float) -> void:
	_guard_palm_blend = move_toward(_guard_palm_blend, 1.0 if state == "pursue" else 0.0, delta * 5.0)
	for index: int in range(_lecture_wrists.size()):
		var wrist: Node3D = _lecture_wrists[index]
		wrist.visible = _guard_palm_blend > 0.1
		var arm: Node3D = _left_arm if index == 0 else _right_arm
		var elbow: Node3D = _left_elbow if index == 0 else _right_elbow
		# Fingers point up while the broad palm faces the person being stopped.
		var wrist_goal: Vector3 = Vector3(-PI - arm.rotation.x - elbow.rotation.x, 0, -0.06 if index == 0 else 0.06)
		wrist.rotation = wrist.rotation.lerp(wrist_goal, minf(delta * 16.0, 1.0))
	for hand: Node3D in _rest_hands:
		hand.visible = _guard_palm_blend <= 0.1
	for finger: Node3D in _lecture_fingers:
		finger.rotation.x = 0.04

func _begin_boss_gait() -> void:
	_gait_initialized = true
	_walk_phase = BOSS_STANCE_FRACTION * 0.5
	_walk_previous_yaw = rotation.y
	_foot_positions = [_left_ankle.global_position, _right_ankle.global_position]
	_foot_swing_origins = _foot_positions.duplicate()
	_foot_swing_start_phases = [_walk_phase, fposmod(_walk_phase + 0.5, 1.0)]
	_foot_yaws = [rotation.y, rotation.y]
	_foot_swing_yaws = [rotation.y, rotation.y]
	_foot_planted = [true, false]

func _advance_boss_gait(displacement: Vector3, requested_move: Vector3, delta: float) -> void:
	displacement.y = 0.0
	_walk_speed = displacement.length() / maxf(delta, 0.0001)
	var moving: bool = is_on_floor() and requested_move.length_squared() > 0.001 and _walk_speed > 0.04
	_walk_blend = move_toward(_walk_blend, 1.0 if moving else 0.0, delta * (7.0 if moving else 5.0))
	if not moving:
		# Finish settling once; do not run a time-driven gait against an obstacle.
		_walk_previous_yaw = rotation.y
		if _walk_blend <= 0.001:
			_gait_initialized = false
			_walk_pelvis_offset = 0.0
		return
	if not _gait_initialized:
		_begin_boss_gait()
	_walk_distance += displacement.length()
	# The hips also travel around the planted foot when turning. Shorten the
	# inside step by that real arc so a corner cannot wrench a foot across the
	# body while its old straight-line stance continues. This never runs when
	# collision blocks root movement, and does not change straight-line cadence.
	var turn_arc: float = absf(wrapf(rotation.y - _walk_previous_yaw, -PI, PI)) * 0.20
	_walk_previous_yaw = rotation.y
	_walk_phase = fposmod(_walk_phase + (displacement.length() + turn_arc) / BOSS_CYCLE_DISTANCE, 1.0)
	var forward: Vector3 = Vector3(sin(rotation.y), 0, cos(rotation.y))
	var across: Vector3 = Vector3(cos(rotation.y), 0, -sin(rotation.y))
	var pelvis_goal: float = 0.0
	for index: int in range(2):
		var phase: float = fposmod(_walk_phase + float(index) * 0.5, 1.0)
		var planted: bool = phase < BOSS_STANCE_FRACTION
		var side: float = -1.0 if index == 0 else 1.0
		var stance_point: Vector3 = global_position + across * side * 0.20 + forward * BOSS_STEP_REACH + Vector3.UP * 0.075
		if planted and not _foot_planted[index]:
			# The previous swing ends at a world-space footprint. Keep that point
			# fixed during support, even while the body turns through the corner.
			_foot_positions[index] = stance_point
			_foot_yaws[index] = rotation.y
		elif not planted and _foot_planted[index]:
			_foot_swing_origins[index] = _foot_positions[index]
			_foot_swing_yaws[index] = _foot_yaws[index]
			_foot_swing_start_phases[index] = BOSS_STANCE_FRACTION
		_foot_planted[index] = planted
		if not planted:
			var swing: float = clampf((phase - _foot_swing_start_phases[index]) / (1.0 - _foot_swing_start_phases[index]), 0.0, 1.0)
			var eased: float = smoothstep(0.0, 1.0, swing)
			# Predict the footprint from the remaining distance in this step.
			# On a straight route this target stays fixed as the body advances;
			# on a turn it follows the intended new heading without crossing feet.
			var landing: Vector3 = stance_point + forward * ((1.0 - phase) * BOSS_CYCLE_DISTANCE)
			_foot_positions[index] = _foot_swing_origins[index].lerp(landing, eased) + Vector3.UP * sin(swing * PI) * 0.105
			_foot_yaws[index] = lerp_angle(_foot_swing_yaws[index], rotation.y, eased)
		else:
			var footprint: Vector3 = to_local(_foot_positions[index])
			var across_hip: float = footprint.x - side * 0.20
			var horizontal_reach_squared: float = across_hip * across_hip + footprint.z * footprint.z
			# Let the hips rise over the support leg, then lower into the next
			# contact. This follows leg reach instead of an unrelated clock bob.
			var support_height: float = footprint.y + sqrt(maxf(0.66 * 0.66 - horizontal_reach_squared, 0.20)) - _hip_height
			pelvis_goal = minf(pelvis_goal, support_height)
	_walk_pelvis_offset = lerpf(_walk_pelvis_offset, clampf(pelvis_goal, -0.14, -0.025), minf(delta * 20.0, 1.0))

func _pose_boss_walking_legs() -> void:
	if not _gait_initialized or _walk_blend <= 0.001:
		_left_ankle.rotation = Vector3.ZERO
		_right_ankle.rotation = Vector3.ZERO
		return
	var legs: Array[Node3D] = [_left_leg, _right_leg]
	var knees: Array[Node3D] = [_left_knee, _right_knee]
	var ankles: Array[Node3D] = [_left_ankle, _right_ankle]
	for index: int in range(2):
		var leg: Node3D = legs[index]
		var target: Vector3 = _visual.to_local(_foot_positions[index]) - leg.position
		var reach: float = clampf(target.length(), 0.12, THIGH_LENGTH + SHIN_LENGTH - 0.002)
		var direction: Vector3 = target.normalized()
		var hinge: Vector3 = Vector3.BACK.cross(direction).normalized()
		if hinge.length_squared() < 0.1:
			hinge = Vector3.RIGHT
		var bend_direction: Vector3 = direction.cross(hinge).normalized()
		var upper_angle: float = acos(clampf((THIGH_LENGTH * THIGH_LENGTH + reach * reach - SHIN_LENGTH * SHIN_LENGTH) / (2.0 * THIGH_LENGTH * reach), -1.0, 1.0))
		var upper_direction: Vector3 = direction * cos(upper_angle) + bend_direction * sin(upper_angle)
		var hip_basis: Basis = Basis(hinge, -upper_direction, hinge.cross(-upper_direction)).orthonormalized()
		leg.quaternion = leg.quaternion.slerp(hip_basis.get_rotation_quaternion(), _walk_blend)
		var knee_angle: float = PI - acos(clampf((THIGH_LENGTH * THIGH_LENGTH + SHIN_LENGTH * SHIN_LENGTH - reach * reach) / (2.0 * THIGH_LENGTH * SHIN_LENGTH), -1.0, 1.0))
		knees[index].rotation.x = lerpf(knees[index].rotation.x, knee_angle, _walk_blend)
		# Counter-rotate at the ankle so knee flexion does not point the shoes
		# through the floor. The footprint keeps its heading during support.
		var planted_basis: Basis = Basis(Vector3.UP, _foot_yaws[index])
		var ankle_basis: Basis = knees[index].global_basis.inverse() * planted_basis
		ankles[index].quaternion = Quaternion.IDENTITY.slerp(ankle_basis.get_rotation_quaternion(), _walk_blend)

func _lecture_emphasis() -> float:
	# Two deliberate accents per sentence leave a readable held pose between
	# them, instead of endlessly waving on a time-driven sine loop.
	var phase: float = clampf(_lecture_age / maxf(_lecture_duration, 0.001), 0.0, 1.0)
	var first: float = sin(clampf((phase - 0.16) / 0.22, 0.0, 1.0) * PI)
	var second: float = sin(clampf((phase - 0.54) / 0.20, 0.0, 1.0) * PI)
	return first + second * 0.70

func _pose_lecture_hands(delta: float, left_wrist: Vector3, right_wrist: Vector3) -> void:
	for index: int in range(_lecture_wrists.size()):
		var goal: Vector3 = left_wrist if index == 0 else right_wrist
		_lecture_wrists[index].rotation = _lecture_wrists[index].rotation.lerp(goal * _lecture_blend, minf(delta * 14.0, 1.0))
	for index: int in range(_lecture_fingers.size()):
		var curl: float = 0.10
		if _lecture_pose == "admonish":
			curl = (0.04 if index % 4 == 0 else 1.42) if index >= 4 else 0.38
		_lecture_fingers[index].rotation.x = lerpf(_lecture_fingers[index].rotation.x, curl, minf(delta * 16.0, 1.0))

func _animate_pose(delta: float, walking: float) -> void:
	var working: bool = opening_role != "" and opening_phase in ["work", "listen"] and not opening_cancelled
	var ordinary_work: bool = opening_role == "" and is_working()
	var coworker_hold: bool = opening_role == "coworker" and opening_phase == "startle" and not opening_cancelled
	var peeking: bool = opening_role == "boss" and opening_phase == "peek" and not opening_cancelled
	var approaching: bool = opening_role == "boss" and opening_phase == "approach" and not opening_cancelled
	var height_goal: float = 0.0
	var head_drop_goal: float = 0.0
	if working:
		height_goal = -0.58 if _broad else -0.24
		head_drop_goal = -0.24 if _broad else -0.035
	elif ordinary_work and work_activity == "typing":
		height_goal = -0.24
		head_drop_goal = -0.025
	elif coworker_hold:
		height_goal = -0.13
	elif peeking:
		# At the actual seated camera, the nose and mouth must clear the divider too.
		# The partition still hides the torso; only the head appears above its edge.
		height_goal = 0.0
	# Work-to-peek rises 0.58m in about 0.48s without root displacement.
	_pose_height = move_toward(_pose_height, height_goal, delta * (1.20 if peeking else 1.4))
	_head_drop = move_toward(_head_drop, head_drop_goal, delta * 0.65)
	var startle_pop: float = sin(clampf(_cue_age / 0.24, 0.0, 1.0) * PI) if coworker_hold else 0.0
	var work_rhythm: float = sin(_clock * 7.0)
	_visual.position.y = _pose_height + (sin(_clock * 2.3) * 0.006 if working else walking * absf(sin(_clock * 4.0)) * 0.01)
	var torso_pitch: float = 0.055 if working and _thin else -startle_pop * 0.10
	var torso_roll: float = -0.055 if working and _thin else (0.026 if coworker_hold else 0.0)
	if ordinary_work:
		torso_pitch = 0.045 if work_activity in ["typing", "copy"] else 0.012
		torso_roll = sin(_clock * 0.65 + _home.x) * 0.012
	elif opening_role == "" and state == "spectate":
		torso_pitch = -0.050
		torso_roll = 0.075
	elif opening_role == "" and state in ["stunned", "flee"]:
		torso_pitch = -sin(clampf(_reaction_age / 0.32, 0.0, 1.0) * PI) * 0.11
	if _broad:
		if not working:
			_visual.position.y = _pose_height + _walk_pelvis_offset * _walk_blend
		_visual.position.x = sin(_walk_phase * TAU) * _walk_blend * 0.012
		_visual.rotation.y = sin(_walk_phase * TAU) * _walk_blend * 0.018
		torso_pitch += _walk_blend * 0.023
		torso_roll += sin(_walk_phase * TAU) * _walk_blend * 0.015
	_visual.rotation.x = lerpf(_visual.rotation.x, torso_pitch, minf(delta * 12.0, 1.0))
	_visual.rotation.z = lerpf(_visual.rotation.z, torso_roll, minf(delta * 9.0, 1.0))
	_head.position = _head_base + Vector3(0, _head_drop + startle_pop * 0.035, 0.025 if working else 0.0)
	var head_pitch: float = 0.22 if working else (-startle_pop * 0.18 if coworker_hold else -0.035)
	var head_roll: float = 0.065 if coworker_hold else 0.0
	if ordinary_work:
		head_pitch = 0.24 if work_activity in ["papers", "copy"] else (0.17 if work_activity == "typing" else -0.03)
		head_roll = 0.055 if personality == "intern" else -0.025
	elif opening_role == "" and state == "stunned":
		head_pitch = -0.085
		head_roll = -0.08
	elif opening_role == "" and state == "spectate":
		head_roll = 0.105
	var lecture_accent: float = _lecture_emphasis() if _lecture_blend > 0.001 else 0.0
	if _lecture_pose == "question":
		head_pitch = lerpf(head_pitch, -0.025 + lecture_accent * 0.035, _lecture_blend)
		head_roll = lerpf(head_roll, -0.075, _lecture_blend)
	elif _lecture_pose == "admonish":
		head_pitch = lerpf(head_pitch, 0.01 + lecture_accent * 0.08, _lecture_blend)
		head_roll = lerpf(head_roll, 0.025, _lecture_blend)
	elif _lecture_pose == "insist":
		head_pitch = lerpf(head_pitch, -0.065 + lecture_accent * 0.025, _lecture_blend)
		head_roll = lerpf(head_roll, -0.065, _lecture_blend)
	_head.rotation.x = lerpf(_head.rotation.x, head_pitch, minf(delta * 10.0, 1.0))
	if working:
		_head.rotation.y = lerp_angle(_head.rotation.y, sin(_clock * 0.47) * 0.035, minf(delta * 4.0, 1.0))
		_head.rotation.z = lerpf(_head.rotation.z, -0.045 if _thin else 0.025, minf(delta * 4.0, 1.0))
	else:
		if ordinary_work:
			_head.rotation.y = lerp_angle(_head.rotation.y, sin(_clock * 0.63 + _home.z) * 0.045, minf(delta * 4.0, 1.0))
		_head.rotation.z = lerpf(_head.rotation.z, head_roll, minf(delta * 8.0, 1.0))
	var left_shoulder: Vector3 = Vector3.ZERO
	var right_shoulder: Vector3 = Vector3.ZERO
	var left_elbow: float = -0.16
	var right_elbow: float = -0.16
	if working:
		left_shoulder = Vector3(-0.63 + work_rhythm * 0.025, -0.07, -0.05)
		right_shoulder = Vector3(-0.67 - work_rhythm * 0.025, 0.07, 0.07)
		left_elbow = -0.78 + work_rhythm * 0.035
		right_elbow = -0.70 - work_rhythm * 0.035
	elif ordinary_work:
		match work_activity:
			"typing":
				var tap: float = sin(_clock * 8.4 + _home.x)
				left_shoulder = Vector3(-0.66 + tap * 0.04, -0.10, -0.06)
				right_shoulder = Vector3(-0.63 - tap * 0.04, 0.10, 0.06)
				left_elbow = -0.74 + tap * 0.055
				right_elbow = -0.78 - tap * 0.055
			"papers":
				var page: float = smoothstep(0.50, 0.95, sin(_clock * 1.55 + _home.x))
				left_shoulder = Vector3(-0.40, -0.05, -0.075)
				left_elbow = -1.29
				right_shoulder = Vector3(-0.34 - page * 0.28, -0.16 - page * 0.22, 0.10)
				right_elbow = -0.95 - page * 0.38
			"copy":
				var press: float = smoothstep(0.22, 0.85, sin(_clock * 1.35 + _home.x))
				left_shoulder = Vector3(-0.20, 0, -0.11)
				left_elbow = -1.12
				right_shoulder = Vector3(-0.70 - press * 0.23, 0.06, 0.055)
				right_elbow = -0.67 + press * 0.19
			"coffee":
				var sip: float = smoothstep(0.80, 0.97, sin(_clock * 0.68 + 0.30))
				left_shoulder = Vector3(-0.04, 0, -0.08)
				right_shoulder = Vector3(-0.50 - sip * 0.36, -0.35, 0.10)
				right_elbow = -1.40 - sip * 0.45
	elif coworker_hold:
		left_shoulder = Vector3(-0.62 - startle_pop * 0.45, -0.06, -0.22 - startle_pop * 0.20)
		right_shoulder = Vector3(-0.71 - startle_pop * 0.37, 0.08, 0.18 + startle_pop * 0.23)
		left_elbow = -0.97
		right_elbow = -0.87
	elif peeking:
		left_shoulder = Vector3(-0.52, -0.06, -0.13)
		right_shoulder = Vector3(-0.48, 0.06, 0.14)
		left_elbow = -0.74
		right_elbow = -0.80
	else:
		var stride: float = sin(_clock * 7.0) * walking * 0.24
		left_shoulder = Vector3(-stride * 0.65, 0, -0.10 if _broad else -0.045)
		right_shoulder = Vector3(stride * 0.65, 0, 0.10 if _broad else 0.045)
		if _broad:
			var arm_swing: float = cos(_walk_phase * TAU) * _walk_blend * 0.29
			left_shoulder.x = arm_swing
			right_shoulder.x = -arm_swing
			left_elbow = -0.22 - _walk_blend * 0.08
			right_elbow = left_elbow
		if approaching and _cue_age < 0.95:
			var gesture: float = 1.0 - smoothstep(0.45, 0.95, _cue_age)
			right_shoulder.x = lerpf(right_shoulder.x, -0.43, gesture)
			right_elbow = lerpf(right_elbow, -0.88, gesture)
	if not _broad and not _opening_controlled() and not ordinary_work:
		if state == "stunned":
			left_shoulder = Vector3(-0.62, -0.04, -0.15)
			right_shoulder = Vector3(-0.66, 0.08, 0.22)
			left_elbow = -1.0
			right_elbow = -0.85
		elif state == "flee":
			left_shoulder = Vector3(-0.60, -0.06, -0.30)
			right_shoulder = Vector3(-0.71, 0.08, 0.31)
			left_elbow = -1.02
			right_elbow = -1.06
		elif state == "spectate":
			left_elbow = -0.42
			right_elbow = -0.75
		elif state == "concern" and personality == "dumping":
			left_shoulder = Vector3(-0.64, -0.12, -0.20)
			left_elbow = -0.95
		if is_instance_valid(_work_prop):
			if work_activity == "coffee":
				right_shoulder = Vector3(-0.48, -0.18, 0.09)
				right_elbow = -1.24
			elif work_activity in ["papers", "copy"]:
				left_shoulder = Vector3(-0.47, -0.10, -0.09)
				left_elbow = -1.15
	if _is_responder() and state == "pursue":
		var extension: float = _security_push_extension()
		left_shoulder = Vector3(-0.62 - extension * 0.60, -0.12, -0.25)
		right_shoulder = Vector3(-0.68 - extension * 0.56, 0.12, 0.25)
		left_elbow = -1.32 + extension * 0.82
		right_elbow = -1.26 + extension * 0.78
	if _broad:
		var upper_lean: float = 0.0
		var upper_roll: float = 0.0
		var left_wrist: Vector3 = Vector3.ZERO
		var right_wrist: Vector3 = Vector3.ZERO
		if _lecture_pose == "question":
			# Both forearms rise into an open, palms-up "what are you doing?".
			left_shoulder = left_shoulder.lerp(Vector3(-0.49 - lecture_accent * 0.05, -0.13, -0.30), _lecture_blend)
			right_shoulder = right_shoulder.lerp(Vector3(-0.46 - lecture_accent * 0.07, 0.13, 0.30), _lecture_blend)
			left_elbow = lerpf(left_elbow, -1.02, _lecture_blend)
			right_elbow = lerpf(right_elbow, -1.05, _lecture_blend)
			left_wrist = Vector3(-0.10, -0.08, -0.06)
			right_wrist = Vector3(-0.10, 0.08, 0.06)
			upper_lean = 0.012
			upper_roll = -0.015
		elif _lecture_pose == "admonish":
			# The right index stays extended while the other fingers curl. Two
			# short downward beats indicate the desk without becoming a punch.
			left_shoulder = left_shoulder.lerp(Vector3(-0.16, -0.03, -0.16), _lecture_blend)
			right_shoulder = right_shoulder.lerp(Vector3(-0.82 + lecture_accent * 0.09, -0.10, 0.08), _lecture_blend)
			left_elbow = lerpf(left_elbow, -0.38, _lecture_blend)
			right_elbow = lerpf(right_elbow, -0.98 + lecture_accent * 0.06, _lecture_blend)
			left_wrist = Vector3(0.15, 0, 0)
			# Raise the pointing hand above the nearby desk and angle the index
			# across the view; a straight-on finger collapsed into a fist silhouette.
			right_wrist = Vector3(-0.10, -0.35, 0.48)
			upper_lean = 0.04 + lecture_accent * 0.025
		elif _lecture_pose == "insist":
			# Offer a palm towards the silent player and lean from the hips while
			# keeping both feet at the approved stopped position.
			left_shoulder = left_shoulder.lerp(Vector3(-0.36, -0.08, -0.24), _lecture_blend)
			right_shoulder = right_shoulder.lerp(Vector3(-0.98 - lecture_accent * 0.07, -0.04, 0.15), _lecture_blend)
			left_elbow = lerpf(left_elbow, -1.12, _lecture_blend)
			right_elbow = lerpf(right_elbow, -0.68 + lecture_accent * 0.07, _lecture_blend)
			left_wrist = Vector3(-0.05, -0.06, -0.08)
			right_wrist = Vector3(0.95, 0.06, 0)
			upper_lean = 0.082 + lecture_accent * 0.02
			upper_roll = -0.012
		_upper_body.rotation = Vector3(upper_lean, 0, upper_roll) * _lecture_blend
		var lean_pivot: Vector3 = Vector3(0, 0.88, 0)
		_upper_body.position = lean_pivot - _upper_body.basis * lean_pivot
		_pose_lecture_hands(delta, left_wrist, right_wrist)
	_left_arm.rotation = _left_arm.rotation.lerp(left_shoulder, minf(delta * 13.0, 1.0))
	_right_arm.rotation = _right_arm.rotation.lerp(right_shoulder, minf(delta * 11.0, 1.0))
	_left_elbow.rotation.x = lerpf(_left_elbow.rotation.x, left_elbow, minf(delta * 13.0, 1.0))
	_right_elbow.rotation.x = lerpf(_right_elbow.rotation.x, right_elbow, minf(delta * 11.0, 1.0))
	if _is_responder():
		_pose_security_hands(delta)
	if is_instance_valid(_work_prop) and work_activity == "coffee":
		_work_prop.rotation.x = -_right_arm.rotation.x - _right_elbow.rotation.x
	var seated: float = clampf(-_pose_height / (0.58 if _broad else 0.24), 0.0, 1.0)
	var leg_wave: float = sin(_clock * 7.0) * walking * 0.22
	_left_leg.position.y = _hip_height + seated * (0.40 if _broad else 0.12)
	_right_leg.position.y = _left_leg.position.y
	_left_leg.rotation.x = -seated * 1.13 + leg_wave
	_right_leg.rotation.x = -seated * 1.13 - leg_wave
	_left_knee.rotation.x = seated * 1.15
	_right_knee.rotation.x = seated * 1.15
	_tie.rotation.x = sin(_clock * 7.0) * walking * 0.07 - startle_pop * 0.28
	_tie.rotation.z = -0.075 if _thin else sin(_clock * 4.0) * walking * 0.025
	if _broad:
		_left_leg.rotation = Vector3(-seated * 1.13, 0, 0)
		_right_leg.rotation = Vector3(-seated * 1.13, 0, 0)
		_pose_boss_walking_legs()
		_tie.rotation.x = sin(_walk_phase * TAU - 0.35) * _walk_blend * 0.035
		_tie.rotation.z = sin(_walk_phase * TAU) * _walk_blend * 0.018
	var eye_goal: float = 0.43 if _broad else 0.52
	var mouth_goal: float = 0.11 if _broad else 0.20
	if coworker_hold:
		eye_goal = 1.0
		mouth_goal = 0.82 if _cue_age < 1.7 else 0.55
	elif peeking:
		eye_goal = 0.83
		mouth_goal = 0.42
	elif approaching:
		eye_goal = 0.61
		mouth_goal = 0.29
	elif state == "concern":
		eye_goal = 0.72
		mouth_goal = 0.36
	elif state == "stunned":
		eye_goal = 0.97
		mouth_goal = 0.66
	elif state == "flee":
		eye_goal = 0.90
		mouth_goal = 0.50
	elif state == "spectate":
		eye_goal = 0.70
		mouth_goal = 0.20
	if _talk_time > 0.0 and not _opening_controlled():
		mouth_goal = 0.15 + absf(sin(_clock * 9.0)) * 0.47
	if boss_lecture_gesture != "":
		var speech_pulse: float = absf(sin(_lecture_age * 9.4 + sin(_lecture_age * 3.1) * 0.7))
		mouth_goal = lerpf(mouth_goal, 0.18 + speech_pulse * 0.50, _lecture_blend)
		var lecture_eye: float = 0.74 if _lecture_pose == "question" else (0.53 if _lecture_pose == "admonish" else 0.61)
		eye_goal = lerpf(eye_goal, lecture_eye, _lecture_blend)
	_eye_open = lerpf(_eye_open, eye_goal, minf(delta * 12.0, 1.0))
	_mouth_open = lerpf(_mouth_open, mouth_goal, minf(delta * 12.0, 1.0))
	for index: int in range(_eyes.size()):
		_eyes[index].scale.y = _eye_open
		# The pupil stays seated on its white as the eye opens, rather than
		# remaining a free-floating bead outside a compressed sphere.
		_pupils[index].scale.y = 1.0 / maxf(_eye_open, 0.38)
		_upper_lids[index].position.y = _face_eye_y + _face_eye_height * _eye_open * 0.50
		_lower_lids[index].position.y = _face_eye_y - _face_eye_height * _eye_open * 0.49
	for index: int in range(_brows.size()):
		var side: float = -1.0 if index == 0 else 1.0
		var brow: Node3D = _brows[index]
		var asymmetry: float = _face_brow_bias * (1.0 - clampf((_eye_open - 0.52) * 2.0, 0.0, 1.0))
		brow.position.y = _face_eye_y + 0.052 + _eye_open * 0.065 + side * asymmetry * 0.05
		brow.position.z = _face_brow_z - maxf(_eye_open - 0.52, 0.0) * 0.035
		var brow_angle: float = 0.27 if _broad and not peeking else (-0.27 if coworker_hold else -0.08)
		if _lecture_blend > 0.001:
			brow_angle = lerpf(brow_angle, 0.17 if _lecture_pose == "question" else (0.36 if _lecture_pose == "admonish" else 0.29), _lecture_blend)
		brow.rotation.z = side * brow_angle + asymmetry
	_mouth.scale.y = _mouth_open
	_lower_lip.position.y = _mouth.position.y - 0.008 - _mouth_open * 0.055
	_update_height_collision()

func _physics_process(delta: float) -> void:
	if is_instance_valid(_rig_adapter) and _rig_adapter.ragdoll_active:
		return
	_clock += delta
	_cue_age += delta
	_reaction_age += delta
	_talk_time = maxf(_talk_time - delta, 0.0)
	_cooldown -= delta
	_advance_reaction(delta)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	var move: Vector3 = Vector3.ZERO
	var target_valid: bool = is_instance_valid(player_target)
	var boss_approaching: bool = _broad and _opening_controlled() and opening_phase == "approach"
	if state == "down":
		stop_boss_lecture_gesture()
		_lecture_blend = 0.0
		if _flight_active:
			_advance_procedural_flight(delta)
		else:
			_down_rotation = move_toward(_down_rotation, _fall_side * PI * 0.5, delta * 7.5)
			_visual.rotation.z = _down_rotation
			_visual.position.y = absf(sin(_down_rotation)) * 0.22
		if not _flight_active and _launch_time > 0.0:
			_launch_time = maxf(_launch_time - delta, 0.0)
			if is_on_floor():
				if _launch_airborne and not _launch_bounced:
					_launch_bounced = true
					var feel: Resource = _hit_feel()
					velocity.y = feel.procedural_bounce
					_thud(feel.procedural_launch_speed)
				velocity.x = move_toward(velocity.x, 0.0, delta * 2.2)
				velocity.z = move_toward(velocity.z, 0.0, delta * 2.2)
			else:
				_launch_airborne = true
		else:
			velocity.x = move_toward(velocity.x, 0.0, delta * 5.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 5.0)
	else:
		if target_valid:
			var offset: Vector3 = player_target.global_position - global_position
			offset.y = 0.0
			var distance: float = offset.length()
			if _opening_controlled():
				if opening_phase == "startle":
					_turn_to_player(delta, 5.5, 19.0)
				elif opening_phase == "peek":
					_turn_to_player(delta, 3.8, 10.0)
				elif opening_phase == "approach":
					var clear_to_player: bool = _can_reach_player()
					# Leave a small hysteresis band after stopping so tiny player or
					# collision corrections do not repeatedly start a new half-step.
					_arrived = distance <= (2.18 if _arrived else 1.95) and clear_to_player
					if _pose_height > -0.10 and not _arrived:
						var route_direction: Vector3 = _path_direction(player_target.global_position, delta)
						if route_direction.length_squared() > 0.001:
							var travel_yaw: float = atan2(route_direction.x, route_direction.z)
							rotation.y = lerp_angle(rotation.y, travel_yaw, 1.0 - exp(-delta * 9.5))
							var heading_error: float = wrapf(travel_yaw - rotation.y, -PI, PI)
							var alignment: float = maxf(cos(heading_error), 0.0)
							var approach_speed: float = BOSS_APPROACH_SPEED
							if clear_to_player:
								approach_speed = minf(approach_speed, maxf((distance - 1.80) * 3.8, 0.24))
							# Turn the body into the first step before accelerating; full
							# speed at a 90-degree heading made the old approach slide.
							move = route_direction * approach_speed * alignment * alignment
						# Head follows the player while the body walks the actual route.
						_turn_to_player(delta, 0.0, 8.0)
					else:
						_turn_to_player(delta, 7.5, 10.0)
			else:
				if state == "pursue" or (state == "concern" and role == "boss"):
					_turn_to_player(delta, 5.0, 9.0)
				elif state in ["concern", "stunned", "spectate"]:
					_turn_toward(_reaction_target, delta, 2.0 if state == "stunned" else 3.5, 7.0)
				_advance_security(delta, distance, offset)
				if state == "pursue" and not _guard_push_active and (distance > 1.08 or not _can_reach_player()):
					move = _path_direction(player_target.global_position, delta) * (2.35 if role == "police" else 2.0)
				elif state == "flee":
					if not _flee_destination.is_finite():
						_flee_destination = _choose_flee_destination()
					var escape: Vector3 = _flee_destination - global_position
					escape.y = 0.0
					if escape.length() <= 0.8 and distance < 2.6:
						_flee_destination = _choose_flee_destination()
					if escape.length() > 0.6:
						move = _path_direction(_flee_destination, delta) * 2.5
						rotation.y = lerp_angle(rotation.y, atan2(move.x, move.z), minf(delta * 5.0, 1.0))
				elif state == "concern" and role == "boss" and (distance > 2.2 or not _can_reach_player()):
					move = _path_direction(player_target.global_position, delta) * 0.7
		elif response_exit.is_finite():
			_guard_push_active = false
			move = _path_direction(response_exit, delta) * (2.35 if role == "police" else 2.0)
			_turn_toward(global_position + move, delta, 5.0, 9.0)
		if boss_approaching:
			var horizontal_velocity: Vector3 = Vector3(velocity.x, 0, velocity.z)
			var acceleration: float = 9.5 if move.length_squared() < horizontal_velocity.length_squared() else 6.5
			horizontal_velocity = horizontal_velocity.move_toward(move, delta * acceleration)
			velocity.x = horizontal_velocity.x
			velocity.z = horizontal_velocity.z
		else:
			velocity.x = move_toward(velocity.x, move.x, delta * 5.0)
			velocity.z = move_toward(velocity.z, move.z, delta * 5.0)
		# Coworker poses retain their original update order and exact cues.
		if not _broad:
			_animate_pose(delta, minf(Vector2(velocity.x, velocity.z).length(), 2.0))
	var before_move: Vector3 = global_position
	move_and_slide()
	if _broad and state != "down":
		_advance_boss_gait(global_position - before_move, move, delta)
		_advance_boss_lecture_gesture(delta)
		_animate_pose(delta, minf(_walk_speed, 2.0))
	if global_position.y < -8.0:
		global_position = Vector3(_home.x, floor_height + 0.1, _home.z)
		velocity = Vector3.ZERO
	if is_instance_valid(_rig_adapter):
		_rig_adapter.update_pose(delta)
