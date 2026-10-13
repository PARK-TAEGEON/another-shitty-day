extends PhysicalBone3D
## Keep the existing player's receive_hit() ray interface on the physical limbs.
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
	if touching and not _was_touching and _previous_speed > 1.2 and is_instance_valid(actor):
		var collider: Object = state.get_contact_collider_object(0)
		actor._rig_adapter.call_deferred("contact_sound",global_position,_previous_speed,collider is RigidBody3D)
	_was_touching = touching
	_previous_speed = state.linear_velocity.length()

func receive_hit(impulse: Vector3, point: Vector3, damage: float) -> void:
	if is_instance_valid(actor):
		actor.receive_hit(impulse, point, damage)
