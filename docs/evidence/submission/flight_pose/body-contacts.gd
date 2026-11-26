extends "flight-capture.gd"
## Diagnostic (headless, --fixed-fps 30): for every Kim body, the physics steps
## with a floor contact and those where a floor contact normal (from the floor
## towards the body, world space) points down. Prints BODY_CONTACTS at the end.
var down_count := {}
var touch_count := {}
func _initialize() -> void:
	physics_frame.connect(_count)
	super._initialize()
func _count() -> void:
	if not is_instance_valid(rig) or rig.bodies.is_empty() or not rig.ragdoll_active or _floor_path == "":
		return
	for body: PhysicalBone3D in rig.bodies:
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		var down := false
		var touch := false
		for i in state.get_contact_count():
			var other := state.get_contact_collider_object(i) as Node
			if other != null and str(other.get_path()) == _floor_path:
				touch = true
				if state.get_contact_local_normal(i).y < -0.5:
					down = true
		if touch: touch_count[body.bone_name] = int(touch_count.get(body.bone_name, 0)) + 1
		if down: down_count[body.bone_name] = int(down_count.get(body.bone_name, 0)) + 1
func _write_log() -> void:
	super._write_log()
	print("BODY_CONTACTS ", JSON.stringify({"down": down_count, "touch": touch_count}))
