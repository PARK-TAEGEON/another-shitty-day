extends Node3D
## An authored miniature office assembled from reusable meshes.
signal impact_event(kind: String, points: int, position: Vector3)
signal dialogue(text: String)
signal opening_began
signal scene_dialogue(speaker: String, text: String, duration: float, source: Node3D)
signal scene_speaker_invalidated(source: Node3D)
signal first_disturbance
signal player_hit(damage: float)
signal damage_assessed(target_id: String, category: String, total: int, label: String)
signal incident_event(kind: String, weight: float, at: Vector3)
signal ambient_dialogue(speaker: String, text: String, duration: float, source: Node3D)
signal scenario_event(event: Dictionary)
signal scenario_dialogue(speaker: String, text: String, duration: float, source: Node3D, priority: int)
signal responder_arrived(actor: Node3D)
signal world_resetting
signal floor_changed
const EventStream = preload("res://scripts/scenario/event_stream.gd")
const CeoScript = preload("res://scripts/scenario/ceo_npc.gd")
const PoliceScript = preload("res://scripts/scenario/police_npc.gd")
var events: RefCounted = EventStream.new()
var ceo: CharacterBody3D
var ceo_hold: Node
var scenario_time: float = 0.0
var _contact: Dictionary = {}
var _last_cause: Dictionary = {}
var _scenario_line: Dictionary = {}
var _pending_reactions: Dictionary = {}
var _scenario_spoken: Dictionary = {}
var scenario_line_can_start: Callable

const PROP_SCRIPT: Script = preload("res://scripts/prop.gd")
const NPC_SCRIPT: Script = preload("res://scripts/office_npc.gd")
const CREAM: Color = Color("eee7d6")
const TEAL: Color = Color("347879")
const INK: Color = Color("293e46")
const WOOD: Color = Color("cda577")
const ORANGE: Color = Color("dc8855")
const OFFICE_FONT = preload("res://assets/fonts/KoreanUI.ttf")

var props: Array[Node3D] = []
var npcs: Array[Node3D] = []
var player_target: Node3D
var desk_position: Vector3 = Vector3(0, 1.0, -0.5)
var _disturbed: bool = false
var _slammed: bool = false
var _level: int = 0
var _reaction_cooldown: float = 0.0
var _ambient_cooldown: float = 2.5
var _ambient_spoken: Dictionary = {}
var _furniture: Node3D
var _navigation: Array[AStarGrid2D] = [AStarGrid2D.new(), AStarGrid2D.new()]
var _navigation_obstacles: Array[Array] = [[], []]
var _navigation_footprints: Array[Array] = [[], []]
var _elevator_doors: Array[StaticBody3D] = []
var _pursuit_transfer_delay: float = 0.0
var _navigation_age: float = 0.0
var opening_coworker: Node3D
var opening_boss: Node3D
var opening_active: bool = false
var opening_started: bool = false
var opening_elapsed: float = -1.0
var _opening_index: int = 0
var _opening_invalidated: Dictionary = {}
const OPENING_BEATS: Array[Dictionary] = [
	{"at": 0.25, "actor": "coworker", "speaker": "박 대리 · 옆자리", "text": "왜 그래?", "duration": 1.35},
	{"at": 1.40, "actor": "boss", "cue": "peek"},
	{"at": 1.90, "actor": "boss", "speaker": "김 팀장 · 가림막 너머", "text": "뭐야 무슨 소리야?", "duration": 1.80},
	{"at": 3.85, "actor": "boss", "cue": "approach", "speaker": "김 팀장", "text": "이게 무슨 짓이지?", "duration": 2.20},
]
const BOSS_LECTURE_IDLE_SECONDS: float = 1.0
const BOSS_LECTURE_GAP_SECONDS: float = 0.4
const BOSS_LECTURE_LINES: Array[Dictionary] = [
	{"text": "지금 뭐 하는 거야? 여기가 집이야?", "gesture": "question", "duration": 2.8},
	{"text": "기분 나쁘다고 책상을 치면, 일이 해결돼?", "gesture": "admonish", "duration": 3.25},
	{"text": "내가 말하고 있잖아. 대답 안 해?", "gesture": "insist", "duration": 2.8},
]
var boss_lecture_index: int = 0
var boss_lecture_active: bool = false
var boss_lecture_finished: bool = false
var _boss_lecture_idle: float = 0.0
var _boss_lecture_remaining: float = 0.0
var _boss_lecture_gap: float = 0.0
var _lecture_activity_serial: int = 0
const NAV_CELL: float = 0.2
const NAV_CLEARANCE: float = 0.38
const EXECUTIVE_ELEVATION: float = 4.6
const FLOOR_HEIGHTS: Array[float] = [0.0, EXECUTIVE_ELEVATION]
const PLAYER_SPAWN: Vector3 = Vector3(0.0, 0.08, 0.65)
const CEO_DESK_POSITION: Vector3 = Vector3(2.7, EXECUTIVE_ELEVATION + 1.0, -4.2)
const NAV_REGIONS: Array[Rect2i] = [Rect2i(-40, -50, 81, 101), Rect2i(-9, -29, 50, 49)]
const EXECUTIVE_BOUNDS: Array[Rect2] = [Rect2(-1.80, -5.7, 9.795, 9.4)]
const EXECUTIVE_FLEE_POINTS: Array[Vector2] = [
	Vector2(-1.15, 2.85), Vector2(4.75, -4.85), Vector2(6.9, -4.8), Vector2(6.9, 2.8),
]
const ELEVATOR_DOOR: Vector3 = Vector3(7.91, 1.35, -1.60)
const ELEVATOR_LANDING: Vector3 = Vector3(6.65, 0.08, -1.60)
const ELEVATOR_ARRIVAL_YAWS: Array[float] = [PI * 0.50, PI * 0.82]
const ELEVATOR_RANGE: float = 2.7
const RESPONSE_ENTRIES: Array[Array] = [
	[Vector3(-0.5, 0.08, 7.2), Vector3(0.6, 0.08, 7.4), Vector3(-0.65, 0.08, 8.0)],
	[Vector3(6.9, 0.08, 2.75), Vector3(6.9, 0.08, -4.75), Vector3(6.9, 0.08, -3.5)],
]
const PURSUIT_TRANSFER_TIMEOUT: float = 5.0

func _ready() -> void:
	events.reset()
	_furniture = Node3D.new()
	_furniture.name = "OfficeSet"
	add_child(_furniture)
	_build_room()
	_build_furniture()
	_build_ceo_room()
	for floor_id: int in range(FLOOR_HEIGHTS.size()):
		_build_elevator(floor_id)
	_build_navigation()
	_build_people()

func _material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.83
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat

func _box(size: Vector3, at: Vector3, color: Color, solid: bool = false, emission: float = 0.0) -> MeshInstance3D:
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh_node.mesh = box
	mesh_node.material_override = _material(color, emission)
	mesh_node.position = at
	_furniture.add_child(mesh_node)
	if solid:
		var body: StaticBody3D = StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 15
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		mesh_node.add_child(body)
		# Only solids intersecting a standing body on that floor block navigation.
		var half_size: Vector3 = size * 0.5
		_add_navigation_bounds(at - half_size, at + half_size, _navigation_obstacles)
	return mesh_node

func floor_index(at: Vector3) -> int:
	# The split is above the office ceiling and below the executive floor slab.
	return 1 if at.y >= EXECUTIVE_ELEVATION - 0.27 else 0

func _add_navigation_bounds(lower: Vector3, upper: Vector3, footprints: Array[Array]) -> void:
	for floor_id: int in range(FLOOR_HEIGHTS.size()):
		var height: float = FLOOR_HEIGHTS[floor_id]
		if upper.y > height + 0.12 and lower.y < height + 1.75:
			var footprint: Rect2 = Rect2(Vector2(lower.x, lower.z), Vector2(upper.x - lower.x, upper.z - lower.z)).grow(NAV_CLEARANCE)
			footprints[floor_id].append(footprint)

func _build_navigation() -> void:
	for floor_id: int in range(FLOOR_HEIGHTS.size()):
		var grid: AStarGrid2D = _navigation[floor_id]
		grid.region = NAV_REGIONS[floor_id]
		grid.cell_size = Vector2.ONE * NAV_CELL
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.update()
	_refresh_navigation()

