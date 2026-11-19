extends "res://scripts/office_npc.gd"
signal grab_invalidated
## Temporary adult CEO, reusing the existing face, walking, hits and fall model.
var can_be_grabbed: bool = true
var grabbed_by: CharacterBody3D

func receive_hit(impulse: Vector3, point: Vector3, damage: float, kind: String = "") -> void:
	grab_invalidated.emit()
	super.receive_hit(impulse, point, damage, kind)

func set_grabbed(holder: CharacterBody3D) -> void:
	grabbed_by = holder
	_reaction_pending = false
	_talk_time = 0.0
	if is_instance_valid(holder):
		state = "stunned"
		_freeze_time = 0.0
		velocity = Vector3.ZERO
	elif state != "down":
		state = "concern"
		if is_inside_tree() and is_instance_valid(player_target) and player_target.is_inside_tree():
			_reaction_target = player_target.global_position
			react(player_target.global_position, 2.0)

func react(where: Vector3, intensity: float = 1.0) -> void:
	if not is_instance_valid(grabbed_by):
		super.react(where, intensity)

func _physics_process(delta: float) -> void:
	if is_instance_valid(grabbed_by) and state != "down":
		# CeoHold owns the one physical slide; keep the existing visible pose/face.
		_clock += delta
		_talk_time = maxf(0.0, _talk_time - delta)
		_turn_toward(grabbed_by.global_position, delta, 6.0, 9.0)
		_animate_pose(delta, Vector2(velocity.x, velocity.z).length())
	else:
		super._physics_process(delta)
