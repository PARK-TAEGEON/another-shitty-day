extends RefCounted

const MODELS := {
	"keyboard": preload("res://assets/submission/office/keyboard.glb"),
	"paper": preload("res://assets/submission/office/paper.glb"),
	"binder": preload("res://assets/submission/office/binder.glb"),
	"desk": preload("res://assets/submission/office/desk.glb"),
	"partition": preload("res://assets/submission/office/partition.glb"),
	"monitor": preload("res://assets/submission/office/monitor.glb"),
	"mug": preload("res://assets/submission/office/mug.glb"),
}
static var reported: Dictionary = {}

static func enabled() -> bool:
	return OS.get_cmdline_user_args().has("--office-props-v2") or bool(ProjectSettings.get_setting("asd/assets/office_props_v2_enabled", false))

static func attach(kind: String, parent: Node3D) -> Node3D:
	var model: Node3D = MODELS[kind].instantiate()
	parent.add_child(model)
	if not reported.has(kind):
		reported[kind] = true
		print("OFFICE_PROP model=", kind, " version=2")
	return model

static func prop_parts(kind: String, parent: Node3D, tint: Color) -> Dictionary:
	var model := attach(kind, parent)
	if kind == "monitor":
		var screen := model.get_node("Head/Screen") as MeshInstance3D
		screen.material_override = screen.get_active_material(0).duplicate()
		return {"head": model.get_node("Head"), "screen": screen, "stand": model.get_node("Stand"),
			"rows": model.get_node("Head").find_children("Row*", "MeshInstance3D", false, false)}
	if kind == "keyboard":
		var keys: Array[Node] = []
		for i in 33:
			keys.append(model.get_node("Key%02d" % i))
		return {"body": model.get_node("Body"), "keys": keys, "space": model.get_node("Space")}
	if kind == "paper":
		return {"sheets": [model.get_node("Sheet0"), model.get_node("Sheet1"),
			model.get_node("Sheet2"), model.get_node("Sheet3")], "label": model.get_node("Label")}
	var glaze := StandardMaterial3D.new()
	glaze.albedo_color = tint
	glaze.roughness = 0.86
	for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			if node.mesh.surface_get_material(surface).resource_name == "teal":
				node.set_surface_override_material(surface, glaze)
	if kind == "binder":
		return {"hinge": model.get_node("Hinge"), "pages": model.get_node("Pages")}
	return {"body": model.get_node("Body"), "coffee": model.get_node("Coffee"),
		"handle": [model.get_node("HandleUpper"), model.get_node("HandleGrip"), model.get_node("HandleLower")]}

static func desk(parent: Node3D, at: Vector3, width: float) -> void:
	var model := attach("desk", parent)
	model.position = at
	(model.get_node("Surface") as Node3D).scale.x = width / 2.9
	(model.get_node("Rail") as Node3D).scale.x = (width - 0.2) / 2.7
	(model.get_node("Left") as Node3D).position.x = -width * 0.5 + 0.17
	(model.get_node("Right") as Node3D).position.x = width * 0.5 - 0.17

static func partition(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var model := attach("partition", parent)
	model.position = at
	model.scale = size / Vector3(2.7, 1.5, 0.13)