func _mark_navigation_obstacle(grid: AStarGrid2D, rect: Rect2) -> void:
	var start: Vector2i = Vector2i(ceili(rect.position.x / NAV_CELL), ceili(rect.position.y / NAV_CELL))
	var end: Vector2i = Vector2i(floori(rect.end.x / NAV_CELL), floori(rect.end.y / NAV_CELL))
	for x: int in range(start.x, end.x + 1):
		for z: int in range(start.y, end.y + 1):
			var cell: Vector2i = Vector2i(x, z)
			if grid.is_in_boundsv(cell):
				grid.set_point_solid(cell)

func _refresh_navigation() -> void:
	_navigation_footprints = _navigation_obstacles.duplicate(true)
	# Large loose props can move; refresh their current footprints periodically.
	for prop: Node3D in props:
		if not is_instance_valid(prop) or bool(prop.get("held")) or float(prop.get("mass")) < 3.0:
			continue
		for child: Node in prop.get_children():
			if not child is CollisionShape3D:
				continue
			var collider: CollisionShape3D = child as CollisionShape3D
			if not collider.shape is BoxShape3D:
				continue
			var half_size: Vector3 = (collider.shape as BoxShape3D).size * 0.5
			var lower: Vector3 = Vector3(INF, INF, INF)
			var upper: Vector3 = Vector3(-INF, -INF, -INF)
			for x: float in [-1.0, 1.0]:
				for y: float in [-1.0, 1.0]:
					for z: float in [-1.0, 1.0]:
						var point: Vector3 = collider.global_transform * (half_size * Vector3(x, y, z))
						lower = lower.min(point)
						upper = upper.max(point)
			_add_navigation_bounds(lower, upper, _navigation_footprints)
	for floor_id: int in range(FLOOR_HEIGHTS.size()):
		var grid: AStarGrid2D = _navigation[floor_id]
		grid.fill_solid_region(grid.region, false)
		for footprint: Rect2 in _navigation_footprints[floor_id]:
			_mark_navigation_obstacle(grid, footprint)
	_navigation_age = 0.65

func _nearest_navigation_cell(grid: AStarGrid2D, at: Vector3) -> Vector2i:
	var cell: Vector2i = Vector2i(roundi(at.x / NAV_CELL), roundi(at.z / NAV_CELL))
	cell.x = clampi(cell.x, grid.region.position.x, grid.region.end.x - 1)
	cell.y = clampi(cell.y, grid.region.position.y, grid.region.end.y - 1)
	if not grid.is_point_solid(cell):
		return cell
	var best: Vector2i = cell
	var best_distance: float = INF
	for radius: int in range(1, 13):
		for x: int in range(-radius, radius + 1):
			for z: int in range(-radius, radius + 1):
				if absi(x) != radius and absi(z) != radius:
					continue
				var candidate: Vector2i = cell + Vector2i(x, z)
				if not grid.is_in_boundsv(candidate) or grid.is_point_solid(candidate):
					continue
				var distance: float = Vector2(candidate.x * NAV_CELL - at.x, candidate.y * NAV_CELL - at.z).length_squared()
				if distance < best_distance:
					best_distance = distance
					best = candidate
		if best_distance < INF:
			return best
	return best

func _navigation_segment_clear(from: Vector3, to: Vector3, footprints: Array) -> bool:
	# Test the whole swept centre line against the same body-expanded footprints
	# used by A*. A clear visual ray alone would cut a shoulder through a desk.
	var origin: Vector2 = Vector2(from.x, from.z)
	var direction: Vector2 = Vector2(to.x - from.x, to.z - from.z)
	for rect: Rect2 in footprints:
		var entry: float = 0.0
		var leave: float = 1.0
		var intersects: bool = true
		for axis: int in range(2):
			if absf(direction[axis]) < 0.00001:
				if origin[axis] < rect.position[axis] or origin[axis] > rect.end[axis]:
					intersects = false
					break
			else:
				var a: float = (rect.position[axis] - origin[axis]) / direction[axis]
				var b: float = (rect.end[axis] - origin[axis]) / direction[axis]
				entry = maxf(entry, minf(a, b))
				leave = minf(leave, maxf(a, b))
				if entry > leave:
					intersects = false
					break
		if intersects:
			return false
	return true

func find_navigation_path(from: Vector3, destination: Vector3) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	var floor_id: int = floor_index(from)
	if floor_id != floor_index(destination):
		return result
	if _navigation_age <= 0.0:
		_refresh_navigation()
	var height: float = FLOOR_HEIGHTS[floor_id]
	var grid: AStarGrid2D = _navigation[floor_id]
	var footprints: Array = _navigation_footprints[floor_id]
	var start: Vector2i = _nearest_navigation_cell(grid, from)
	var end: Vector2i = _nearest_navigation_cell(grid, destination)
	if grid.is_point_solid(start) or grid.is_point_solid(end):
		return result
	var route: PackedVector2Array = grid.get_point_path(start, end)
	var candidates: PackedVector3Array = PackedVector3Array()
	for index: int in range(1, route.size()):
		candidates.append(Vector3(route[index].x, height, route[index].y))
	if candidates.is_empty() and start == end:
		candidates.append(Vector3(end.x * NAV_CELL, height, end.y * NAV_CELL))
	if candidates.is_empty():
		return result
	var exact_destination: Vector3 = Vector3(destination.x, height, destination.z)
	if _navigation_segment_clear(candidates[-1], exact_destination, footprints):
		candidates.append(exact_destination)
	# Follow a few clear corners instead of shuffling through every grid centre.
	var anchor: Vector3 = from
	var index: int = 0
	while index < candidates.size():
		var farthest: int = index
		for next: int in range(candidates.size() - 1, index, -1):
			if _navigation_segment_clear(anchor, candidates[next], footprints):
				farthest = next
				break
		result.append(candidates[farthest])
		anchor = candidates[farthest]
		index = farthest + 1
	return result

func _label(text_value: String, at: Vector3, scale_value: float, color: Color, rotation_y: float = 0.0) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text_value
	label.font = OFFICE_FONT
	label.font_size = 72
	label.pixel_size = scale_value
	label.modulate = color
	label.outline_size = 0
	label.position = at
	label.rotation.y = rotation_y
	_furniture.add_child(label)
	return label

func _light(at: Vector3, energy: float, color: Color, radius: float) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = false
	_furniture.add_child(light)

