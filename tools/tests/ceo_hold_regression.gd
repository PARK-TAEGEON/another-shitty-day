extends SceneTree
## v0.3 integration: actual saved MainScene, actual E input handler and physical
## pair movement. Fixtures prepare free actors, loose props and stress obstacles;
## they never assign hold.active/target or fabricate successful grab metadata.
## Headless assertions are not visual/style/subjective gameplay approval.
const MainScene: PackedScene = preload("res://scenes/main.tscn")
var game: Node3D
var world: Node3D
var player: CharacterBody3D
var ceo: CharacterBody3D
var hold: Node
var failures: Array[String] = []
var observations: Dictionary = {}
var facts: Array[Dictionary] = []
var changes: Array[Dictionary] = []
var obstacles: Array[Node] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("CEO_HOLD_CHECK: " + message)

func _advance(seconds: float) -> void:
	var deadline: float = float(game.elapsed) + seconds
	var wall: int = Time.get_ticks_msec() + 25000
	while game.elapsed < deadline and Time.get_ticks_msec() < wall:
		await physics_frame
	check(game.elapsed >= deadline, "simulation wait stopped at %.3f / %.3f" % [game.elapsed, deadline])

func _tap(action: String) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var released: InputEventAction = InputEventAction.new()
	released.action = action
	released.pressed = false
	Input.parse_input_event(released)
	Input.flush_buffered_events()

func _aim(at: Vector3) -> void:
	var offset: Vector3 = at - player.camera.global_position
	player.rotation.y = atan2(-offset.x, -offset.z)
	player.set("_pitch", atan2(offset.y, Vector2(offset.x, offset.z).length()))
	player.set("_shake", 0.0)
	player.camera.rotation = Vector3(float(player.get("_pitch")), 0.0, 0.0)

func _capture_fact(event: Dictionary) -> void:
	facts.append(event.duplicate(true))

func _capture_change(actor: CharacterBody3D, held: bool, reason: String) -> void:
	changes.append({"held": held, "reason": reason, "actor": actor.get_instance_id() if is_instance_valid(actor) else 0})

func _pair_fixture(at: Vector3 = Vector3(12.0, 0.04, 0.0)) -> void:
	# Placement occurs only while Free. All success must then use real E events.
	check(not hold.active, "pair fixture was used to move an already held actor")
	player.global_position = at
	player.velocity = Vector3.ZERO
	ceo.global_position = at + Vector3(0.0, 0.0, -0.95)
	ceo.velocity = Vector3.ZERO
	ceo.rotation.y = PI
	# Free standing-actor fixture only: do not let an earlier flee destination
	# move the prepared subject out of range before testing a new E press.
	ceo.state = "concern"
	ceo.set("_reaction_pending", false)
	ceo.set("_flee_destination", Vector3.INF)
	_aim(ceo.global_position + Vector3.UP * 1.1)
	await _advance(0.1)

func _reset() -> void:
	paused = false
	for key: String in ["move_forward", "move_back", "move_left", "move_right", "sprint", "pickup", "punch", "kick", "slam"]:
		if InputMap.has_action(key):
			Input.action_release(key)
	hold.release("test_reset")
	player.release_held()
	for obstacle: Node in obstacles:
		if is_instance_valid(obstacle):
			obstacle.queue_free()
	obstacles.clear()
	world.reset_world()
	game.call("_reset_run_state")
	game.call("_resume")
	ceo = world.ceo
	hold = player.actor_hold
	facts.clear()
	changes.clear()
	await _advance(1.6)
	check(not hold.active and hold.target == null and hold.cooldown_remaining == 0.0, "round reset retained relation/cooldown")
	await _pair_fixture()

func _grab() -> bool:
	_tap("pickup")
	await _advance(0.10)
	check(hold.active and hold.holder == player and hold.target == ceo and ceo.grabbed_by == player, "real E did not create exactly the CEO owner-target relation")
	return bool(hold.active)

func _release_count() -> int:
	var count: int = 0
	for change: Dictionary in changes:
		if not change.held:
			count += 1
	return count

func _box(at: Vector3, size: Vector3, layer: int = 1) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 15
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	body.global_position = at
	obstacles.append(body)
	return body

