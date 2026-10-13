extends PhysicalBone3D
## Keep the existing player's receive_hit() ray interface on the physical limbs.
var actor: CharacterBody3D

func receive_hit(impulse: Vector3, point: Vector3, damage: float) -> void:
	if is_instance_valid(actor):
		actor.receive_hit(impulse, point, damage)