func _build_room() -> void:
	var atmosphere: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("c2cec9")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d5ded9")
	environment.ambient_light_energy = 0.48
	atmosphere.environment = environment
	_furniture.add_child(atmosphere)
	var daylight: DirectionalLight3D = DirectionalLight3D.new()
	daylight.rotation_degrees = Vector3(-48, -28, 0)
	daylight.light_color = Color("fff2d9")
	daylight.light_energy = 0.72
	daylight.shadow_enabled = true
	daylight.directional_shadow_max_distance = 25.0
	_furniture.add_child(daylight)
	_box(Vector3(16.4, 0.3, 18.4), Vector3(0, -0.17, -1), Color("6c8585"), true)
	# Subtle checker carpet and inset circulation strip.
	for x: int in range(-4, 4):
		for z: int in range(-5, 4):
			var color: Color = Color("738b8a") if (x + z) % 2 == 0 else Color("6a8282")
			_box(Vector3(1.985, 0.008, 1.985), Vector3(x * 2 + 1, -0.01, z * 2 + 1), color)
	_box(Vector3(2.25, 0.018, 5.5), Vector3(0, 0.005, 5.1), Color("acb8a6"))
	_box(Vector3(0.25, 4.3, 18), Vector3(-8.12, 2.12, -1), CREAM, true)
	_box(Vector3(0.25, 4.3, 18), Vector3(8.12, 2.12, -1), CREAM, true)
	_box(Vector3(16.4, 4.3, 0.25), Vector3(0, 2.12, -10.12), CREAM, true)
	_box(Vector3(6.5, 4.3, 0.25), Vector3(-4.75, 2.12, 8.12), CREAM, true)
	_box(Vector3(6.5, 4.3, 0.25), Vector3(4.75, 2.12, 8.12), CREAM, true)
	_box(Vector3(3.0, 0.95, 0.25), Vector3(0, 3.8, 8.12), CREAM, true)
	# A shallow entry alcove hides arriving security until it steps inside.
	_box(Vector3(3.0, 0.2, 2.2), Vector3(0, -0.05, 9), Color("d4cbb8"), true)
	# Recess the alcove sides slightly to avoid coplanar faces at the cream jambs.
	_box(Vector3(0.2, 4, 2.4), Vector3(-1.61, 1.9, 9), TEAL, true)
	_box(Vector3(0.2, 4, 2.4), Vector3(1.61, 1.9, 9), TEAL, true)
	_box(Vector3(3.4, 4, 0.2), Vector3(0, 1.9, 10.15), TEAL, true)
	_box(Vector3(16.2, 0.19, 18.2), Vector3(0, 4.22, -1), Color("d9d6c8"), true)
	# Wall skirting and the teal waist-height accent.
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.05, 0.16, 18), Vector3(side * 7.97, 0.1, -1), INK)
		_box(Vector3(0.06, 0.035, 18), Vector3(side * 7.96, 1.15, -1), WOOD)
	_box(Vector3(16, 0.16, 0.05), Vector3(0, 0.1, -9.97), INK)
	# Long daylight window overlooking a tiny stylized city silhouette.
	_box(Vector3(10.5, 2.25, 0.07), Vector3(-1.65, 2.45, -9.93), Color("accad0"), false, 0.27)
	_box(Vector3(10.65, 0.085, 0.12), Vector3(-1.65, 1.3, -9.86), INK)
	_box(Vector3(10.65, 0.085, 0.12), Vector3(-1.65, 3.59, -9.86), INK)
	for n: int in range(8):
		var px: float = -6.9 + n * 1.5
		_box(Vector3(0.075, 2.35, 0.1), Vector3(px, 2.45, -9.84), INK)
	for n: int in range(11):
		var h: float = 0.45 + float((n * 7) % 6) * 0.14
		_box(Vector3(0.53, h, 0.018), Vector3(-6.5 + n * 0.89, 1.42 + h * 0.5, -9.87), Color("829ea9"))
		for row: int in range(3):
			_box(Vector3(0.3, 0.035, 0.013), Vector3(-6.5 + n * 0.89, 1.55 + row * 0.19, -9.85), Color("bad0cd"))
	# Brand panel and discreet workplace jokes are part of the set dressing.
	_box(Vector3(3.2, 2.15, 0.085), Vector3(5.77, 2.45, -9.88), TEAL)
	_label("GOOD\nWORK.", Vector3(5.77, 2.67, -9.81), 0.009, CREAM)
	_label("HAPPINESS IS MANDATORY", Vector3(5.77, 1.77, -9.8), 0.00175, Color("c4d7c3"))
	_box(Vector3(0.065, 1.25, 2.35), Vector3(7.94, 2.25, -3.7), WOOD)
	_box(Vector3(0.072, 1.1, 2.18), Vector3(7.9, 2.25, -3.7), CREAM)
	_label("TEAMWORK\nMAKES THE\nDREAM WORK", Vector3(7.845, 2.3, -3.7), 0.0032, TEAL, -PI * 0.5)
	_label("EXIT", Vector3(0, 3.42, 7.94), 0.005, TEAL, PI)
	_box(Vector3(1.12, 0.37, 0.065), Vector3(0, 3.43, 7.99), Color("deead1"), false, 0.4)
	for px: float in [-4.5, 0.0, 4.5]:
		for pz: float in [-6.0, 1.0]:
			_box(Vector3(1.8, 0.08, 0.55), Vector3(px, 4.08, pz), Color("3c5359"))
			_box(Vector3(1.68, 0.018, 0.44), Vector3(px, 4.03, pz), Color("fff0cc"), false, 0.8)
			_light(Vector3(px, 3.65, pz), 0.8, Color("ffecd0"), 7.0)
	_light(Vector3(-3, 2.9, -7.8), 0.85, Color("d6edf0"), 8.0)

func _desk(at: Vector3, width: float = 2.3) -> void:
	_box(Vector3(width, 0.105, 1.3), at + Vector3(0, 0.98, 0), WOOD, true)
	_box(Vector3(width - 0.06, 0.028, 1.26), at + Vector3(0, 1.047, 0), Color("e5c99d"))
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.11, 0.93, 1.0), at + Vector3(side * (width * 0.5 - 0.17), 0.45, 0), CREAM, true)
	_box(Vector3(width - 0.2, 0.33, 0.06), at + Vector3(0, 0.72, -0.44), INK, true)

func _prop(type_value: String, name_value: String, at: Vector3, color: Color = ORANGE, yaw: float = 0.0) -> Node3D:
	var prop: RigidBody3D = PROP_SCRIPT.new() as RigidBody3D
	prop.set("kind", type_value)
	prop.set("display_name", name_value)
	prop.set("tint", color)
	prop.position = at
	prop.rotation.y = yaw
	add_child(prop)
	prop.connect("scored", _on_scored)
	prop.connect("noise", _on_noise)
	prop.connect("damage_assessed", _on_damage_assessed.bind(prop))
	prop.connect("incident", _on_incident)
	prop.connect("contact_started", begin_prop_contact)
	prop.connect("contact_finished", end_prop_contact)
	props.append(prop)
	return prop

func _workstation(at: Vector3, color: Color, personal: bool = false) -> void:
	_desk(at, 2.9 if personal else 2.3)
	# Keep the centre clear so the face appearing over the divider is readable.
	_prop("monitor", "모니터", at + Vector3(-0.83 if personal else -0.15, 1.19, -0.34), TEAL)
	_prop("keyboard", "키보드", at + Vector3(-0.16, 1.105, 0.34), CREAM)
	_prop("mug", "커피잔", at + Vector3(0.72, 1.19, 0.3), color)
	_prop("paper", "분기 보고서", at + Vector3(-0.88, 1.09, 0.2), CREAM)
	_prop("binder", "사내 규정집", at + Vector3(0.7, 1.11, -0.25), TEAL)
	if not personal:
		# Pulled aside while the clerk works at the front edge; leaves their capsule clear.
		_prop("chair", "사무용 의자", at + Vector3(0.86, 0.03, 1.30), color, -0.18)
	else:
		# The player begins in front of this desk; their empty chair is to the side.
		_prop("chair", "내 의자", at + Vector3(-2.85, 0.03, 2.1), TEAL, 0.55)
		_box(Vector3(0.65, 0.008, 0.43), at + Vector3(0.63, 1.066, 0.15), Color("617d76"))
		_label("EMPLOYEE OF THE MONTH*", at + Vector3(0, 0.84, 0.668), 0.00155, CREAM)

