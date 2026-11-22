extends SceneTree
## Real saved MainScene action/impact transactions that cause first police arrival.
## Full must finish the initiating hit's assessments before holding the world.
## Fixture scope: existing phase-2 heat/recovery, low-health living CEO, and a
## standard held mug aimed at a frozen but collidable existing printer. Success
## uses real punch/throw input, native prop contact and production ledger signals.
const WorldScript: Script = preload("res://scripts/world.gd")
const TOP: float = WorldScript.EXECUTIVE_ELEVATION
const MainScene: PackedScene = preload("res://scenes/main.tscn")
var game: Node3D
var world: Node3D
var player: CharacterBody3D
var signals: Array[Dictionary] = []
var facts: Array[Dictionary] = []
var failures: Array[String] = []
var observations: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("POLICE_ARRIVAL_DAMAGE_CHECK: " + message)

func _tap(action: String) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _aim(at: Vector3) -> void:
	var offset: Vector3 = at - player.camera.global_position
	player.rotation.y = atan2(-offset.x, -offset.z)
	player.set("_pitch", atan2(offset.y, Vector2(offset.x, offset.z).length()))
	player.set("_shake", 0.0)
	player.camera.rotation = Vector3(float(player.get("_pitch")), 0.0, 0.0)

func _capture(id: String, category: String, amount: int, label: String) -> void:
	signals.append({"id": id, "category": category, "amount": amount, "label": label, "paused_at_emit": paused})

func _capture_fact(event: Dictionary) -> void:
	facts.append(event.duplicate(true))

func _fact_for(kind: String, actor: Node, root_id: String) -> Dictionary:
	for event: Dictionary in facts:
		if event.get("fact", "") == kind and event.get("target_id", "") == str(actor.get_instance_id()) and event.get("root_action_id", "") == root_id:
			return event
	return {}

func _fixture(mode: String) -> void:
	paused = false
	if is_instance_valid(game):
		game.police_arrival.cancel()
		game.sound.stop_all()
		game.queue_free()
		await process_frame
		await process_frame
	game = MainScene.instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	game.set("_automated_run", true)
	game.call("_resume")
	world = game.world
	player = game.player
	game.police_arrival.mode = mode
	for i: int in range(105):
		await physics_frame
	game.call("_set_phase", 2)
	game.elapsed = 20.0
	game.set("_response_changed_at", 0.0)
	signals.clear()
	facts.clear()
	world.damage_assessed.connect(_capture)
	world.scenario_event.connect(_capture_fact)

func _wait_for(condition: Callable, message: String) -> bool:
	var end: int = Time.get_ticks_msec() + 5000
	while not bool(condition.call()) and Time.get_ticks_msec() < end:
		# SceneTree timer can observe completion even after Full takes the pause.
		await create_timer(0.02, true).timeout
	var done: bool = bool(condition.call())
	check(done, message)
	return done

func _assert_pause_owner(mode: String) -> void:
	check(game.phase == 3 and game.police_arrival.presented, mode + " action did not dispatch the first actual police")
	check(game.police_arrival.owns_world_pause() == (mode == "full") and paused == (mode == "full"), mode + " pause ownership disagrees with presentation mode")

