extends Node
## One Free/Held relation. Environment collisions remain on for both capsules.
signal grab_started(actor: CharacterBody3D)
signal holding_changed(actor: CharacterBody3D, held: bool, reason: String)
signal hold_motion(actor: CharacterBody3D)
signal hold_expiring(actor: CharacterBody3D)
var holder: CharacterBody3D
var target: CharacterBody3D
var active: bool = false
var side: float = 1.0
var age: float = 0.0
var cooldown_remaining: float = 0.0
var rules: Dictionary = {}
var _start: Vector3
var _moved_spoken: bool = false
var _expiring_spoken: bool = false
var _overlap_age: float = 0.0
var _turn_budget: float = 0.0

func _init() -> void:
	rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenario/ceo_hold_v03.json"))

func try_grab(actor: CharacterBody3D) -> bool:
	if active or cooldown_remaining > 0.0 or not is_instance_valid(holder) or not holder.is_inside_tree() or not holder.enabled or get_tree().paused:
		return false
	if is_instance_valid(holder.held_prop) or holder.get("_cooldown") > 0.0 or holder.get("_anim") > 0.0 or holder.get("_slam_pending"):
		return false
	if not is_instance_valid(actor) or not actor.is_inside_tree() or not actor.has_method("set_grabbed") or actor.get("can_be_grabbed") != true or actor.health <= 0.0 or actor.state == "down" or actor.get("_cooldown") > 0.0:
		return false
	if is_instance_valid(actor.grabbed_by) or not holder.is_on_floor() or not actor.is_on_floor():
		return false
	var offset: Vector3 = actor.global_position - holder.global_position
	if Vector2(offset.x, offset.z).length() > float(rules.grab_distance) or not _visible(actor) or not _flat_pair(holder.global_position, actor.global_position):
		return false
	var local: Vector3 = holder.to_local(actor.global_position)
	var preferred: float = -1.0 if local.x < 0.0 else 1.0
	var selected: float = 0.0
	for choice: float in [preferred, -preferred]:
		var destination: Vector3 = _anchor(holder.global_position, holder.rotation.y, choice)
		if _flat_pair(holder.global_position, destination) and _safe_fraction(actor, actor.global_position, destination - actor.global_position, holder) >= 0.999 and _clear_at(actor, destination, holder):
			selected = choice
			break
	if selected == 0.0:
		return false
	target = actor
	side = selected
	age = 0.0
	_overlap_age = 0.0
	_moved_spoken = false
	_expiring_spoken = false
	_start = holder.global_position
	_turn_budget = 0.0
	grab_started.emit(actor)
	actor.interrupt_work()
	actor.add_collision_exception_with(holder)
	holder.add_collision_exception_with(actor)
	actor.set_grabbed(holder)
	if not actor.grab_invalidated.is_connected(_on_target_hit):
		actor.grab_invalidated.connect(_on_target_hit)
	active = true
	holding_changed.emit(actor, true, "input")
	return true

func release(reason: String = "input") -> void:
	if not active:
		return
	var actor: CharacterBody3D = target if is_instance_valid(target) else null
	active = false
	target = null
	cooldown_remaining = float(rules.regrab_seconds)
	age = 0.0
	_overlap_age = 0.0
	if is_instance_valid(actor):
		if actor.grab_invalidated.is_connected(_on_target_hit):
			actor.grab_invalidated.disconnect(_on_target_hit)
		if is_instance_valid(holder):
			actor.remove_collision_exception_with(holder)
			holder.remove_collision_exception_with(actor)
		actor.set_grabbed(null)
	holding_changed.emit(actor, false, reason)

func reset_round() -> void:
	release("restart")
	cooldown_remaining = 0.0
	age = 0.0

func _exit_tree() -> void:
	release("scene_change")

func _on_target_hit() -> void:
	release("target_hit")

func movement_scale() -> float:
	return float(rules.walk_scale) if active else 1.0

func limit_motion(motion: Vector3) -> Vector3:
	if not active:
		return motion
	if not is_instance_valid(holder) or not holder.is_inside_tree() or not is_instance_valid(target) or not target.is_inside_tree():
		release("missing_actor")
		return motion
	var destination: Vector3 = _anchor(holder.global_position + motion, holder.rotation.y, side)
	if not _flat_pair(holder.global_position + motion, destination):
		release("terrain")
		return Vector3.ZERO
	var fraction: float = minf(_safe_fraction(holder, holder.global_position, motion, target), _safe_fraction(target, target.global_position, destination - target.global_position, holder))
	return motion * (maxf(0.0, fraction - 0.02) if fraction < 0.999 else 1.0)

func limit_yaw(requested: float) -> float:
	if not active:
		return requested
	if not is_instance_valid(holder) or not holder.is_inside_tree() or not is_instance_valid(target) or not target.is_inside_tree():
		release("missing_actor")
		return requested
	var begin: float = holder.rotation.y
	var change: float = clampf(wrapf(requested - begin, -PI, PI), -_turn_budget, _turn_budget)
	var steps: int = maxi(1, ceili(absf(change) / 0.08))
	var previous: Vector3 = target.global_position
	var accepted: float = begin
	for i: int in range(1, steps + 1):
		var yaw: float = begin + change * float(i) / float(steps)
		var point: Vector3 = _anchor(holder.global_position, yaw, side)
		if not _flat_pair(holder.global_position, point) or _safe_fraction(target, previous, point - previous, holder) < 0.999 or not _clear_at(target, point, holder):
			break
		previous = point
		accepted = yaw
	_turn_budget = maxf(0.0, _turn_budget - absf(accepted - begin))
	return accepted