func _build_furniture() -> void:
	_workstation(Vector3(0, 0, -0.5), TEAL, true)
	_workstation(Vector3(-4.1, 0, -4.5), ORANGE)
	_workstation(Vector3(4.15, 0, -5.5), Color("779078"))
	# The opposite divider masks the seated boss; its open left end is a real route.
	_box(Vector3(2.7, 1.50, 0.13), Vector3(-0.15, 0.77, -1.46), Color("78888a"), true)
	_box(Vector3(2.76, 0.045, 0.16), Vector3(-0.15, 1.54, -1.46), Color("b9b7a7"))
	for px: float in [-1.47, 1.17]:
		_box(Vector3(0.06, 1.54, 0.17), Vector3(px, 0.77, -1.46), Color("a5aea7"))
	for n: int in range(3):
		var memo: MeshInstance3D = _box(Vector3(0.14, 0.18, 0.009), Vector3(0.18 + n * 0.21, 1.28 - n * 0.045, -1.389), Color("e8dbaa") if n % 2 == 0 else CREAM)
		memo.rotation.z = (n - 1) * 0.08
	# The nearby colleague has a visible work surface rather than waiting in an aisle.
	_desk(Vector3(3.05, 0, -1.95), 1.85)
	_prop("monitor", "동료의 모니터", Vector3(3.13, 1.19, -2.25), Color("718789"))
	_prop("keyboard", "동료의 키보드", Vector3(2.58, 1.105, -1.52), CREAM, -0.2)
	_prop("paper", "검토 중인 서류", Vector3(3.5, 1.09, -1.61), CREAM)
	# Freestanding dividers leave a clear central circulation route.
	_box(Vector3(2.9, 1.28, 0.13), Vector3(-4.15, 0.64, -5.3), TEAL, true)
	_box(Vector3(2.9, 0.055, 0.15), Vector3(-4.15, 1.3, -5.3), WOOD)
	_box(Vector3(2.9, 1.28, 0.13), Vector3(4.15, 0.64, -6.3), TEAL, true)
	_box(Vector3(2.9, 0.055, 0.15), Vector3(4.15, 1.3, -6.3), WOOD)
	# Shared printer / credenza.
	_box(Vector3(2.6, 0.89, 0.66), Vector3(-6.55, 0.46, -8.9), CREAM, true)
	_box(Vector3(2.7, 0.085, 0.75), Vector3(-6.55, 0.94, -8.9), WOOD, true)
	for px: float in [-7.34, -6.53, -5.72]:
		_box(Vector3(0.77, 0.74, 0.025), Vector3(px, 0.46, -8.55), Color("d9d6c6"))
		_box(Vector3(0.15, 0.025, 0.05), Vector3(px, 0.75, -8.52), INK)
	_prop("printer", "프린터", Vector3(-6.5, 1.22, -8.85))
	_prop("paper", "추가 보고서", Vector3(-7.48, 1.01, -8.82))
	# Lounge provides a contrasting quiet area behind the starting desk.
	_box(Vector3(2.45, 0.43, 0.95), Vector3(-5.8, 0.32, 5.0), TEAL, true)
	_box(Vector3(2.45, 0.74, 0.2), Vector3(-5.8, 0.71, 5.43), TEAL, true)
	for px: float in [-7.01, -4.59]:
		_box(Vector3(0.2, 0.68, 0.96), Vector3(px, 0.5, 5), TEAL, true)
	_box(Vector3(1.18, 0.075, 0.68), Vector3(-5.8, 0.49, 3.53), WOOD, true)
	for px: float in [-6.2, -5.4]:
		_box(Vector3(0.055, 0.46, 0.48), Vector3(px, 0.24, 3.53), INK, true)
	_prop("mug", "식은 커피", Vector3(-6.05, 0.65, 3.54), CREAM)
	_prop("binder", "사보", Vector3(-5.55, 0.57, 3.48), ORANGE, 0.24)
	# Reception cabinet, bulletin board and an oversized decorative plant.
	_box(Vector3(2.8, 1.15, 0.68), Vector3(5.8, 0.6, 6.75), TEAL, true)
	_box(Vector3(2.9, 0.075, 0.77), Vector3(5.8, 1.2, 6.75), WOOD, true)
	_prop("plant", "책상 화분", Vector3(6.65, 1.37, 6.75), CREAM)
	_prop("binder", "안전 수칙", Vector3(5.0, 1.29, 6.77), ORANGE)
	_box(Vector3(2.6, 1.3, 0.07), Vector3(5.8, 2.48, 7.94), WOOD)
	_box(Vector3(2.43, 1.15, 0.08), Vector3(5.8, 2.48, 7.88), Color("a78d67"))
	for n: int in range(5):
		var paper: MeshInstance3D = _box(Vector3(0.32, 0.47, 0.012), Vector3(4.91 + n * 0.45, 2.5 + (0.1 if n % 2 == 0 else -0.12), 7.829), CREAM if n % 2 == 0 else Color("e5bd75"))
		paper.rotation.z = float(n - 2) * 0.045
	_prop("plant", "사무실 화분", Vector3(6.8, 0.15, -8.6), ORANGE)
	_prop("plant", "휴게실 화분", Vector3(-7.1, 0.15, 1.6), ORANGE)
	# Low storage units give depth to the office without blocking the first view.
	_box(Vector3(0.6, 1.9, 1.8), Vector3(7.45, 0.96, 0.3), INK, true)
	for y: float in [0.25, 0.83, 1.4]:
		_box(Vector3(0.64, 0.045, 1.85), Vector3(7.45, y, 0.3), WOOD)
		for n: int in range(6):
			_box(Vector3(0.38, 0.4, 0.13), Vector3(7.34, y + 0.24, -0.35 + n * 0.19), TEAL if n % 2 == 0 else ORANGE)
	_build_office_zones()

func _nameplate(text_value: String, at: Vector3, color: Color = TEAL) -> void:
	_box(Vector3(0.75, 0.19, 0.06), at, color)
	_label(text_value, at + Vector3(0, 0, 0.036), 0.0018, CREAM)

func _build_office_zones() -> void:
	# All new solids stay behind/right of the accepted opening corridor.
	_nameplate("정 인턴", Vector3(-4.82, 1.17, -3.96), ORANGE)
	_nameplate("이 사원", Vector3(3.43, 1.17, -4.96))
	_box(Vector3(1.65, 0.40, 0.05), Vector3(-6.5, 2.30, -9.79), TEAL)
	_label("문서 · 복사", Vector3(-6.5, 2.30, -9.754), 0.003, CREAM)
	_box(Vector3(0.56, 0.26, 0.38), Vector3(-5.72, 1.12, -8.89), Color("688880"))
	_label("용지", Vector3(-5.72, 1.14, -8.688), 0.00135, CREAM)
	# A low partition, meeting table and whiteboard make a small shared meeting bay.
	_box(Vector3(4.3, 0.014, 4.5), Vector3(4.72, 0.022, 2.6), Color("89978b"))
	_box(Vector3(0.10, 1.18, 3.5), Vector3(2.46, 0.61, 2.4), Color("aeb8a7"), true)
	_box(Vector3(0.15, 0.05, 3.55), Vector3(2.46, 1.225, 2.4), WOOD)
	_box(Vector3(2.65, 0.11, 1.65), Vector3(4.65, 0.94, 2.27), WOOD, true)
	_box(Vector3(2.57, 0.023, 1.58), Vector3(4.65, 1.007, 2.27), Color("e7ceaa"))
	for px: float in [3.55, 5.75]:
		for pz: float in [1.69, 2.85]:
			_box(Vector3(0.10, 0.90, 0.10), Vector3(px, 0.45, pz), INK, true)
	_prop("paper", "회의 자료", Vector3(4.33, 1.06, 2.78), CREAM, 0.15)
	_prop("binder", "회의록", Vector3(5.32, 1.065, 2.05), TEAL, -0.12)
	_prop("mug", "회의실 커피잔", Vector3(5.46, 1.16, 2.78), ORANGE)
	_prop("chair", "회의실 의자", Vector3(5.95, 0.03, 3.82), Color("a5765a"), -0.24)
	_prop("chair", "회의실 의자", Vector3(4.23, 0.03, 0.79), TEAL, PI)
	_box(Vector3(0.07, 1.36, 2.85), Vector3(7.86, 2.30, 2.75), INK)
	_box(Vector3(0.079, 1.23, 2.69), Vector3(7.80, 2.30, 2.75), Color("eeeede"))
	_label("진행 상황 공유\n\n오늘도 정상 진행 중", Vector3(7.745, 2.39, 2.75), 0.0028, TEAL, -PI * 0.5)
	_box(Vector3(0.12, 0.06, 2.7), Vector3(7.76, 1.64, 2.75), WOOD)
	# Reading corners and work zones use the same palette, without extra named cast.
	_box(Vector3(1.55, 0.32, 0.05), Vector3(5.60, 3.58, 7.78), TEAL)
	_label("공용 공간", Vector3(5.6, 3.58, 7.743), 0.00255, CREAM, PI)
	_box(Vector3(2.65, 0.74, 0.48), Vector3(-5.8, 0.39, 6.75), CREAM, true)
	_box(Vector3(2.72, 0.08, 0.55), Vector3(-5.8, 0.80, 6.75), WOOD, true)
	_box(Vector3(0.5, 0.66, 0.38), Vector3(-6.25, 1.16, 6.75), INK)
	_box(Vector3(0.35, 0.22, 0.035), Vector3(-6.25, 1.22, 6.541), TEAL, false, 0.16)
	_prop("mug", "휴게실 머그잔", Vector3(-5.35, 0.98, 6.69), ORANGE)
	_label("잠깐만 부탁해요", Vector3(-5.8, 2.06, 7.80), 0.0031, TEAL, PI)