func _punch_down_transaction(mode: String) -> void:
	await _fixture(mode)
	var ceo: CharacterBody3D = world.ceo
	player.global_position = ceo.global_position + Vector3(0.0, 0.0, 0.95)
	player.velocity = Vector3.ZERO
	_aim(ceo.global_position + Vector3.UP * 1.1)
	for i: int in range(8):
		await physics_frame
	ceo.health = 18.0
	game.response_heat = 17.0
	var before: Dictionary = game.damage_ledger.breakdown()
	_tap("punch")
	if not await _wait_for(func() -> bool: return ceo.state == "down", mode + " actual punch did not down the living fixture"):
		return
	_assert_pause_owner(mode)
	var after: Dictionary = game.damage_ledger.breakdown()
	var actual_signals: Array[Dictionary] = signals.duplicate(true)
	check(int(after.care) - int(before.care) == 300000, mode + " lost the initiating punch's real care assessment")
	check(int(after.work) - int(before.work) == 200000, mode + " lost the initiating punch's cumulative work assessment")
	check(int(after.response) - int(before.response) == 500000, mode + " did not record one original police dispatch cost")
	if mode == "full":
		var saw_paused_care: bool = false
		for event: Dictionary in signals:
			if event.category == "care" and event.paused_at_emit:
				saw_paused_care = true
		check(saw_paused_care, "Full fixture did not exercise assessment after its synchronous pause")
		var total: int = game.score
		var heat: float = game.response_heat
		for repeat: int in range(8):
			world.damage_assessed.emit(str(ceo.get_instance_id()), "care", 300000, "same real assessment replay")
			world.damage_assessed.emit(str(ceo.get_instance_id()), "work", 200000, "same real assessment replay")
		check(game.score == total and game.response_heat == heat, "Full assessment replay farmed dollars or heat")
		game.call("_open_menu", false)
		check(paused and not game.police_arrival.owns_world_pause(), "menu retained the intro's ledger pause exemption")
		world.damage_assessed.emit("review-menu-ghost", "property", 12345, "menu invalid assessment")
		check(game.score == total, "user menu pause accepted a new damage assessment")
		world.incident_event.emit("review-menu-ghost", 3.0, ceo.global_position)
		check(game.response_heat == heat, "user menu pause accepted a new incident")
		game.call("_end_run")
		world.damage_assessed.emit("review-after-result", "care", 300000, "result invalid assessment")
		check(game.score == total and game.damage_ledger.is_frozen(), "result accepted a new assessment after ledger freeze")
		world.incident_event.emit("review-after-result", 3.0, ceo.global_position)
		check(game.response_heat == heat, "result accepted a new incident")
	observations[mode + "_real_punch_down"] = {"before": before, "after": after, "actual_signals": actual_signals, "duplicate_menu_result_checks": mode == "full"}

func _thrown_npc_transaction(mode: String) -> void:
	await _fixture(mode)
	var ceo: CharacterBody3D = world.ceo
	var witness: CharacterBody3D
	for npc: CharacterBody3D in world.npcs:
		if npc.role == "observer":
			witness = npc
			break
	check(witness != null, mode + " scene lacks the existing observer")
	if witness == null:
		return
	# Place an existing Free observer beside, outside the actual throw trajectory.
	# It keeps its original delayed reaction, dialogue and work interruption AI.
	witness.global_position = Vector3(1.5, TOP + 0.04, -2.0)
	witness.velocity = Vector3.ZERO
	player.global_position = Vector3(2.7, TOP + 0.04, 0.0)
	player.velocity = Vector3.ZERO
	_aim(ceo.global_position + Vector3.UP * 1.35)
	for i: int in range(8):
		await physics_frame
	var source: RigidBody3D
	for prop: RigidBody3D in world.props:
		if prop.kind == "mug":
			source = prop
			break
	check(source != null, mode + " NPC throw scene lacks a mug")
	if source == null:
		return
	source.set_held(true)
	source.global_position = player.camera.to_global(Vector3(0.13, -0.14, -1.15))
	source.global_basis = Basis.IDENTITY
	player.held_prop = source
	ceo.health = 18.0
	game.response_heat = 17.25
	var before: Dictionary = game.damage_ledger.breakdown()
	_tap("punch")
	var root_id: String = str((source.get_meta("scenario_origin", {}) as Dictionary).get("root_action_id", ""))
	if not await _wait_for(func() -> bool: return ceo.state == "down", mode + " real mug throw did not strike/down the CEO"):
		return
	_assert_pause_owner(mode)
	var after: Dictionary = game.damage_ledger.breakdown()
	# This existing collision reports THROW +1 before the struck NPC reports
	# ASSAULT +3. Intro presentation must not change that accepted transaction.
	check(is_equal_approx(game.response_heat, 21.25), mode + " lost/duplicated an incident inside the same actual throw collision")
	check(int(after.property) - int(before.property) == 10000 and int(after.care) - int(before.care) == 300000 and int(after.work) - int(before.work) == 200000, mode + " lost the same NPC throw's original property/care/work costs")
	var contact: Dictionary = _fact_for("action_contact", ceo, root_id)
	check(not contact.is_empty() and contact.get("validated", false) == true and contact.get("instigator_id", "") == "player" and contact.get("round_id", "") == world.events.round_id, mode + " lost the real player collision's contact/root/round fact")
	if mode == "full":
		check(_fact_for("npc_reaction", witness, root_id).is_empty(), "Full credited a pending observer reaction before it applied")
		await create_timer(0.15, true).timeout
		check(_fact_for("npc_reaction", witness, root_id).is_empty(), "Full applied/credited a fresh observer reaction during world pause")
		game.police_arrival.cancel()
	if await _wait_for(func() -> bool: return not _fact_for("npc_reaction", witness, root_id).is_empty(), mode + " actual observer reaction did not preserve the accepted throw origin after resume"):
		var reaction: Dictionary = _fact_for("npc_reaction", witness, root_id)
		check(witness.state not in ["idle", "down"] and reaction.get("validated", false) == true, mode + " observer fact preceded a living applied reaction")
	observations[mode + "_real_throw_npc"] = {"health": ceo.health, "heat": game.response_heat, "before": before, "after": after, "contact": contact, "actual_witness_reaction": _fact_for("npc_reaction", witness, root_id)}

