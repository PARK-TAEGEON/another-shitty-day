extends Node3D
## The imported neck, shoulders, elbows and legs use the existing office pivots.
## OfficeNPC still owns every pose, expression, interaction and fall.
const MODEL_PATH := "res://assets/rig_slice/park_office.glb"

var loaded_model: Node3D
var _actor: CharacterBody3D
var _sources: Array[Node3D] = []
var _targets: Array[Node3D] = []
var _eyes: Array[Node3D] = []
var _brows: Array[Node3D] = []
var _brow_rest: Array[Transform3D] = []
var _source_brow_rest: Array[Vector3] = []
var _mouth: Node3D

func attach_to(actor: CharacterBody3D) -> bool:
	name = "ParkVisualAdapter"
	_actor = actor
	if not ResourceLoader.exists(MODEL_PATH):
		push_error("PARK_VISUAL asset unavailable: " + MODEL_PATH)
		return false
	var scene := load(MODEL_PATH) as PackedScene
	if scene == null:
		push_error("PARK_VISUAL could not load " + MODEL_PATH)
		return false
	var instance := scene.instantiate()
	loaded_model = instance as Node3D
	if loaded_model == null:
		if instance != null:
			instance.free()
		push_error("PARK_VISUAL invalid scene root in " + MODEL_PATH)
		return false
	add_child(loaded_model)
	var controls := {
		"ParkHead": actor._head, "ParkTie": actor._tie,
		"ParkArmLeft": actor._left_arm, "ParkArmRight": actor._right_arm,
		"ParkElbowLeft": actor._left_elbow, "ParkElbowRight": actor._right_elbow,
		"ParkThighLeft": actor._left_leg, "ParkThighRight": actor._right_leg,
		"ParkShinLeft": actor._left_knee, "ParkShinRight": actor._right_knee,
		"ParkFootLeft": actor._left_ankle, "ParkFootRight": actor._right_ankle,
	}
	for part: String in controls:
		var target := loaded_model.find_child(part, true, false) as Node3D
		if target == null:
			push_error("PARK_VISUAL missing " + part + " in " + MODEL_PATH)
			return false
		_sources.append(controls[part])
		_targets.append(target)
	# Face suffixes are anatomical. Existing controls are ordered from -X to +X.
	for side: String in ["R", "L"]:
		var eye := loaded_model.find_child("ParkEye" + side, true, false) as Node3D
		var brow := loaded_model.find_child("ParkBrow" + side, true, false) as Node3D
		if eye == null or brow == null:
			push_error("PARK_VISUAL missing " + side + " expression controls in " + MODEL_PATH)
			return false
		_eyes.append(eye)
		_brows.append(brow)
		_brow_rest.append(brow.transform)
		_source_brow_rest.append(actor._brows[_brows.size() - 1].position)
	_mouth = loaded_model.find_child("ParkMouth", true, false) as Node3D
	if _mouth == null:
		push_error("PARK_VISUAL missing ParkMouth in " + MODEL_PATH)
		return false

	# Keep the old controls alive. The new model inherits the old visual root's
	# lean, height and procedural knockdown, including the down-state early path.
	for mesh: MeshInstance3D in actor._visual.find_children("*", "MeshInstance3D", true, false):
		mesh.hide()
	actor._visual.add_child(self)
	_copy_pose()
	print("PARK_VISUAL model=%s motion=office_npc controls=%d" % [loaded_model.scene_file_path, _targets.size()])
	return true

func _physics_process(_delta: float) -> void:
	_copy_pose()

func _copy_pose() -> void:
	for i in _targets.size():
		_targets[i].transform = _sources[i].transform
	for i in _eyes.size():
		_eyes[i].scale.y = _actor._eye_open
		var source_brow: Node3D = _actor._brows[i]
		_brows[i].position = _brow_rest[i].origin + source_brow.position - _source_brow_rest[i]
		_brows[i].basis = Basis(Vector3.BACK, source_brow.rotation.z) * _brow_rest[i].basis
	_mouth.scale.y = _actor._mouth_open