func _npc(name_value: String, role_value: String, at: Vector3, color: Color, yaw: float = 0.0, opening_role: String = "", profile: Dictionary = {}) -> Node3D:
	var npc: CharacterBody3D = (CeoScript if role_value == "ceo" else (PoliceScript if role_value == "police" else NPC_SCRIPT)).new() as CharacterBody3D
	npc.set("display_name", name_value)
	npc.set("role", role_value)
	npc.set("opening_role", opening_role)
	npc.set("suit_color", color)
	for key: String in profile:
		npc.set(key, profile[key])
	if role_value in ["guard", "police"]:
		npc.set("affiliation", "security")
		npc.set("work_activity", "idle")
	if role_value == "coward":
		npc.set("skin_color", Color("ab795b"))
	npc.set("player_target", player_target if is_instance_valid(player_target) and floor_index(at) == floor_index(player_target.global_position) else null)
	_configure_actor_floor(npc, floor_index(at))
	npc.set("navigation_provider", Callable(self, "find_navigation_path"))
	npc.position = at
	npc.rotation.y = yaw
	add_child(npc)
	npc.connect("scored", _on_scored)
	npc.connect("said", _on_said.bind(npc))
	npc.connect("player_hit", _on_player_hit)
	npc.connect("noise", _on_noise)
	npc.connect("damage_assessed", _on_damage_assessed.bind(npc))
	npc.connect("incident", _on_incident)
	if role_value == "police":
		npc.set("hold_provider", Callable(self, "_hold_relation"))
		npc.connect("hold_observed", _on_police_observed)
	npcs.append(npc)
	return npc

func _build_people() -> void:
	opening_boss = _npc("김 팀장", "boss", Vector3(-0.65, 0.02, -2.15), Color("e7dfcc"), 0.0, "boss", {"affiliation": "department", "personality": "boss", "work_activity": "papers", "work_line": "시킨 대로만 하지 말고, 생각을 좀 해.", "reaction_line": "지금 뭐 하는 거야?"})
	opening_coworker = _npc("박 대리", "observer", Vector3(1.78, 0.02, -1.05), Color("6f9995"), 2.7, "coworker", {"affiliation": "department", "personality": "sarcastic", "work_activity": "typing", "work_line": "오, 오늘은 제시간에 끝내게?", "reaction_line": "야, 진짜 왜 그래?"})
	_npc("이 사원", "coward", Vector3(4.15, 0.06, -4.22), Color("789079"), PI, "", {"affiliation": "department", "personality": "rude", "work_activity": "typing", "work_line": "마무리는 선배님이 좀 해주세요.", "reaction_line": "저는 시키는 대로만 했는데요!"})
	_npc("최 과장", "observer", Vector3(-5.7, 0.06, 4.20), Color("4e747d"), 1.1, "", {"affiliation": "department", "personality": "dumping", "work_activity": "coffee", "work_line": "네가 제일 빠르잖아. 이것도 부탁할게.", "reaction_line": "잠깐, 일단 진정 좀 해."})
	_npc("정 인턴", "observer", Vector3(-4.1, 0.06, -3.25), Color("c48754"), PI, "", {"affiliation": "department", "personality": "intern", "work_activity": "papers", "work_line": "이건 AI로 하면 금방 아닌가요?", "reaction_line": "저 오늘 처음 왔는데…"})
	_npc("타 부서 직원 · 복사실", "coward", Vector3(-6.35, 0.06, -7.92), Color("a89b81"), PI, "", {"affiliation": "other", "personality": "fearful", "work_activity": "copy", "reaction_line": "왜 저래… 가까이 가지 마."})
	_npc("타 부서 직원 · 회의실", "observer", Vector3(4.45, 0.06, 3.75), Color("897887"), PI, "", {"affiliation": "other", "personality": "spectator", "work_activity": "papers", "reaction_line": "어… 저쪽 무슨 일이야?"})

func slam_desk(origin: Vector3, strength: float = 1.0) -> bool:
	if origin.distance_to(CEO_DESK_POSITION) < 2.15:
		var object: Node3D
		for item: Node3D in props:
			if is_instance_valid(item) and item.get("display_name") == "대표 기념패":
				object = item
				break
		if not is_instance_valid(object):
			return false
		begin_player_contact("slam", object)
		object.receive_hit(Vector3.UP * 2.0, object.global_position, 8.0)
		incident_event.emit("DESK_SLAM", 0.75, object.global_position)
		_disturb(object.global_position, 1.0)
		end_player_contact("slam", object)
		return true
	if origin.distance_to(desk_position) > 2.15:
		return false
	var desk_target: Node3D = props[0]
	begin_player_contact("slam", desk_target)
	for prop: Node3D in props:
		if not is_instance_valid(prop) or bool(prop.get("held")):
			continue
		var at: Vector3 = prop.global_position
		if at.distance_to(desk_position) < 1.9 and at.y > 0.85:
			var outward: Vector3 = at - desk_position
			outward.y = 0.0
			var rb: RigidBody3D = prop as RigidBody3D
			if rb.has_method("mark_player_impulse"):
				rb.call("mark_player_impulse")
			rb.sleeping = false
			rb.apply_central_impulse((outward * 0.65 + Vector3.UP * 2.2) * strength * sqrt(rb.mass))
			rb.apply_torque_impulse(Vector3(0.24, 0.12, -0.2) * strength)
	if not _slammed:
		_slammed = true
		if not _disturbed:
			_start_opening_scene()
		impact_event.emit("DESK SLAM", 75, desk_position)
	incident_event.emit("DESK_SLAM", 0.75, desk_position)
	_disturb(desk_position, 1.0)
	end_player_contact("slam", desk_target)
	return true

func _actor_available(actor: Node3D) -> bool:
	return is_instance_valid(actor) and actor.is_inside_tree() and bool(actor.call("can_opening_react"))

func _actor_living(actor: Node3D) -> bool:
	return is_instance_valid(actor) and actor.is_inside_tree() and str(actor.get("state")) != "down" and float(actor.get("health")) > 0.0

func _start_opening_scene() -> void:
	if opening_started:
		return
	opening_started = true
	opening_active = true
	opening_elapsed = 0.0
	_opening_index = 0
	_opening_invalidated.clear()
	_reset_boss_lecture()
	opening_began.emit()
	if _actor_available(opening_coworker):
		opening_coworker.call("interrupt_work")
		opening_coworker.call("opening_cue", "startle")
		record_scenario_fact(_contact, "npc_reaction", opening_coworker)
	if _actor_available(opening_boss):
		opening_boss.call("opening_cue", "listen")

func _advance_opening_scene(delta: float) -> void:
	if not opening_active:
		return
	opening_elapsed += delta
	for actor: Node3D in [opening_coworker, opening_boss]:
		if is_instance_valid(actor) and not _actor_available(actor) and not _opening_invalidated.has(actor.get_instance_id()):
			_opening_invalidated[actor.get_instance_id()] = true
			scene_speaker_invalidated.emit(actor)
	while _opening_index < OPENING_BEATS.size() and opening_elapsed >= float(OPENING_BEATS[_opening_index]["at"]):
		var beat: Dictionary = OPENING_BEATS[_opening_index]
		_opening_index += 1
		var actor: Node3D = opening_coworker if beat["actor"] == "coworker" else opening_boss
		if not _actor_available(actor):
			continue
		if beat.has("cue"):
			if str(beat["cue"]) == "peek":
				actor.call("interrupt_work")
			actor.call("opening_cue", str(beat["cue"]))
		if beat.has("text"):
			scene_dialogue.emit(str(beat["speaker"]), str(beat["text"]), float(beat["duration"]), actor)
	if opening_elapsed >= 6.5:
		opening_active = false
		if _actor_available(opening_coworker):
			opening_coworker.call("opening_cue", "release")

func _reset_boss_lecture() -> void:
	boss_lecture_index = 0
	boss_lecture_active = false
	boss_lecture_finished = false
	_boss_lecture_idle = 0.0
	_boss_lecture_remaining = 0.0
	_boss_lecture_gap = 0.0
	_lecture_activity_serial = int(player_target.get("activity_serial")) if is_instance_valid(player_target) and player_target.has_method("is_idle_for_boss_lecture") else 0

func notify_player_activity(_kind: String) -> void:
	# Main connects the immediate input signal so even a missed punch cuts the
	# caption before its delayed hit check. The serial also supports standalone worlds.
	if is_instance_valid(player_target) and player_target.has_method("is_idle_for_boss_lecture"):
		_lecture_activity_serial = int(player_target.get("activity_serial"))
	if opening_started and not boss_lecture_finished:
		_interrupt_boss_lecture()

