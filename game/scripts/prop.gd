extends RigidBody3D
## Small authored rigid props: gameplay mass and bounds stay deliberately simple.
signal scored(kind: String, points: int, at: Vector3)
signal noise(at: Vector3, strength: float)
signal damage_assessed(category: String, total: int, label: String)
signal incident(kind: String, weight: float, at: Vector3)
signal contact_started(source: Node3D, target: Node3D)
signal contact_finished(source: Node3D, target: Node3D)

## Fictional balance amounts. Each entry is the cumulative damaged/unusable cost,
## not two separate invoices. The world ledger adds only the increase.
const DAMAGE_COSTS: Dictionary = {
	"monitor": [100000, 300000], "mug": [10000, 10000],
	"printer": [150000, 450000], "keyboard": [20000, 50000],
	"chair": [30000, 120000], "plant": [15000, 40000],
	"paper": [5000, 15000], "binder": [10000, 30000]
}
const DAMAGE_THRESHOLDS: Dictionary = {
	"monitor": [16.0, 40.0], "mug": [12.0, 12.0],
	"printer": [22.0, 65.0], "keyboard": [12.0, 32.0],
	"chair": [20.0, 65.0], "plant": [15.0, 35.0],
	"paper": [10.0, 25.0], "binder": [14.0, 38.0]
}
const MIN_HIT_DAMAGE: float = 6.0
const MIN_COLLISION_SPEED: float = 3.0
const THROW_RELEASE_SPEED: float = 7.0

var display_name: String = "Object"
var kind: String = "mug"
var tint: Color = Color("d98752")
var held: bool = false
var damage_stage: int = 0 # Intact, visibly damaged, unusable.
var accumulated_damage: float = 0.0
var damage_total: int = 0
var _scored: bool = false
var _thrown: bool = false
var _last_velocity: Vector3 = Vector3.ZERO
var _age: float = 0.0
var _impact_armed: bool = false
var _activation_remaining: float = 0.0
var _rest_time: float = 0.0
var _release_probe: float = 0.0
var _collision_cooldown: float = 0.0
var _visuals: Node3D
var _details: Node3D
var _parts: Dictionary = {}
var _flicker_clock: float = 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 15
	contact_monitor = true
	max_contacts_reported = 4
	linear_damp = 0.18
	angular_damp = 0.45
	var physics: PhysicsMaterial = PhysicsMaterial.new()
	physics.friction = 0.72
	physics.bounce = 0.12
	physics_material_override = physics
	_visuals = Node3D.new()
	_visuals.name = "PropVisuals"
	add_child(_visuals)
	_details = Node3D.new()
	_details.name = "DamageDetails"
	_visuals.add_child(_details)
	_build()
	set_process(false)
	body_entered.connect(_on_body_entered)
	add_to_group("grabbable")

func _mat(color: Color, rough: float = 0.75) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	return mat

