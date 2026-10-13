extends "res://scripts/office_npc.gd"
signal scenario_hit
## Temporary adult CEO: existing procedural body, hit/face/navigation behavior.
var scenario_destination: Vector3 = Vector3.INF
var scenario_look: Vector3 = Vector3.ZERO
var commanding: bool = true

func receive_hit(impulse: Vector3, point: Vector3, damage: float) -> void:
	super.receive_hit(impulse, point, damage)
	scenario_hit.emit()

func move_to(at: Vector3) -> void:
	if state == "down":
		return
	scenario_destination = at
	_flee_destination = at
	_repath_time = 0.0
	state = "flee"

func settle(at: Vector3, commands: bool = false) -> void:
	scenario_destination = Vector3.INF
	scenario_look = at
	commanding = commands
	if state != "down":
		state = "concern" if commands else "spectate"
		_reaction_target = at

func _choose_flee_destination() -> Vector3:
	return scenario_destination if scenario_destination.is_finite() else global_position

func _apply_reaction(where: Vector3, _intensity: float) -> void:
	# The director owns CEO destinations; a legacy noise must not overwrite them.
	if state == "down":
		return
	interrupt_work()
	_reaction_pending = false
	_reaction_target = where
	if not scenario_destination.is_finite():
		state = "concern"

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state != "down" and not scenario_destination.is_finite():
		_turn_toward(scenario_look, delta, 4.0, 8.0)