func _interrupt_boss_lecture() -> void:
	if boss_lecture_active and is_instance_valid(opening_boss):
		opening_boss.call("stop_boss_lecture_gesture")
		scene_speaker_invalidated.emit(opening_boss)
	boss_lecture_active = false
	_boss_lecture_remaining = 0.0
	_boss_lecture_idle = 0.0
	_boss_lecture_gap = 0.0
	# A spoken or interrupted sentence is consumed, never replayed on every stop.
	if boss_lecture_index >= BOSS_LECTURE_LINES.size():
		boss_lecture_finished = true

func _cancel_boss_lecture() -> void:
	_interrupt_boss_lecture()
	boss_lecture_finished = true

func _advance_boss_lecture(delta: float) -> void:
	if not opening_started or boss_lecture_finished:
		return
	if not _actor_available(opening_boss) or _level >= 2 or not is_instance_valid(player_target):
		_cancel_boss_lecture()
		return
	if str(opening_boss.get("opening_phase")) in ["released", "cancelled"]:
		_cancel_boss_lecture()
		return
	# The three accepted opening lines own their original timing and framing.
	if opening_active or not player_target.has_method("is_idle_for_boss_lecture"):
		return
	if int(player_target.get("activity_serial")) != _lecture_activity_serial:
		notify_player_activity("action")
	if not bool(player_target.call("is_idle_for_boss_lecture")) or not bool(opening_boss.call("can_boss_lecture")):
		_interrupt_boss_lecture()
		return
	if boss_lecture_active:
		_boss_lecture_remaining = maxf(0.0, _boss_lecture_remaining - delta)
		if _boss_lecture_remaining <= 0.0:
			opening_boss.call("stop_boss_lecture_gesture")
			scene_speaker_invalidated.emit(opening_boss)
			boss_lecture_active = false
			_boss_lecture_gap = BOSS_LECTURE_GAP_SECONDS
			boss_lecture_finished = boss_lecture_index >= BOSS_LECTURE_LINES.size()
		return
	_boss_lecture_idle += delta
	_boss_lecture_gap = maxf(0.0, _boss_lecture_gap - delta)
	if _boss_lecture_idle < BOSS_LECTURE_IDLE_SECONDS or _boss_lecture_gap > 0.0:
		return
	var beat: Dictionary = BOSS_LECTURE_LINES[boss_lecture_index]
	boss_lecture_index += 1
	boss_lecture_active = true
	_boss_lecture_remaining = float(beat["duration"])
	opening_boss.call("begin_boss_lecture_gesture", str(beat["gesture"]), _boss_lecture_remaining)
	scene_dialogue.emit("김 팀장", str(beat["text"]), _boss_lecture_remaining, opening_boss)

func cancel_opening_scene() -> void:
	_cancel_boss_lecture()
	opening_active = false
	_opening_index = OPENING_BEATS.size()
	for actor: Node3D in [opening_coworker, opening_boss]:
		if is_instance_valid(actor):
			scene_speaker_invalidated.emit(actor)
			if _actor_available(actor) and str(actor.get("opening_phase")) != "work":
				actor.call("interrupt_work")
				actor.call("opening_cue", "release")

func _disturb(at: Vector3, strength: float) -> void:
	if not _disturbed:
		_disturbed = true
		first_disturbance.emit()
	if _reaction_cooldown > 0.0 and strength < 1.8:
		return
	_reaction_cooldown = 0.6
	var radius: float = 4.8 + clampf(strength, 0.0, 3.0) * 2.7
	for npc: Node3D in npcs:
		if not is_instance_valid(npc) or floor_index(at) != floor_index(npc.global_position):
			continue
		var distance: float = npc.global_position.distance_to(at)
		if distance > radius:
			continue
		var ear: Vector3 = npc.global_position + Vector3.UP * 1.5
		var source: Vector3 = at + Vector3.UP * 0.25
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(source, ear, 1)
		var obscured: bool = not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
		if obscured and distance > radius * 0.8:
			continue
		npc.call("react", at, strength * (0.75 if obscured else 1.0))
		if not _contact.is_empty() and bool(npc.get("_reaction_pending")):
			_pending_reactions[npc.get_instance_id()] = {"actor": npc, "origin": _contact.duplicate(true), "expires": scenario_time + 1.5}

func _on_damage_assessed(category: String, total: int, label_text: String, source: Node3D) -> void:
	if is_instance_valid(source):
		damage_assessed.emit(str(source.get_instance_id()), category, total, label_text)
		if category == "work" and not _contact.is_empty():
			record_scenario_fact(_contact, "work_interrupted", source)

func _on_incident(kind: String, weight: float, at: Vector3) -> void:
	incident_event.emit(kind, weight, at)
	_disturb(at, 2.5 if kind == "ASSAULT" else 1.5)

func _on_scored(kind: String, points: int, at: Vector3) -> void:
	impact_event.emit(kind, points, at)
	_disturb(at, 2.0)

func _on_noise(at: Vector3, strength: float) -> void:
	if strength > 0.25:
		_disturb(at, strength)

func _on_said(text_value: String, source: Node3D) -> void:
	_record_applied_reaction(source)
	# The accepted opening has a separate priority channel; drop stale background lines.
	if opening_active or boss_lecture_active or not _actor_living(source):
		return
	var words: String = text_value
	if "|" in words:
		words = words.substr(words.find("|") + 1).strip_edges()
	ambient_dialogue.emit(str(source.get("display_name")), words, 2.8, source)
	if source.get("affiliation") == "security" and not _last_cause.is_empty():
		record_scenario_fact(_last_cause, "guard_warning" if source.get("role") == "guard" else "responder_warning", source)

func _advance_work_dialogue(delta: float) -> void:
	if _disturbed or not is_instance_valid(player_target) or not bool(player_target.get("enabled")):
		return
	_ambient_cooldown = maxf(0.0, _ambient_cooldown - delta)
	if _ambient_cooldown > 0.0:
		return
	var nearest: Node3D
	var best_distance: float = INF
	for npc: Node3D in npcs:
		if not _actor_living(npc) or _ambient_spoken.has(npc.get_instance_id()):
			continue
		if str(npc.get("work_line")) == "" or not bool(npc.call("is_working")):
			continue
		var distance: float = npc.global_position.distance_to(player_target.global_position)
		if distance < 3.4 and distance < best_distance:
			nearest = npc
			best_distance = distance
	if nearest != null:
		_ambient_spoken[nearest.get_instance_id()] = true
		if nearest.has_method("speak_work_line"):
			nearest.call("speak_work_line")
		else:
			ambient_dialogue.emit(str(nearest.get("display_name")), str(nearest.get("work_line")), 2.8, nearest)
		_ambient_cooldown = 5.0

func _on_player_hit(damage: float) -> void:
	player_hit.emit(damage)

func escalate(level: int) -> void:
	if level <= _level:
		return
	var previous: int = _level
	_level = level
	if level >= 2:
		cancel_opening_scene()
	if level >= 2 and previous < 2:
		var guard: Node3D = _npc("사내 경비", "guard", _response_entry(0), Color("8c947b"), PI)
		if is_instance_valid(guard):
			damage_assessed.emit("dispatch:guard", "response", 100000, "사내 경비 투입")
	if level >= 3 and previous < 3:
		var entry: Vector3 = _response_entry(1)
		var police: Node3D = _npc("출동 경찰", "police", entry, Color("354f70"), 0.0 if floor_index(entry) == 1 else PI)
		if is_instance_valid(police):
			damage_assessed.emit("dispatch:police", "response", 500000, "경찰 출동 · 사건 처리")
			record_scenario_fact(_last_cause, "police_arrived", police)
			responder_arrived.emit(police)
	if level >= 4 and previous < 4:
		var entry: Vector3 = _response_entry(2)
		var backup: Node3D = _npc("지원 경찰", "police", entry, Color("354f70"), 0.0 if floor_index(entry) == 1 else PI)
		if is_instance_valid(backup):
			damage_assessed.emit("dispatch:reinforcement", "response", 800000, "경찰 추가 출동")

