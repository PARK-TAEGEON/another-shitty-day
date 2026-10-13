extends "res://scripts/office_npc.gd"
## Police-only response to a currently visible, physically held CEO.
## The shared responder controller and accepted push contact remain authoritative.
signal hold_observed(target: CharacterBody3D)

@export var hold_reaction_range: float = 6.5
@export var hold_min_distance: float = 2.5
@export var hold_max_distance: float = 3.5
@export var hold_standoff_distance: float = 3.0
var hold_provider: Callable
var witnessed_hold: bool = false
var observed_holder: CharacterBody3D
var observed_target: CharacterBody3D
var _hold_warning_spoken: bool = false

func _refresh_hold_witness() -> void:
	witnessed_hold = false
	observed_holder = null
	observed_target = null
	if role != "police" or state == "down" or health <= 0.0 or not hold_provider.is_valid():
		return
	var relation: Node = hold_provider.call() as Node
	if not is_instance_valid(relation) or not relation.is_inside_tree():
		return
	var relation_active: Variant = relation.get("active")
	if not relation_active is bool or not relation_active:
		return
	var holder: CharacterBody3D = relation.get("holder") as CharacterBody3D
	var actor: CharacterBody3D = relation.get("target") as CharacterBody3D
	if not is_instance_valid(holder) or not holder.is_inside_tree() or holder != player_target:
		return
	var holder_enabled: Variant = holder.get("enabled")
	if not holder_enabled is bool or not holder_enabled:
		return
	if not is_instance_valid(actor) or not actor.is_inside_tree() or str(actor.get("role")) != "ceo" or str(actor.get("state")) == "down":
		return
	var actor_health: Variant = actor.get("health")
	if not (actor_health is float or actor_health is int) or float(actor_health) <= 0.0:
		return
	if actor.get("grabbed_by") != holder:
		return
	if global_position.distance_to(holder.global_position) > hold_reaction_range or global_position.distance_to(actor.global_position) > hold_reaction_range:
		return
	if not _sees_body(holder, 1.2) or not _sees_body(actor, 1.35):
		return
	witnessed_hold = true
	observed_holder = holder
	observed_target = actor
	if not _hold_warning_spoken:
		_hold_warning_spoken = true
		_talk_time = 2.8
		said.emit("%s  |  잠깐, 사장님은 놓고 얘기하세요." % display_name)
		hold_observed.emit(actor)

func _sees_body(body: CharacterBody3D, height: float) -> bool:
	# Actual bodies, not the player's view/cut camera. Props also obstruct sight.
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.5,
		body.global_position + Vector3.UP * height,
		1 | 2)
	query.exclude = [get_rid(), body.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _advance_security(delta: float, distance: float, offset: Vector3) -> void:
	_refresh_hold_witness()
	if witnessed_hold and not _guard_push_active:
		# This modifier gates only a NEW windup. A prior accepted windup follows
		# the inherited contact/range/occlusion and may still hit/release the holder.
		return
	super._advance_security(delta, distance, offset)

func _physics_process(delta: float) -> void:
	_refresh_hold_witness()
	if not witnessed_hold or _guard_push_active or state != "pursue":
		super._physics_process(delta)
		return
	var previous_reaction: Vector3 = _reaction_target
	var destination: Vector3 = _standoff_point()
	var horizontal: Vector3 = observed_holder.global_position - global_position
	horizontal.y = 0.0
	var movement: Vector3 = Vector3.ZERO
	if horizontal.length() < hold_min_distance or horizontal.length() > hold_max_distance:
		movement = _path_direction(destination, delta) * 2.35
	# A temporary concern pose keeps the inherited pursuit branch from moving
	# into arm's reach. The inherited controller still performs the only slide,
	# gravity, collision, clocks, damage pose and animation update for this tick.
	state = "concern"
	_reaction_target = observed_holder.global_position
	velocity.x = movement.x
	velocity.z = movement.z
	super._physics_process(delta)
	if state == "concern":
		state = "pursue"
	_reaction_target = previous_reaction

func _standoff_point() -> Vector3:
	var away: Vector3 = global_position - observed_holder.global_position
	away.y = 0.0
	if away.length_squared() < 0.001:
		away = -Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	var destination: Vector3 = observed_holder.global_position + away.normalized() * hold_standoff_distance
	destination.y = global_position.y
	return destination