func _test_real_E_and_no_farming() -> void:
	await _reset()
	var initial_money: int = game.score
	var initial_heat: float = game.response_heat
	if not await _grab():
		return
	# A newly disturbed witness can apply its legitimate delayed work interruption.
	# Let that first reaction settle before measuring repeated/stationary farming.
	await _advance(1.5)
	var heat_after: float = game.response_heat
	var money_after: int = game.score
	check(ceo.collision_layer == 4 and ceo.collision_mask != 0, "grab disabled CEO environment collision like a held prop")
	check(ceo.get_parent() == world, "grab reparented the CEO under the player")
	for repeat: int in range(10):
		check(not hold.try_grab(ceo), "duplicate grab while Held was accepted")
	check(game.response_heat == heat_after and game.score == money_after, "duplicate grab added heat or money")
	var held_facts: int = 0
	var held_event: Dictionary = {}
	for event: Dictionary in facts:
		if event.get("fact", "") == "actor_held":
			held_facts += 1
			held_event = event.duplicate(true)
	check(held_facts == 1, "one accepted hold recorded more than one actor_held fact")
	for repeat: int in range(10):
		world.scenario_event.emit(held_event)
	check(game.response_heat == heat_after and game.score == money_after, "retransmitted held metadata farmed heat or dollars")
	await _advance(1.0)
	check(hold.active and game.response_heat == heat_after and game.score == money_after, "stationary holding farmed heat/money or unexpectedly released")
	var health: float = ceo.health
	for action: String in ["punch", "kick", "slam"]:
		_tap(action)
		await _advance(0.15)
	check(hold.active and ceo.health == health and player.get("_anim") == 0.0, "Held accepted/reserved an attack")
	var release_before: int = _release_count()
	_tap("pickup")
	await _advance(0.08)
	check(not hold.active and ceo.grabbed_by == null and hold.target == null, "same E did not safely release the relation")
	check(_release_count() == release_before + 1 and not is_instance_valid(player.held_prop), "E release was consumed twice or acquired a prop")
	check(ceo.state != "idle" and ceo.state != "down", "release restored stale peaceful work instead of current reaction")
	hold.release("duplicate")
	hold.release("duplicate")
	check(_release_count() == release_before + 1, "release was not idempotent")
	check(not player.get_collision_exceptions().has(ceo) and not ceo.get_collision_exceptions().has(player), "release retained the pair collision exceptions")
	observations["E_hold_release_no_farming"] = {"money_before": initial_money, "money_after": money_after, "heat_before": initial_heat, "heat_after": heat_after, "changes": changes.duplicate(true), "facts": facts.duplicate(true)}

func _test_E_priority_and_readiness() -> void:
	await _reset()
	player.perform_action("punch")
	_tap("pickup")
	check(not hold.active, "E grabbed during an accepted attack/contact recovery")
	await _advance(0.55)
	check(not hold.active, "denied E was buffered and grabbed after recovery")
	await _reset()
	var prop: RigidBody3D = world.props[0]
	# Standard held-prop setup is a fixture, not evidence for a CEO grab.
	prop.global_position = player.camera.to_global(Vector3(0.13, -0.14, -1.15))
	prop.set_held(true)
	player.held_prop = prop
	_tap("pickup")
	await _advance(0.08)
	check(not is_instance_valid(player.held_prop) and not hold.active, "one E dropped a prop and also grabbed the CEO")
	check(changes.is_empty(), "dropping a held prop recorded a CEO grab")
	await _reset()
	player.global_position += Vector3(0.0, 0.0, 1.0)
	_aim(ceo.global_position + Vector3.UP)
	await _advance(0.08)
	_tap("pickup")
	await _advance(0.08)
	check(not hold.active, "out-of-range E grabbed the CEO")
	await _reset()
	var kim: Node3D = world.opening_boss
	check(not hold.try_grab(kim), "CEO-only pilot allowed grabbing Kim/the protected opening actor")
	observations["E_precedence_readiness_distance_only_CEO"] = true