func _physics_process(delta: float) -> void:
	scenario_time += delta
	_advance_scenario_line()
	for id: int in _pending_reactions.keys():
		var item: Dictionary = _pending_reactions[id]
		if not is_instance_valid(item["actor"]):
			_pending_reactions.erase(id)
			continue
		var actor: Node3D = item["actor"]
		if not _actor_living(actor) or scenario_time > float(item["expires"]):
			_pending_reactions.erase(id)
		elif not bool(actor.get("_reaction_pending")) and float(actor.get("_reaction_age")) < 0.10:
			_record_applied_reaction(actor)
	_reaction_cooldown = maxf(0.0, _reaction_cooldown - delta)
	_navigation_age = maxf(0.0, _navigation_age - delta)
	_update_actor_targets(delta)
	_advance_opening_scene(delta)
	_advance_boss_lecture(delta)
	_advance_work_dialogue(delta)

func _build_ceo_room() -> void:
	var top: Vector3 = Vector3.UP * EXECUTIVE_ELEVATION
	_box(Vector3(10.1, 0.3, 9.6), top + Vector3(3.1, -0.17, -1), Color("6a7068"), true)
	_box(Vector3(0.25, 4.3, 9.6), top + Vector3(8.12, 2.12, -1), TEAL, true)
	_box(Vector3(0.2, 4.3, 9.6), top + Vector3(-1.9, 2.12, -1), CREAM, true)
	_box(Vector3(10.1, 4.3, 0.2), top + Vector3(3.1, 2.12, -5.8), CREAM, true)
	_box(Vector3(10.1, 4.3, 0.2), top + Vector3(3.1, 2.12, 3.8), TEAL, true)
	_box(Vector3(10.1, 0.19, 9.6), top + Vector3(3.1, 4.22, -1), CREAM, true)
	# The east corridor connects the lift to a wide opening in the executive office.
	_box(Vector3(0.18, 4.3, 4.6), top + Vector3(5.85, 2.12, -3.5), CREAM, true)
	_box(Vector3(0.18, 4.3, 2.6), top + Vector3(5.85, 2.12, 2.5), CREAM, true)
	_box(Vector3(0.18, 1.15, 2.4), top + Vector3(5.85, 3.69, 0), TEAL, true)
	_box(Vector3(0.27, 0.22, 2.55), top + Vector3(5.85, 3.12, 0), INK)
	_label("대표이사", top + Vector3(6.0, 3.11, 0), 0.005, CREAM, PI * 0.5)
	_box(Vector3(2.02, 0.014, 9.3), top + Vector3(6.96, -0.008, -1), Color("acb8a6"))
	_box(Vector3(3.5, 0.02, 2.7), top + Vector3(2.7, 0.005, -3.5), Color("87816b"))
	_desk(CEO_DESK_POSITION - Vector3.UP, 3.0)
	_desk(top + Vector3(-0.1, 0, -2.5), 1.7)
	_desk(top + Vector3(3.3, 0, 2.4), 1.7)
	_box(Vector3(5.4, 1.65, 0.05), top + Vector3(2.7, 2.65, -5.67), Color("accad0"), false, 0.27)
	for x: float in [0.03, 1.8, 3.6, 5.37]:
		_box(Vector3(0.055, 1.70, 0.075), top + Vector3(x, 2.65, -5.62), INK)
	_box(Vector3(5.44, 0.06, 0.09), top + Vector3(2.7, 1.80, -5.61), WOOD)
	_label("결재는 여기서. 책임은 현장에서.", top + Vector3(2.7, 1.55, -5.66), 0.003, TEAL)
	_label("공용 서류", top + Vector3(-0.1, 1.55, -2.5), 0.0028, CREAM)
	_label("방문객", top + Vector3(3.3, 1.55, 2.4), 0.0028, CREAM)
	_light(top + Vector3(2.0, 3.7, -1.0), 1.35, Color("ffecd0"), 8.0)
	_light(top + Vector3(6.9, 3.65, -1.5), 0.9, Color("ffecd0"), 6.5)
	_prop("binder", "대표 기념패", top + Vector3(2.0, 1.13, -4.0), ORANGE)
	_prop("paper", "대표 결재함", top + Vector3(3.4, 1.1, -4.0), CREAM)
	_prop("chair", "대표 의자", top + Vector3(3.5, 0.04, -2.8), INK, PI)
	_prop("paper", "밀린 공용 서류", top + Vector3(-0.1, 1.1, -2.5), CREAM)
	_prop("mug", "대표 커피잔", top + Vector3(3.3, 1.16, 2.4), ORANGE)
	ceo = _npc("사장", "ceo", top + Vector3(2.7, 0.04, -2.8), Color("634e46"), PI, "", {"affiliation": "executive", "personality": "dumping", "health": 90.0, "work_activity": "papers"})

func _build_elevator(floor_id: int) -> void:
	var base: Vector3 = Vector3.UP * FLOOR_HEIGHTS[floor_id]
	var door: MeshInstance3D = _box(Vector3(0.12, 2.70, 1.60), base + ELEVATOR_DOOR, INK, true)
	_elevator_doors.append(door.get_child(0) as StaticBody3D)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.09, 2.56, 0.74), base + ELEVATOR_DOOR + Vector3(-0.04, -0.025, side * 0.38), Color("638482"))
		_box(Vector3(0.18, 2.75, 0.075), base + ELEVATOR_DOOR + Vector3(-0.06, 0.03, side * 0.80), WOOD)
	_box(Vector3(0.22, 0.45, 1.83), base + Vector3(7.84, 2.93, -1.60), INK)
	_label("엘리베이터   %dF" % (floor_id + 1), base + Vector3(7.72, 2.93, -1.60), 0.004, CREAM, -PI * 0.5)
	_box(Vector3(0.12, 0.28, 0.16), base + Vector3(7.87, 1.28, -2.48), INK)
	_box(Vector3(0.028, 0.065, 0.088), base + Vector3(7.799, 1.31, -2.48), Color("ffd89b"), false, 1.0)
	_box(Vector3(1.2, 0.013, 1.65), base + Vector3(7.32, 0.005, -1.60), WOOD)

func elevator_hint(body: CharacterBody3D, collider: Object) -> String:
	var floor_id: int = floor_index(body.global_position)
	if collider != _elevator_doors[floor_id]:
		return ""
	return "엘리베이터  ·  E %s" % ("2층 사장실" if floor_id == 0 else "1층 사무실")

func try_use_elevator(body: CharacterBody3D, collider: Object) -> bool:
	if body != player_target or not body.enabled or get_tree().paused or elevator_hint(body, collider).is_empty():
		return false
	if (is_instance_valid(ceo_hold) and ceo_hold.active) or is_instance_valid(body.held_prop):
		return false
	var floor_id: int = floor_index(body.global_position)
	var door_at: Vector3 = ELEVATOR_DOOR + Vector3.UP * FLOOR_HEIGHTS[floor_id]
	if (body.global_position + Vector3.UP * ELEVATOR_DOOR.y).distance_to(door_at) > ELEVATOR_RANGE + 0.22:
		return false
	var destination: int = 1 - floor_id
	var landing: Vector3 = ELEVATOR_LANDING + Vector3.UP * FLOOR_HEIGHTS[destination]
	if not _entry_clear(landing, body):
		return false
	body.place_at(landing, ELEVATOR_ARRIVAL_YAWS[destination], 0.0)
	if opening_started:
		cancel_opening_scene()
	_pursuit_transfer_delay = PURSUIT_TRANSFER_TIMEOUT
	floor_changed.emit()
	return true