func _box(size: Vector3, at: Vector3, color: Color, rot: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _mat(color)
	node.position = at
	node.rotation = rot
	(parent if parent != null else _visuals).add_child(node)
	return node

func _cylinder(radius: float, height: float, at: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	node.mesh = mesh
	node.material_override = _mat(color)
	node.position = at
	(parent if parent != null else _visuals).add_child(node)
	return node

func _bounds(size: Vector3, at: Vector3 = Vector3.ZERO) -> void:
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = at
	add_child(collision)

func _build() -> void:
	var ink: Color = Color("263b43")
	var cream: Color = Color("efe8d7")
	match kind:
		"mug":
			mass = 0.65
			_parts["body"] = _cylinder(0.095, 0.21, Vector3.ZERO, tint)
			_parts["coffee"] = _cylinder(0.078, 0.008, Vector3(0, 0.108, 0), Color("473123"))
			_parts["handle"] = [
				_box(Vector3(0.09, 0.032, 0.035), Vector3(0.112, 0.06, 0), tint),
				_box(Vector3(0.035, 0.12, 0.035), Vector3(0.154, 0, 0), tint),
				_box(Vector3(0.09, 0.032, 0.035), Vector3(0.112, -0.06, 0), tint)
			]
			_bounds(Vector3(0.24, 0.22, 0.2))
		"keyboard":
			mass = 0.9
			_parts["body"] = _box(Vector3(0.6, 0.045, 0.22), Vector3.ZERO, cream)
			_parts["keys"] = []
			for row: int in range(3):
				for col: int in range(11):
					_parts["keys"].append(_box(Vector3(0.039, 0.014, 0.04), Vector3(-0.255 + col * 0.05, 0.03, -0.07 + row * 0.05), ink if col == 10 else Color("c2c7be")))
			_parts["space"] = _box(Vector3(0.24, 0.012, 0.025), Vector3(0, 0.031, 0.095), Color("c2c7be"))
			_bounds(Vector3(0.6, 0.07, 0.23))
		"monitor":
			mass = 3.8
			var head: Node3D = Node3D.new()
			head.position = Vector3(0, 0.27, 0)
			_visuals.add_child(head)
			_parts["head"] = head
			_box(Vector3(0.72, 0.44, 0.075), Vector3.ZERO, ink, Vector3.ZERO, head)
			_parts["screen"] = _box(Vector3(0.65, 0.36, 0.008), Vector3(0, 0.01, 0.042), Color("497479"), Vector3.ZERO, head)
			_parts["rows"] = [_box(Vector3(0.24, 0.018, 0.012), Vector3(-0.15, 0.12, 0.049), Color("cfdecd"), Vector3.ZERO, head)]
			for n: int in range(4):
				_parts["rows"].append(_box(Vector3(0.42 - n * 0.055, 0.011, 0.012), Vector3(-0.06, 0.04 - n * 0.04, 0.049), Color("93b5ae"), Vector3.ZERO, head))
			_parts["stand"] = _box(Vector3(0.065, 0.2, 0.07), Vector3(0, -0.02, 0), ink)
			_box(Vector3(0.33, 0.028, 0.24), Vector3(0, -0.115, 0.015), ink)
			_bounds(Vector3(0.74, 0.62, 0.26), Vector3(0, 0.17, 0))
		"chair":
			mass = 5.5
			_parts["seat"] = _box(Vector3(0.57, 0.13, 0.54), Vector3(0, 0.47, 0), tint)
			_parts["back"] = _box(Vector3(0.54, 0.53, 0.11), Vector3(0, 0.77, -0.23), tint, Vector3(-0.08, 0, 0))
			_parts["column"] = _cylinder(0.045, 0.4, Vector3(0, 0.25, 0), ink)
			for n: int in range(5):
				var a: float = TAU * float(n) / 5.0
				_box(Vector3(0.07, 0.05, 0.58), Vector3(sin(a) * 0.11, 0.06, cos(a) * 0.11), ink, Vector3(0, a, 0))
			_box(Vector3(0.07, 0.26, 0.08), Vector3(-0.31, 0.61, 0), ink)
			_parts["arm_post"] = _box(Vector3(0.07, 0.26, 0.08), Vector3(0.31, 0.61, 0), ink)
			_box(Vector3(0.11, 0.06, 0.32), Vector3(-0.31, 0.75, 0), ink)
			_parts["arm_pad"] = _box(Vector3(0.11, 0.06, 0.32), Vector3(0.31, 0.75, 0), ink)
			_bounds(Vector3(0.69, 1.04, 0.68), Vector3(0, 0.52, 0))
		"plant":
			mass = 2.0
			_parts["body"] = _cylinder(0.15, 0.26, Vector3(0, 0, 0), tint)
			_parts["soil"] = _cylinder(0.13, 0.014, Vector3(0, 0.135, 0), Color("423a2a"))
			_parts["leaves"] = []
			for n: int in range(6):
				var a: float = TAU * float(n) / 6.0
				_parts["leaves"].append(_box(Vector3(0.095, 0.37, 0.04), Vector3(sin(a) * 0.085, 0.28, cos(a) * 0.085), Color("426e4d"), Vector3(0.4, a, 0.3)))
			_bounds(Vector3(0.32, 0.6, 0.32), Vector3(0, 0.16, 0))
		"paper":
			mass = 0.45
			_parts["sheets"] = []
			for n: int in range(4):
				_parts["sheets"].append(_box(Vector3(0.28, 0.012, 0.35), Vector3(n * 0.012, n * 0.014, 0), cream, Vector3(0, n * 0.07, 0)))
			_parts["label"] = _box(Vector3(0.15, 0.003, 0.018), Vector3(0.02, 0.064, -0.09), Color("78928e"))
			_bounds(Vector3(0.34, 0.08, 0.4), Vector3(0.02, 0.02, 0))
		"binder":
			mass = 1.1
			_box(Vector3(0.24, 0.065, 0.32), Vector3.ZERO, tint)
			_parts["pages"] = _box(Vector3(0.21, 0.043, 0.28), Vector3(0.015, 0, 0.01), cream)
			var hinge: Node3D = Node3D.new()
			hinge.position = Vector3(-0.12, 0.036, 0)
			_visuals.add_child(hinge)
			_parts["hinge"] = hinge
			_box(Vector3(0.24, 0.01, 0.32), Vector3(0.12, 0, 0), tint, Vector3.ZERO, hinge)
			_box(Vector3(0.11, 0.004, 0.055), Vector3(0.12, 0.007, -0.055), cream, Vector3.ZERO, hinge)
			_bounds(Vector3(0.25, 0.08, 0.33))
		"printer":
			mass = 7.0
			_box(Vector3(0.66, 0.39, 0.55), Vector3.ZERO, Color("dddacb"))
			_parts["lid"] = _box(Vector3(0.6, 0.06, 0.5), Vector3(0, 0.225, 0), ink)
			_box(Vector3(0.41, 0.065, 0.02), Vector3(0, -0.05, 0.285), ink)
			_parts["tray"] = _box(Vector3(0.28, 0.015, 0.2), Vector3(0, -0.06, 0.37), cream)
			_parts["screen"] = _box(Vector3(0.12, 0.018, 0.09), Vector3(0.19, 0.264, 0.15), Color("7bb7ae"))
			_bounds(Vector3(0.68, 0.5, 0.62))
		_:
			mass = 1.6
			_parts["body"] = _box(Vector3(0.33, 0.33, 0.33), Vector3.ZERO, tint)
			_bounds(Vector3(0.34, 0.34, 0.34))

func _line(from: Vector3, to: Vector3, width: float, color: Color, parent: Node3D = null) -> void:
	var edge: Vector3 = to - from
	var node: MeshInstance3D = _box(Vector3(width, edge.length(), width), (from + to) * 0.5, color, Vector3.ZERO, parent if parent != null else _details)
	node.quaternion = Quaternion(Vector3.UP, edge.normalized())

func _chip(at: Vector3, size: Vector3, rot: Vector3, color: Color) -> void:
	# Small attached ceramic/paper fragments are visual geometry, not extra rigid
	# bodies. This keeps the original safe carrying bounds and bounded physics cost.
	var vertices: Array[Vector3] = [
		Vector3(-0.5, -0.5, -0.4), Vector3(0.5, -0.5, -0.4), Vector3(-0.08, -0.5, 0.5),
		Vector3(-0.5, 0.5, -0.4), Vector3(0.5, 0.5, -0.4), Vector3(-0.08, 0.5, 0.5)
	]
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in [0, 2, 1, 3, 4, 5, 0, 1, 4, 0, 4, 3, 1, 2, 5, 1, 5, 4, 2, 0, 3, 2, 3, 5]:
		surface.add_vertex(vertices[index] * size)
	surface.generate_normals()
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = surface.commit()
	node.material_override = _mat(color)
	node.position = at
	node.rotation = rot
	_details.add_child(node)

func _set_color(part: String, color: Color) -> void:
	var mesh: MeshInstance3D = _parts[part] as MeshInstance3D
	(mesh.material_override as StandardMaterial3D).albedo_color = color

func _update_damage_visuals() -> void:
	for child: Node in _details.get_children():
		(child as Node3D).hide()
		child.queue_free()
	var final: bool = damage_stage == 2
	var ink: Color = Color("263b43")
	var crack: Color = Color("182429")
	var cream: Color = Color("efe8d7")
	match kind:
		"monitor":
			var head: Node3D = _parts["head"]
			if _details.get_parent() != head:
				_details.reparent(head, false)
			head.rotation = Vector3(0.12, 0, -0.2) if final else Vector3(0, 0, -0.055)
			head.position.y = 0.22 if final else 0.27
			(_parts["stand"] as Node3D).rotation.z = 0.15 if final else 0.025
			_set_color("screen", Color("101d22") if final else Color("304f55"))
			for row: MeshInstance3D in _parts["rows"]:
				row.visible = not final
			var lines: Array[Vector3] = [Vector3(-0.27, 0.17, 0.053), Vector3(-0.1, 0.06, 0.053), Vector3(-0.04, -0.055, 0.053), Vector3(0.19, -0.16, 0.053)]
			for n: int in range(lines.size() - 1):
				_line(lines[n], lines[n + 1], 0.01, Color("bdcec2") if final else cream)
			_line(lines[1], Vector3(0.13, 0.14, 0.053), 0.007, cream)
			_line(lines[2], Vector3(-0.25, -0.1, 0.053), 0.007, cream)
			if not final:
				_box(Vector3(0.085, 0.25, 0.007), Vector3(0.21, 0.025, 0.054), Color("68807a"), Vector3.ZERO, _details)
				_box(Vector3(0.51, 0.014, 0.008), Vector3(0, -0.025, 0.055), Color("be9d8a"), Vector3.ZERO, _details)
			_box(Vector3(0.025, 0.013, 0.009), Vector3(0.28, -0.198, 0.047), Color("b26651"), Vector3.ZERO, _details)
			set_process(not final)
		"mug":
			(_parts["body"] as Node3D).hide()
			(_parts["coffee"] as Node3D).hide()
			for handle: Node3D in _parts["handle"]:
				handle.hide()
			_cylinder(0.095, 0.052, Vector3(0, -0.078, 0), tint, _details)
			_cylinder(0.078, 0.008, Vector3(0, -0.048, 0), cream, _details)
			for n: int in range(5):
				var angle: float = float(n) * 0.63 + 0.2
				var height: float = 0.075 + float(n % 3) * 0.024
				_box(Vector3(0.06, height, 0.017), Vector3(sin(angle) * 0.083, -0.07 + height * 0.5, cos(angle) * 0.083), tint, Vector3(0, angle, 0), _details)
			_chip(Vector3(-0.11, -0.085, 0.035), Vector3(0.115, 0.016, 0.085), Vector3(0.1, 0.4, -0.18), tint)
			_chip(Vector3(0.055, -0.087, -0.105), Vector3(0.11, 0.018, 0.08), Vector3(0, -0.6, 0.1), tint)
			_box(Vector3(0.034, 0.075, 0.034), Vector3(0.132, -0.061, 0.045), tint, Vector3(0.2, -0.3, 0.7), _details)
		"printer":
			(_parts["lid"] as Node3D).rotation = Vector3(-0.47, 0.04, -0.11) if final else Vector3(-0.1, 0, -0.025)
			(_parts["lid"] as Node3D).position = Vector3(-0.025, 0.27, -0.055) if final else Vector3(0, 0.24, 0)
			(_parts["tray"] as Node3D).rotation.x = 0.35 if final else 0.12
			_set_color("screen", Color("142428") if final else Color("c79354"))
			_line(Vector3(-0.27, 0.16, 0.279), Vector3(-0.18, 0.045, 0.281), 0.013, crack)
			_line(Vector3(-0.18, 0.045, 0.281), Vector3(-0.24, -0.13, 0.281), 0.01, crack)
			for n: int in range(4 if final else 2):
				_box(Vector3(0.17, 0.009, 0.2), Vector3(-0.08 + n * 0.04, -0.02 + n * 0.018, 0.34 + n * 0.015), cream, Vector3(0.12 + n * 0.13, n * 0.18, n * 0.06), _details)
			if final:
				_chip(Vector3(0.27, -0.16, 0.25), Vector3(0.15, 0.04, 0.12), Vector3(0.4, -0.3, 0), cream)
		"keyboard":
			var keys: Array = _parts["keys"]
			for index: int in [4, 16, 22, 27, 31]:
				var key: Node3D = keys[index]
				key.position.y = 0.046 + (0.008 * (index % 3))
				key.position.z += (0.055 if final else 0.02) * (-1 if index % 2 == 0 else 1)
				key.rotation = Vector3(0.16, index * 0.17, 0.2 if final else 0.05)
			(_parts["space"] as Node3D).rotation.y = 0.26 if final else 0.08
			_line(Vector3(-0.12, 0.027, -0.095), Vector3(0.05, 0.031, 0.045), 0.012, crack)
			if final:
				(_parts["body"] as Node3D).hide()
				_box(Vector3(0.295, 0.045, 0.22), Vector3(-0.154, 0.005, 0), cream, Vector3(0, -0.02, -0.05), _details)
				_box(Vector3(0.29, 0.045, 0.22), Vector3(0.158, -0.014, 0.012), cream, Vector3(0, 0.08, -0.12), _details)
				_box(Vector3(0.12, 0.018, 0.06), Vector3(0.04, 0.018, 0.015), Color("45664f"), Vector3(0, -0.25, 0.1), _details)
		"chair":
			(_parts["back"] as Node3D).rotation = Vector3(-0.38, 0.1, -0.29) if final else Vector3(-0.11, 0, -0.12)
			(_parts["back"] as Node3D).position = Vector3(0.1, 0.63, -0.28) if final else Vector3(0.02, 0.75, -0.23)
			(_parts["arm_post"] as Node3D).rotation.z = -0.65 if final else -0.21
			(_parts["arm_pad"] as Node3D).rotation.z = -0.55 if final else -0.19
			(_parts["arm_pad"] as Node3D).position = Vector3(0.31, 0.29, 0.065) if final else Vector3(0.34, 0.71, 0)
			if final:
				(_parts["column"] as Node3D).scale.y = 0.63
				(_parts["seat"] as Node3D).position.y = 0.34
				(_parts["seat"] as Node3D).rotation.z = 0.1
				(_parts["arm_post"] as Node3D).position = Vector3(0.31, 0.22, 0)
			_line(Vector3(-0.15, 0.555 if not final else 0.43, 0.15), Vector3(0.07, 0.558 if not final else 0.445, 0.03), 0.018, crack)
		"plant":
			_line(Vector3(-0.05, 0.105, 0.145), Vector3(0.025, 0.015, 0.152), 0.012, crack)
			_line(Vector3(0.025, 0.015, 0.152), Vector3(-0.025, -0.07, 0.15), 0.01, crack)
			var leaves: Array = _parts["leaves"]
			for n: int in range(leaves.size()):
				var leaf: Node3D = leaves[n]
				leaf.rotation.x = 1.2 if final else (0.86 if n % 3 == 0 else 0.4)
				if final:
					leaf.position.y = 0.17 + float(n % 2) * 0.035
					leaf.position.x += 0.04
			if final:
				(_parts["body"] as Node3D).scale.y = 0.52
				(_parts["body"] as Node3D).position.y = -0.06
				(_parts["soil"] as Node3D).position.y = 0.015
				_chip(Vector3(-0.11, 0.015, 0.1), Vector3(0.13, 0.018, 0.12), Vector3(0.1, 0.5, 0.2), tint)
				_chip(Vector3(0.14, -0.075, 0.12), Vector3(0.16, 0.022, 0.12), Vector3(-0.1, -0.4, 0.15), tint)
				for n: int in range(3):
					_box(Vector3(0.07, 0.037, 0.065), Vector3(-0.11 + n * 0.092, -0.06, 0.18), Color("514333"), Vector3(0.1, n * 0.5, 0.1), _details)
		"paper":
			(_parts["label"] as Node3D).hide()
			for n: int in range(4):
				var sheet: Node3D = _parts["sheets"][n]
				sheet.position = Vector3((n - 1.5) * 0.035, n * 0.016, (n % 2) * 0.05)
				sheet.rotation.y = -0.3 + n * 0.21
				if final:
					sheet.hide()
					var crease: Node3D = Node3D.new()
					crease.position = Vector3((n - 1.5) * 0.045, 0.014 + n * 0.022, (n % 2) * 0.07)
					crease.rotation.y = -0.4 + n * 0.32
					_details.add_child(crease)
					_box(Vector3(0.14, 0.01, 0.32), Vector3(-0.067, 0.013, 0), cream, Vector3(0, 0, -0.23), crease)
					_box(Vector3(0.14, 0.01, 0.32), Vector3(0.067, 0.013, 0), cream, Vector3(0, 0, 0.23), crease)
					_line(Vector3(0, 0.01, -0.15), Vector3(0, 0.01, 0.15), 0.005, Color("7b8780"), crease)
					for row: int in range(3):
						_box(Vector3(0.09, 0.003, 0.01), Vector3(-0.077, 0.027, -0.08 + row * 0.034), Color("78928e"), Vector3(0, 0, -0.23), crease)
				else:
					for row: int in range(3):
						var at: Vector3 = sheet.position + sheet.basis * Vector3(-0.01, 0.009, -0.08 + row * 0.034)
						_box(Vector3(0.15, 0.003, 0.012), at, Color("78928e"), sheet.rotation, _details)
		"binder":
			(_parts["hinge"] as Node3D).rotation.z = 1.16 if final else 0.44
			(_parts["pages"] as Node3D).position.x = 0.07 if final else 0.035
			for n: int in range(4 if final else 2):
				_box(Vector3(0.2, 0.007, 0.28), Vector3(0.04 + n * 0.024, 0.035 + n * 0.011, 0.012 + n * 0.014), cream, Vector3(0, -0.1 + n * 0.16, n * 0.035), _details)
			if final:
				_box(Vector3(0.017, 0.025, 0.24), Vector3(-0.092, 0.031, 0), ink, Vector3(0, 0.1, 0.13), _details)
		_:
			(_parts["body"] as Node3D).scale = Vector3(1.05, 0.73 if final else 0.91, 1.02)
			(_parts["body"] as Node3D).rotation.z = -0.13 if final else -0.055

func _apply_damage(amount: float, source: String) -> void:
	if damage_stage == 2 or amount < MIN_HIT_DAMAGE:
		return
	var thresholds: Array = DAMAGE_THRESHOLDS.get(kind, [16.0, 40.0])
	accumulated_damage = minf(accumulated_damage + amount, float(thresholds[1]))
	var next_stage: int = 2 if accumulated_damage >= float(thresholds[1]) else (1 if accumulated_damage >= float(thresholds[0]) else 0)
	if next_stage <= damage_stage:
		return
	damage_stage = next_stage
	var costs: Array = DAMAGE_COSTS.get(kind, [10000, 30000])
	damage_total = int(costs[damage_stage - 1])
	_update_damage_visuals()
	var suffix: String = "사용 불능" if damage_stage == 2 else "손상"
	if kind == "mug":
		suffix = "파손"
	elif kind == "paper":
		suffix = "훼손" if damage_stage == 2 else "흩어짐"
	damage_assessed.emit("property", damage_total, "%s %s" % [display_name, suffix])
	# Legacy feedback remains available to fixtures/older integrations. New money
	# and heat consumers use the two explicit signals above, never these old points.
	if not _scored:
		_scored = true
		scored.emit(source, 25 if source == "THROW" else 15, global_position)

func set_held(value: bool) -> void:
	held = value
	freeze = value
	collision_layer = 0 if value else 2
	collision_mask = 0 if value else 15
	_impact_armed = false
	_thrown = false
	_activation_remaining = 0.0
	_rest_time = 0.0
	_last_velocity = Vector3.ZERO
	_release_probe = 0.0
	_collision_cooldown = 0.0
	if value:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	else:
		sleeping = false
		# Backward-compatible release detection. The player explicitly marks throws;
		# legacy callers assigning a fast launch immediately after release also work.
		# A normal 0.5 m/s E drop cannot arm before this short probe expires.
		_release_probe = 0.1

func mark_player_impulse() -> void:
	if held:
		return
	_impact_armed = true
	_thrown = false
	_activation_remaining = 3.0
	_rest_time = 0.0
	_release_probe = 0.0

func mark_player_throw() -> void:
	if held:
		return
	mark_player_impulse()
	_thrown = true
	_activation_remaining = 4.0
	_last_velocity = linear_velocity
	_collision_cooldown = 0.0
	continuous_cd = true

func receive_hit(impulse: Vector3, _point: Vector3, damage: float) -> void:
	_receive_impulse_hit(impulse, damage, true)

func receive_collision_hit(impulse: Vector3, _point: Vector3, damage: float) -> void:
	# A thrown object's incident already describes this collision. Assess the
	# struck prop's damage without inventing a second player punch for its heat.
	_receive_impulse_hit(impulse, damage, false)

func _receive_impulse_hit(impulse: Vector3, damage: float, report_incident: bool) -> void:
	if held:
		return
	sleeping = false
	apply_central_impulse(impulse)
	apply_torque_impulse(Vector3(impulse.z, 0.3, -impulse.x) * 0.09)
	if damage < MIN_HIT_DAMAGE:
		return
	mark_player_impulse()
	_collision_cooldown = 0.12
	_last_velocity = linear_velocity
	_apply_damage(damage, "OBJECT")
	if report_incident:
		incident.emit("PROPERTY", 0.6, global_position)
	noise.emit(global_position, clampf(impulse.length() / 4.0, 0.4, 3.0))

func _process(delta: float) -> void:
	# Damaged screens lose sync briefly; a dead screen stays black. No whole-screen
	# flash or extra lights are needed to communicate the broken electronic state.
	_flicker_clock += delta
	if kind == "monitor" and damage_stage == 1:
		var sync_lost: bool = fmod(_flicker_clock, 1.35) > 1.17
		_set_color("screen", Color("101d22") if sync_lost else Color("304f55"))
		for row: MeshInstance3D in _parts["rows"]:
			row.visible = not sync_lost

func _physics_process(delta: float) -> void:
	_age += delta
	_collision_cooldown = maxf(0.0, _collision_cooldown - delta)
	if _release_probe > 0.0:
		_release_probe -= delta
		if linear_velocity.length() >= THROW_RELEASE_SPEED:
			mark_player_throw()
	if _impact_armed:
		_activation_remaining -= delta
		_rest_time = _rest_time + delta if linear_velocity.length() < 0.6 else 0.0
		if _activation_remaining <= 0.0 or _rest_time > 0.4:
			_impact_armed = false
			_thrown = false
	_last_velocity = linear_velocity
	if global_position.y < -8.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if held or not _impact_armed or _collision_cooldown > 0.0:
		return
	var speed: float = _last_velocity.length()
	if speed < MIN_COLLISION_SPEED:
		return
	var was_thrown: bool = _thrown
	contact_started.emit(self, body as Node3D)
	# Consume the activated landing before forwarding a hit. The same object may
	# contact a wall, desk and floor in one frame without three incident emissions.
	_impact_armed = false
	_thrown = false
	_activation_remaining = 0.0
	_collision_cooldown = 0.18
	noise.emit(global_position, clampf(speed / 3.0, 0.4, 3.0))
	var collision_damage: float = clampf((speed - 2.2) * 7.0 * sqrt(mass), MIN_HIT_DAMAGE, 85.0)
	_apply_damage(collision_damage, "THROW" if was_thrown else "OBJECT")
	# Desk splash is attributed for damage only; its one desk incident belongs to
	# the world. A punched prop's later landing likewise isn't a second punch.
	if was_thrown:
		incident.emit("THROW", 1.0, global_position)
		var hit_impulse: Vector3 = _last_velocity.normalized() * minf(mass * speed, 18.0)
		if body.has_method("receive_collision_hit"):
			body.receive_collision_hit(hit_impulse, global_position, 25.0)
		elif body.has_method("receive_hit"):
			body.receive_hit(hit_impulse, global_position, 25.0)
	contact_finished.emit(self, body as Node3D)