func _anchor(at: Vector3, yaw: float, choice: float) -> Vector3:
	return at + Basis(Vector3.UP, yaw) * Vector3(choice * float(rules.side_offset), 0, -float(rules.forward_offset))

func _visible(actor: CharacterBody3D) -> bool:
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(holder.camera.global_position, actor.global_position + Vector3.UP * 1.1, 3)
	ray.exclude = [holder.get_rid(), actor.get_rid()]
	return holder.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _floor_at(at: Vector3) -> Dictionary:
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.45, at - Vector3.UP * 0.65, 1)
	ray.exclude = [holder.get_rid()]
	return holder.get_world_3d().direct_space_state.intersect_ray(ray)

func _flat_pair(a: Vector3, b: Vector3) -> bool:
	var fa: Dictionary = _floor_at(a)
	var fb: Dictionary = _floor_at(b)
	return not fa.is_empty() and not fb.is_empty() and (fa.normal as Vector3).dot(Vector3.UP) >= float(rules.minimum_floor_dot) and (fb.normal as Vector3).dot(Vector3.UP) >= float(rules.minimum_floor_dot) and absf(fa.position.y - fb.position.y) <= float(rules.floor_height_tolerance)

func _collider(body: CharacterBody3D) -> CollisionShape3D:
	for child: Node in body.get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
	return null

func _query(body: CharacterBody3D, at: Vector3, exclude: CharacterBody3D) -> PhysicsShapeQueryParameters3D:
	var shape_node: CollisionShape3D = _collider(body)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var capsule: CapsuleShape3D = shape_node.shape.duplicate() as CapsuleShape3D
	# Contact skin keeps a standing floor contact out of horizontal overlap tests.
	capsule.radius = maxf(0.1, capsule.radius - 0.01)
	capsule.height = maxf(capsule.radius * 2.0, capsule.height - 0.02)
	query.shape = capsule
	query.transform = shape_node.global_transform
	query.transform.origin += at - body.global_position
	query.collision_mask = 7
	query.exclude = [body.get_rid(), exclude.get_rid()]
	query.margin = 0.002
	return query

func _safe_fraction(body: CharacterBody3D, at: Vector3, motion: Vector3, exclude: CharacterBody3D) -> float:
	if motion.length_squared() < 0.000001:
		return 1.0
	var query: PhysicsShapeQueryParameters3D = _query(body, at, exclude)
	query.motion = motion
	var fractions: PackedFloat32Array = holder.get_world_3d().direct_space_state.cast_motion(query)
	return fractions[0] if fractions.size() == 2 else 0.0

func _clear_at(body: CharacterBody3D, at: Vector3, exclude: CharacterBody3D) -> bool:
	return holder.get_world_3d().direct_space_state.intersect_shape(_query(body, at, exclude), 1).is_empty()

func _physics_process(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if not active:
		return
	if not is_instance_valid(holder) or not holder.is_inside_tree() or not is_instance_valid(target) or not target.is_inside_tree():
		release("missing_actor")
		return
	if target.health <= 0.0 or target.state == "down":
		release("incapacitated")
		return
	age += delta
	_turn_budget = float(rules.turn_rate) * delta
	if float(rules.hold_seconds) > 0.0 and age >= float(rules.hold_seconds):
		release("timeout")
		return
	if not _expiring_spoken and float(rules.hold_seconds) > 0.0 and age >= float(rules.hold_seconds) - 2.0:
		_expiring_spoken = true
		hold_expiring.emit(target)
	var desired: Vector3 = _anchor(holder.global_position, holder.rotation.y, side)
	if not _flat_pair(holder.global_position, desired):
		release("terrain")
		return
	var motion: Vector3 = desired - target.global_position
	motion.y = 0.0
	motion = motion.limit_length(float(rules.follow_speed) * delta)
	var fraction: float = _safe_fraction(target, target.global_position, motion, holder)
	if fraction < 0.999:
		motion *= maxf(0.0, fraction - 0.02)
	target.velocity.x = motion.x / maxf(delta, 0.001)
	target.velocity.z = motion.z / maxf(delta, 0.001)
	target.velocity.y = -0.1 if target.is_on_floor() else target.velocity.y - 18.0 * delta
	target.move_and_slide()
	var separation: float = Vector2(target.global_position.x - holder.global_position.x, target.global_position.z - holder.global_position.z).length()
	var minimum: float = (_collider(holder).shape as CapsuleShape3D).radius + (_collider(target).shape as CapsuleShape3D).radius + 0.05
	var overlap: bool = separation < minimum or not _clear_at(target, target.global_position, holder) or not _clear_at(holder, holder.global_position, target)
	_overlap_age = _overlap_age + delta if overlap else 0.0
	if separation < minimum:
		release("pair_overlap")
		return
	if _overlap_age >= float(rules.overlap_release_seconds) or (age > 0.4 and target.global_position.distance_to(desired) > 0.45):
		release("obstructed")
		return
	if not _moved_spoken and holder.global_position.distance_to(_start) > 0.65:
		_moved_spoken = true
		hold_motion.emit(target)