func _entry_clear(at: Vector3, except: CharacterBody3D = null) -> bool:
	# Test the full standing volume, including loose props and other actors.
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.85
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform.origin = at + Vector3.UP * capsule.height * 0.5
	query.collision_mask = 7 | 8
	if is_instance_valid(except):
		query.exclude = [except.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _response_entry(slot: int) -> Vector3:
	var floor_id: int = floor_index(player_target.global_position) if is_instance_valid(player_target) else 0
	var at: Vector3 = RESPONSE_ENTRIES[floor_id][slot]
	return at + Vector3.UP * FLOOR_HEIGHTS[floor_id]

func _configure_actor_floor(npc: Node3D, floor_id: int) -> void:
	npc.floor_height = FLOOR_HEIGHTS[floor_id]
	if floor_id == 1:
		npc.flight_bounds = EXECUTIVE_BOUNDS
		npc.flee_points = EXECUTIVE_FLEE_POINTS
	else:
		npc.flight_bounds = NPC_SCRIPT.OFFICE_FLIGHT_BOUNDS
		npc.flee_points = NPC_SCRIPT.OFFICE_FLEE_POINTS

func _update_actor_targets(delta: float) -> void:
	if not is_instance_valid(player_target):
		return
	_pursuit_transfer_delay = maxf(0.0, _pursuit_transfer_delay - delta)
	var target_floor: int = floor_index(player_target.global_position)
	var used_entries: Array[Vector3] = []
	for npc: Node3D in npcs:
		if not is_instance_valid(npc):
			continue
		var floor_id: int = floor_index(npc.global_position)
		npc.player_target = player_target if floor_id == target_floor else null
		npc.response_exit = Vector3.INF
		if floor_id == target_floor or npc.get("affiliation") != "security" or not _actor_living(npc):
			continue
		var exit: Vector3 = ELEVATOR_LANDING + Vector3.UP * FLOOR_HEIGHTS[floor_id]
		npc.response_exit = exit
		# Walk up to the lift. If congestion prevents that, re-enter through a
		# clear dispatch point upstairs/downstairs with the same actor and health.
		if npc.global_position.distance_to(exit) > 0.85 and _pursuit_transfer_delay > 0.0:
			continue
		for slot: int in range(RESPONSE_ENTRIES[target_floor].size()):
			var at: Vector3 = _response_entry(slot)
			if at in used_entries or not _entry_clear(at, npc):
				continue
			npc.enter_response_floor(at)
			_configure_actor_floor(npc, target_floor)
			npc.player_target = player_target
			used_entries.append(at)
			break

func record_scenario_fact(origin: Dictionary, fact: String, target: Node3D = null, extra: Dictionary = {}) -> Dictionary:
	var event: Dictionary = events.fact(origin, fact, target, extra)
	if not event.is_empty():
		scenario_event.emit(event)
	return event

func begin_player_contact(kind: String, target: Node3D) -> void:
	_contact = events.action(kind, target, scenario_time)
	if not _contact.is_empty():
		_contact["state_before"] = _target_state(target)
		if target.has_method("mark_player_impulse") and kind in ["punch", "kick", "throw"]:
			target.set_meta("scenario_origin", _contact.duplicate(true))
			target.set_meta("scenario_origin_time", scenario_time)
			target.set_meta("scenario_hops", 0)

func _target_state(target: Node3D) -> Dictionary:
	if target.has_method("set_held"):
		return {"damage": target.get("damage_stage"), "held": target.get("held"), "position": target.global_position}
	if target.has_method("receive_hit"):
		return {"state": target.get("state"), "health": target.get("health"), "position": target.global_position}
	return {"position": target.global_position}

func end_player_contact(kind: String, target: Node3D) -> void:
	if _contact.is_empty() or not is_instance_valid(target):
		_contact.clear()
		return
	var origin: Dictionary = _contact.duplicate(true)
	var fact: String = "actor_held" if kind == "actor_grab" else ("action_contact" if kind in ["punch", "kick", "slam"] else "prop_manipulated")
	var event: Dictionary = record_scenario_fact(origin, fact, target, {"state_after": _target_state(target)})
	if fact == "action_contact":
		_last_cause = origin
		if target.has_method("react") and _actor_living(target):
			record_scenario_fact(origin, "npc_reaction", target)
	if kind == "actor_grab" and not event.is_empty():
		_last_cause = origin
		incident_event.emit("ACTOR_GRAB", float(ceo_hold.rules.grab_incident_weight), target.global_position)
		_disturb(target.global_position, 1.8)
	_contact.clear()

func begin_prop_contact(source: Node3D, target: Node3D) -> void:
	_contact.clear()
	if events.frozen or not source.has_meta("scenario_origin") or scenario_time - float(source.get_meta("scenario_origin_time", -10.0)) > 2.0 or int(source.get_meta("scenario_hops", 0)) >= 3:
		return
	_contact = (source.get_meta("scenario_origin") as Dictionary).duplicate(true)
	if str(_contact.get("round_id", "")) != events.round_id:
		_contact.clear()
		return
	if is_instance_valid(target):
		_contact["state_before"] = _target_state(target)
		if target.has_method("mark_player_impulse"):
			target.set_meta("scenario_origin", _contact.duplicate(true))
			target.set_meta("scenario_origin_time", source.get_meta("scenario_origin_time"))
			target.set_meta("scenario_hops", int(source.get_meta("scenario_hops", 0)) + 1)

func end_prop_contact(source: Node3D, target: Node3D) -> void:
	if _contact.is_empty():
		return
	var origin: Dictionary = _contact.duplicate(true)
	_last_cause = origin
	record_scenario_fact(origin, "action_contact", target if is_instance_valid(target) else source)
	_contact.clear()

func _record_applied_reaction(actor: Node3D) -> void:
	if not is_instance_valid(actor) or not _pending_reactions.has(actor.get_instance_id()):
		return
	var pending: Dictionary = _pending_reactions[actor.get_instance_id()]
	_pending_reactions.erase(actor.get_instance_id())
	if _actor_living(actor) and actor.get("state") not in ["idle", "pursue"]:
		record_scenario_fact(pending["origin"], "npc_reaction", actor)
		if bool(actor.get("_work_interrupted")):
			record_scenario_fact(pending["origin"], "work_interrupted", actor)

func queue_scenario_line(beat: String, actor: Node3D, text: String, priority: int) -> void:
	if not _actor_living(actor):
		return
	var once_key: String = "%d:%s" % [actor.get_instance_id(), beat]
	if _scenario_spoken.has(once_key):
		return
	if not _scenario_line.is_empty() and int(_scenario_line["priority"]) > priority:
		return
	_scenario_spoken[once_key] = true
	_scenario_line = {"beat": beat, "actor": actor, "text": text, "priority": priority, "due": scenario_time + 0.2, "expires": scenario_time + 3.2}

func cancel_scenario_speaker(actor: Node3D) -> void:
	if not _scenario_line.is_empty() and _scenario_line["actor"] == actor:
		_scenario_line.clear()
	scene_speaker_invalidated.emit(actor)

func _advance_scenario_line() -> void:
	if _scenario_line.is_empty():
		return
	if not is_instance_valid(_scenario_line["actor"]):
		_scenario_line.clear()
		return
	var actor: Node3D = _scenario_line["actor"]
	if not _actor_living(actor) or scenario_time > float(_scenario_line["expires"]) or not is_instance_valid(player_target) or actor.global_position.distance_to(player_target.global_position) > 8.0:
		_scenario_line.clear()
		return
	if scenario_time < float(_scenario_line["due"]) or opening_active or boss_lecture_active:
		return
	if scenario_line_can_start.is_valid() and not bool(scenario_line_can_start.call(int(_scenario_line["priority"]))):
		return
	scenario_dialogue.emit(str(actor.get("display_name")), str(_scenario_line["text"]), 2.8, actor, int(_scenario_line["priority"]))
	actor.set("_talk_time", 2.8)
	_scenario_line.clear()

func _hold_relation() -> Node:
	return ceo_hold if is_instance_valid(ceo_hold) else null

func _on_police_observed(actor: CharacterBody3D) -> void:
	if _actor_living(actor):
		queue_scenario_line("ceo-police-seen", actor, "봤지? 대표가 있어야 말을 듣잖아.", 60)

func reset_world() -> void:
	world_resetting.emit()
	if is_instance_valid(player_target):
		player_target.reset_position(PLAYER_SPAWN)
	_pending_reactions.clear()
	_scenario_spoken.clear()
	_contact.clear()
	_last_cause.clear()
	_scenario_line.clear()
	scenario_time = 0.0
	cancel_opening_scene()
	for prop: Node3D in props:
		if is_instance_valid(prop):
			remove_child(prop)
			prop.queue_free()
	for npc: Node3D in npcs:
		if is_instance_valid(npc):
			remove_child(npc)
			npc.queue_free()
	props.clear()
	npcs.clear()
	remove_child(_furniture)
	_furniture.queue_free()
	_disturbed = false
	_slammed = false
	_level = 0
	_reaction_cooldown = 0.0
	_ambient_cooldown = 2.5
	_ambient_spoken.clear()
	opening_started = false
	opening_elapsed = -1.0
	_opening_index = 0
	_opening_invalidated.clear()
	_reset_boss_lecture()
	for obstacles: Array in _navigation_obstacles:
		obstacles.clear()
	_elevator_doors.clear()
	_pursuit_transfer_delay = 0.0
	_ready()
