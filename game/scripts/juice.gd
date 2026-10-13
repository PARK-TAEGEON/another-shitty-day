extends Node3D
## Comic hit feedback: impact puffs and a very short hitstop. Presentation only.
## Damage, money, escalation and NPC decisions never read anything from here.

const PUFF_COLOR: Color = Color(1.0, 0.98, 0.92, 0.9)
const HITSTOP_SCALE: float = 0.06

var enabled: bool = true
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _puffs: Array[Dictionary] = []
var _puff_mesh: SphereMesh
var _hitstop_serial: int = 0

func _ready() -> void:
	_rng.seed = 7331
	_puff_mesh = SphereMesh.new()
	_puff_mesh.radius = 0.5
	_puff_mesh.height = 1.0
	_puff_mesh.radial_segments = 10
	_puff_mesh.rings = 5

## A white cartoon dust burst. `power` ~0.5 for a prop knock, ~1.0 for a person.
func puff(at: Vector3, power: float = 1.0) -> void:
	if not enabled:
		return
	# Never bloom inside the lens: a point-blank hit puffs a little further out.
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		var from_eye: Vector3 = at - camera.global_position
		if from_eye.length() < 1.1:
			at = camera.global_position + from_eye.normalized() * 1.1
	var count: int = 4 + int(power * 4.0)
	for index: int in range(count):
		var node: MeshInstance3D = MeshInstance3D.new()
		node.mesh = _puff_mesh
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = PUFF_COLOR
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		node.global_position = at
		var direction: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.3, 1), _rng.randf_range(-1, 1)).normalized()
		_puffs.append({
			"node": node,
			"velocity": direction * _rng.randf_range(1.1, 2.4) * (0.6 + power * 0.5),
			"age": 0.0,
			"life": _rng.randf_range(0.26, 0.42),
			"size": _rng.randf_range(0.035, 0.07) * (0.7 + power * 0.5),
		})

## Freeze the game for a few frames so a big hit lands. Real time, not game time.
func hitstop(seconds: float) -> void:
	if not enabled or seconds <= 0.0:
		return
	_hitstop_serial += 1
	var serial: int = _hitstop_serial
	Engine.time_scale = HITSTOP_SCALE
	await get_tree().create_timer(seconds, true, false, true).timeout
	if serial == _hitstop_serial:
		Engine.time_scale = 1.0

func cancel() -> void:
	_hitstop_serial += 1
	Engine.time_scale = 1.0
	for puff_data: Dictionary in _puffs:
		(puff_data["node"] as Node).queue_free()
	_puffs.clear()

func _process(delta: float) -> void:
	for index: int in range(_puffs.size() - 1, -1, -1):
		var puff_data: Dictionary = _puffs[index]
		var node: MeshInstance3D = puff_data["node"]
		puff_data["age"] = float(puff_data["age"]) + delta
		var u: float = float(puff_data["age"]) / float(puff_data["life"])
		if u >= 1.0:
			node.queue_free()
			_puffs.remove_at(index)
			continue
		node.global_position += (puff_data["velocity"] as Vector3) * delta * (1.0 - u)
		node.scale = Vector3.ONE * float(puff_data["size"]) * (0.6 + u * 1.3)
		(node.material_override as StandardMaterial3D).albedo_color.a = 0.9 * (1.0 - u)

func _exit_tree() -> void:
	Engine.time_scale = 1.0