func _test_physical_pair() -> void:
	await _reset()
	if not await _grab():
		return
	var start_player: Vector3 = player.global_position
	var start_ceo: Vector3 = ceo.global_position
	Input.action_press("move_back")
	Input.action_press("sprint")
	await _advance(0.55)
	Input.action_release("move_back")
	Input.action_release("sprint")
	await _advance(0.18)
	check(hold.active and player.global_position.distance_to(start_player) > 0.8 and ceo.global_position.distance_to(start_ceo) > 0.8, "real held walking did not move both physical capsules")
	check(Vector2(player.velocity.x, player.velocity.z).length() <= 3.8 * float(hold.rules.walk_scale) + 0.05, "Held sprint ignored the configured walking restriction")
	var pair_distance: float = Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(ceo.global_position.x, ceo.global_position.z))
	check(pair_distance >= 0.60 and pair_distance <= 1.2, "paired locomotion overlapped or lost the CEO capsule")
	# A new layer-1 wall ahead of both capsules tests the actual swept move path.
	var barrier_z: float = maxf(player.global_position.z, ceo.global_position.z) + 1.0
	_box(Vector3(12.0, 1.4, barrier_z), Vector3(4.5, 2.8, 0.2))
	await _advance(0.08)
	Input.action_press("move_back")
	await _advance(0.9)
	Input.action_release("move_back")
	await _advance(0.12)
	check(player.global_position.z < barrier_z - 0.24 and ceo.global_position.z < barrier_z - 0.24, "a held capsule crossed the blocking wall")
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(1800.0, 0.0)
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await _advance(0.15)
	check(player.global_position.z < barrier_z - 0.24 and ceo.global_position.z < barrier_z - 0.24, "rapid real mouse turn carried a capsule through the wall")
	observations["real_pair_walk_wall_rapid_rotation"] = {"player": str(player.global_position), "ceo": str(ceo.global_position), "barrier_z": barrier_z, "still_held": hold.active}

func _test_grab_geometry_rejection() -> void:
	await _reset()
	_box(Vector3(12.0, 1.35, -0.48), Vector3(2.0, 2.7, 0.08))
	await _advance(0.06)
	_tap("pickup")
	await _advance(0.06)
	check(not hold.active and changes.is_empty(), "E grabbed the CEO through a solid torso occluder")
	await _reset()
	# Both legal lateral alignments are occupied, but the Free subject remains
	# outside the pillars. This tests refusal, not teleporting into penetration.
	_box(Vector3(12.55, 1.25, -0.63), Vector3(0.32, 2.5, 0.32))
	_box(Vector3(11.45, 1.25, -0.63), Vector3(0.32, 2.5, 0.32))
	await _advance(0.06)
	var actor_before: Vector3 = ceo.global_position
	_tap("pickup")
	await _advance(0.06)
	check(not hold.active and changes.is_empty() and ceo.global_position.distance_to(actor_before) < 0.05, "unsafe initial alignment grabbed or forced the CEO through occupied space")
	await _reset()
	await _pair_fixture(Vector3(12.0, 0.55, 0.0))
	_tap("pickup")
	check(not hold.active, "midair/unsupported pair was accepted")
	observations["torso_occlusion_occupied_alignment_unsupported_floor"] = true

func _test_pause_timeout_cooldown() -> void:
	await _reset()
	if not await _grab():
		return
	var age_before: float = hold.age
	var player_before: Vector3 = player.global_position
	var ceo_before: Vector3 = ceo.global_position
	game.call("_open_menu", false)
	_tap("pickup")
	for i: int in range(20):
		await process_frame
	check(hold.active and is_equal_approx(hold.age, age_before), "menu pause released the pair or consumed hold time")
	check(player.global_position.distance_to(player_before) < 0.001 and ceo.global_position.distance_to(ceo_before) < 0.001, "one held body moved during pause")
	game.call("_resume")
	await _advance(float(hold.rules.hold_seconds) - age_before + 0.15)
	check(not hold.active and changes[-1].reason == "timeout", "configured hold time did not safely release")
	await _pair_fixture()
	_tap("pickup")
	await _advance(0.05)
	check(not hold.active, "E bypassed the release/regrab cooldown")
	await _advance(float(hold.rules.regrab_seconds) + 0.1)
	await _pair_fixture()
	await _grab()
	check(hold.active, "a fresh E could not grab after cooldown")
	observations["pause_timeout_cooldown"] = {"hold_seconds": hold.rules.hold_seconds, "regrab_seconds": hold.rules.regrab_seconds, "changes": changes.duplicate(true)}