func _thrown_prop_transaction() -> void:
	await _fixture("full")
	player.global_position = Vector3(2.0, TOP + 0.04, 0.0)
	player.velocity = Vector3.ZERO
	_aim(player.camera.global_position + Vector3(0.0, 0.0, -5.0))
	for i: int in range(8):
		await physics_frame
	var source: RigidBody3D
	var target: RigidBody3D
	for prop: RigidBody3D in world.props:
		if source == null and prop.kind == "mug":
			source = prop
		elif target == null and prop.kind == "printer":
			target = prop
	check(source != null and target != null, "actual scene lacks the mug/printer fixtures")
	if source == null or target == null:
		return
	# Freeze only the intact receiver; its actual collision and hit handler remain.
	target.freeze = true
	target.global_position = Vector3(2.13, player.camera.global_position.y - 0.14, -3.0)
	target.global_basis = Basis.IDENTITY
	# Standard held-object placement is a fixture. Real LMB launches the mug and
	# a native body_entered contact causes the source incident plus receiver damage.
	source.set_held(true)
	source.global_position = player.camera.to_global(Vector3(0.13, -0.14, -1.15))
	source.global_basis = Basis.IDENTITY
	player.held_prop = source
	game.response_heat = 17.25
	var before: Dictionary = game.damage_ledger.breakdown()
	_tap("punch")
	if not await _wait_for(func() -> bool: return target.damage_stage > 0, "real thrown mug did not collide with and damage the intact printer"):
		observations["throw_fixture_failed"] = {"source": str(source.global_position), "target": str(target.global_position), "signals": signals}
		return
	_assert_pause_owner("full")
	var after: Dictionary = game.damage_ledger.breakdown()
	var actual_signals: Array[Dictionary] = signals.duplicate(true)
	var expected: int = int(source.damage_total) + int(target.damage_total)
	check(expected > 10000 and int(after.property) - int(before.property) == expected, "Full lost the same throw collision's receiver property assessment")
	var paused_receiver: bool = false
	for event: Dictionary in signals:
		if event.id == str(target.get_instance_id()) and event.category == "property" and event.paused_at_emit:
			paused_receiver = true
	check(paused_receiver, "throw fixture did not exercise actual receiver damage after Full pause")
	var total: int = game.score
	var heat: float = game.response_heat
	for repeat: int in range(8):
		world.damage_assessed.emit(str(source.get_instance_id()), "property", source.damage_total, "source same assessment replay")
		world.damage_assessed.emit(str(target.get_instance_id()), "property", target.damage_total, "receiver same assessment replay")
	check(game.score == total and game.response_heat == heat, "throw assessment replay added money or heat")
	observations["full_native_throw_receiver"] = {"before": before, "after": after, "source_damage": source.damage_total, "receiver_damage": target.damage_total, "actual_signals": actual_signals, "duplicate_replays": 8}

func _run() -> void:
	print("POLICE_ARRIVAL_DAMAGE_REGRESSION_BEGIN")
	for mode: String in ["full", "short", "off"]:
		await _punch_down_transaction(mode)
	for mode: String in ["full", "short", "off"]:
		await _thrown_npc_transaction(mode)
	await _thrown_prop_transaction()
	observations["failures"] = failures
	print(JSON.stringify(observations, "\t"))
	paused = false
	if is_instance_valid(game):
		game.police_arrival.cancel()
		game.sound.stop_all()
		game.queue_free()
	await process_frame
	await process_frame
	# Audio playback command cleanup is asynchronous in the real mixer. Give its
	# stopped WAV voices one short wall-clock drain after the scene was freed.
	OS.delay_msec(150)
	await process_frame
	print("POLICE_ARRIVAL_DAMAGE_REGRESSION_OK" if failures.is_empty() else "POLICE_ARRIVAL_DAMAGE_REGRESSION_FAILED")
	quit(0 if failures.is_empty() else 1)
