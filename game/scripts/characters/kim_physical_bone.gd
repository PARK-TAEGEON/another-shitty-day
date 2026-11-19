extends PhysicalBone3D
## Keep the existing player's receive_hit() ray interface on the physical limbs.
const HitFeelScript = preload("res://scripts/hit_feel.gd")
var actor: CharacterBody3D
var record_contacts: bool = false
var contact_ids: Dictionary = {}
var _was_touching: bool = false
var _previous_speed: float = 0.0

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if record_contacts:
		for i in range(state.get_contact_count()):
			contact_ids[state.get_contact_collider_id(i)] = true
	var touching: bool = state.get_contact_count() > 0
	if touching and not _was_touching and _previous_speed > 1.2 and is_instance_valid(actor) and is_instance_valid(actor._rig_adapter):
		var feel: Resource = HitFeelScript.load_settings()
		if self.bone_name in ["Pelvis", "Chest", "Head"]:
			var normal: Vector3 = state.get_contact_local_normal(0)
			var kick: float = minf(_previous_speed, 5.0) * float(feel.impact_bounce)
			state.apply_central_impulse(normal * kick * self.mass)
		var collider: Object = state.get_contact_collider_object(0)
		actor._rig_adapter.call_deferred("contact_sound", global_position, _previous_speed, collider is RigidBody3D)
		actor._rig_adapter.call_deferred("notify_impact", _previous_speed)
	_was_touching = touching
	_previous_speed = state.linear_velocity.length()

func receive_hit(impulse: Vector3, point: Vector3, damage: float, kind: String = "") -> void:
	if is_instance_valid(actor):
		actor.receive_hit(impulse, point, damage, kind)
