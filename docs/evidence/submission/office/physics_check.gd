extends SceneTree
## Compare both modes at construction time, before the first physics step.
const SETTING := "asd/assets/office_props_v2_enabled"

func _initialize() -> void:
	run.call_deferred()

func snapshot(enabled: bool) -> Dictionary:
	ProjectSettings.set_setting(SETTING, enabled)
	var world = preload("res://scripts/world.gd").new()
	root.add_child(world)
	var solids := []
	for body: StaticBody3D in world.find_children("*", "StaticBody3D", true, false):
		for node: CollisionShape3D in body.find_children("*", "CollisionShape3D", true, false):
			if node.shape is BoxShape3D:
				solids.append(str([node.global_transform, node.shape.size, body.collision_layer, body.collision_mask]))
	solids.sort()
	var props := []
	for prop in world.props:
		var shape: CollisionShape3D = prop.find_children("*", "CollisionShape3D", false, false)[0]
		props.append([prop.kind, prop.global_transform, prop.mass, prop.collision_layer, prop.collision_mask,
			shape.transform, shape.shape.size, prop.DAMAGE_COSTS[prop.kind], prop.DAMAGE_THRESHOLDS[prop.kind]])
	var result := {"statics": solids, "props": props, "footprints": world._navigation_obstacles.duplicate(true)}
	world.free()
	return result

func run() -> void:
	var old_value = ProjectSettings.get_setting(SETTING, false)
	var original := snapshot(false)
	var updated := snapshot(true)
	ProjectSettings.set_setting(SETTING, old_value)
	var ok := original == updated
	print("OFFICE_PHYSICS identical=", ok, " static_boxes=", original.statics.size(), " props=", original.props.size())
	quit(0 if ok else 1)