func _test_hit_missing_actor_and_result() -> void:
	await _reset()
	if await _grab():
		var health_before: float = ceo.health
		ceo.receive_hit(Vector3(0.3, 0.0, 0.3), ceo.global_position, 20.0)
		check(not hold.active and ceo.health < health_before and ceo.grabbed_by == null, "CEO hit did not release before applying normal damage")
	await _reset()
	if await _grab():
		var composure: float = game.composure
		world.player_hit.emit(10.0)
		check(not hold.active and game.composure == composure - 10.0, "player hit was ignored while Held or failed to release")
	await _reset()
	if await _grab():
		world.npcs.erase(ceo)
		world.remove_child(ceo)
		# Player's motion callback can run before its child hold controller next
		# ticks. The limiter must clear a detached target before any world query.
		hold.limit_motion(Vector3.ZERO)
		check(not hold.active, "player motion limiter retained a detached target until a later tick")
		ceo.queue_free()
		await process_frame
		await _advance(0.1)
		check(not hold.active and hold.target == null, "target removal left a stale Held relation")
	await _reset()
	if await _grab():
		game.call("_end_run")
		check(game.ended and not hold.active and ceo.grabbed_by == null, "actual result retained a held pair/input limit")
		check(game.damage_ledger.is_frozen(), "actual result did not freeze the original dollar ledger")
	observations["normal_hit_missing_actor_result_release"] = true

func _test_real_saved_scene_restart() -> void:
	await _reset()
	if not await _grab():
		return
	var previous_round: String = world.events.round_id
	var previous_game: int = game.get_instance_id()
	var event: Dictionary = facts[0].duplicate(true) if not facts.is_empty() else {}
	game.call("_restart")
	var frames: int = 0
	while (not is_instance_valid(current_scene) or current_scene.get_instance_id() == previous_game) and frames < 120:
		await process_frame
		frames += 1
	check(frames < 120, "_restart failed to reload main.tscn")
	if frames >= 120:
		return
	game = current_scene as Node3D
	game.set("_automated_run", true)
	game.call("_resume")
	world = game.world
	player = game.player
	ceo = world.ceo
	hold = player.actor_hold
	world.scenario_event.connect(_capture_fact)
	hold.holding_changed.connect(_capture_change)
	check(not hold.active and hold.target == null and hold.cooldown_remaining == 0.0 and hold.age == 0.0, "actual scene restart retained temporary hold state")
	check(world.events.round_id != previous_round, "actual scene restart reused the prior round")
	var money: int = game.score
	var heat: float = game.response_heat
	world.scenario_event.emit(event)
	check(game.score == money and game.response_heat == heat, "old round metadata raised the new round's ledger/heat")
	await _advance(1.6)
	await _pair_fixture()
	await _grab()
	observations["actual_scene_restart_and_old_metadata"] = {"new_round": world.events.round_id, "fresh_E_works": hold.active}

func _run() -> void:
	print("CEO_HOLD_REGRESSION_BEGIN")
	Engine.time_scale = 3.0
	game = MainScene.instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	game.set("_automated_run", true)
	game.call("_resume")
	world = game.world
	player = game.player
	ceo = world.ceo
	hold = player.actor_hold
	world.scenario_event.connect(_capture_fact)
	hold.holding_changed.connect(_capture_change)
	check(world.ceo_hold == hold, "world police provider and player control have different hold authorities")
	await _test_real_E_and_no_farming()
	await _test_E_priority_and_readiness()
	await _test_physical_pair()
	await _test_grab_geometry_rejection()
	await _test_pause_timeout_cooldown()
	await _test_hit_missing_actor_and_result()
	await _test_real_saved_scene_restart()
	observations["fixture_scope"] = "Free actor/prop placements and stress obstacles are fixtures. All successful holds/releases use E input; live movement/turns use normal input. Specialized police LOS/windup tests are separate."
	observations["failures"] = failures
	print(JSON.stringify(observations, "\t"))
	paused = false
	Engine.time_scale = 1.0
	game.queue_free()
	await process_frame
	await process_frame
	print("CEO_HOLD_REGRESSION_OK" if failures.is_empty() else "CEO_HOLD_REGRESSION_FAILED")
	quit(0 if failures.is_empty() else 1)
