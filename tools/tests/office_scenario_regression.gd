extends SceneTree
## Integration regression: actual Main/world, actual accepted player actions,
## actual CEO locomotion. Fixtures position the player/loose props, never assign
## route.status/outcome or teleport a CEO to manufacture A/B reachability.
## Headless proves state/integration only, not screen quality or enjoyment.

const MainScript: Script = preload("res://scripts/main.gd")
const MainScene: PackedScene = preload("res://scenes/main.tscn")
const RouteScript: Script = preload("res://scripts/scenario/office_route.gd")
const PUBLIC: Vector3 = Vector3(9.9, 0.02, -0.8)
const VISITOR: Vector3 = Vector3(12.5, 0.02, 0.8)

var game: Node3D
var world: Node3D
var player: CharacterBody3D
var route: Node
var failures: Array[String] = []
var observations: Dictionary = {"fixture_policy": "Player and loose-prop positions may be arranged before real actions. CEO motion is real except explicitly named blocked/destination-change fixtures. No route status/outcome writes."}
var facts: Array[Dictionary] = []
var fixture_log: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("OFFICE_SCENARIO_CHECK: " + message)

func _capture(event: Dictionary) -> void:
	facts.append(event.duplicate(true))

func _advance(seconds: float) -> void:
	var until: float = world.scenario_time + seconds
	var frames: int = 0
	var wall_start: int = Time.get_ticks_msec()
	while world.scenario_time < until and frames < 24000:
		await physics_frame
		frames += 1
		if Time.get_ticks_msec() - wall_start > 30000:
			check(false, "simulation wait timed out: clock %s / target %s, paused %s" % [world.scenario_time, until, paused])
			break
	check(frames < 24000, "simulation clock stopped before requested interval")

func _wait_candidate(seconds: float = 4.5) -> void:
	var until: float = world.scenario_time + seconds
	var wall_start: int = Time.get_ticks_msec()
	while not route.candidate.is_empty() and world.scenario_time < until:
		await physics_frame
		if Time.get_ticks_msec() - wall_start > 10000:
			check(false, "candidate wait stalled: %s; clock %s, paused %s, ended %s, CEO %s" % [str(route.candidate), world.scenario_time, paused, game.ended, str(route.ceo.global_position)])
			break

func _fixture_player(at: Vector3, look_at: Vector3) -> void:
	fixture_log.append("player placement %s" % str(at))
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.camera.look_at(look_at, Vector3.UP)
	player.set("_pitch", player.camera.rotation.x)
	player.set("_shake", 0.0)

func _fixture_prop(item: RigidBody3D, at: Vector3) -> void:
	fixture_log.append("loose-prop placement: " + str(item.display_name))
	item.freeze = true
	item.global_position = at
	item.global_rotation = Vector3.ZERO
	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO

func _pickup(item: RigidBody3D, at: Vector3) -> bool:
	_fixture_prop(item, at)
	_fixture_player(Vector3(at.x, 0.08, at.z + 1.15), at + Vector3(0.0, 0.08, 0.0))
	await _advance(0.05)
	var hit: Dictionary = player.call("_ray", 2.7)
	check(hit.get("collider") == item, "fixture did not aim the pickup ray at " + str(item.display_name))
	player.call("_pickup_or_drop")
	check(player.held_prop == item and item.held, "real pickup did not acquire " + str(item.display_name))
	return player.held_prop == item

func _carry_and_drop(at: Vector3, facing: Vector3) -> void:
	_fixture_player(at, facing)
	# The existing collision-swept carrying code moves the held object.
	await _advance(0.20)
	player.call("_pickup_or_drop")
	await _advance(0.05)

func _start_by_slam() -> void:
	_fixture_player(Vector3(12.7, 0.08, -3.0), Vector3(12.7, 1.0, -4.2))
	player.perform_action("slam")
	await _advance(0.48)
	check(route.status == "active", "real first CEO desk contact did not activate the optional route")
	check(player.get("_slam_confirmed"), "CEO desk slam was not confirmed by the actual world")

func _begin_a() -> void:
	await _start_by_slam()
	var plaque: RigidBody3D = route.authority_props[0]
	if not await _pickup(plaque, Vector3(12.0, 1.05, -1.0)):
		return
	await _carry_and_drop(Vector3(10.0, 0.08, 0.4), Vector3(10.0, 1.0, -2.0))
	check(not route.candidate.is_empty() and str(route.candidate.get("result", "")) == "A", "real carry/drop at public frontage did not propose A")

func _begin_b() -> void:
	await _start_by_slam()
	var chair: RigidBody3D = route.command_prop
	if not await _pickup(chair, Vector3(13.5, 0.04, -2.8)):
		return
	await _carry_and_drop(Vector3(13.5, 0.08, 2.0), Vector3(13.5, 1.0, 0.0))
	check(not route.candidate.is_empty() and str(route.candidate.get("result", "")) == "B", "real chair carry/drop did not propose B")

func _reset() -> void:
	paused = false
	if is_instance_valid(player.held_prop):
		player.release_held()
	player.set_active(false)
	world.reset_world()
	game.call("_reset_run_state")
	game.call("_resume")
	route = world.office_route
	facts.clear()
	fixture_log.clear()
	await _advance(0.08)
	check(route.status == "available" and route.outcome.is_empty() and route.candidate.is_empty(), "reset retained a route result or pending candidate")
	check(game.chaos.total() == 0, "reset retained the previous round's Chaos")

func _test_idle_and_autonomy() -> void:
	_fixture_player(Vector3(11.0, 0.08, 0.0), Vector3(12.7, 1.3, -2.8))
	var prior_scale: float = Engine.time_scale
	Engine.time_scale = 12.0
	await _advance(90.0)
	Engine.time_scale = prior_scale
	check(route.status == "available" and route.outcome.is_empty(), "90 seconds of observation automatically selected/completed the route")
	check(game.chaos.total() == 0 and game.damage_ledger.total() == 0 and game.response_heat == 0.0, "observation generated score, damage or response heat")
	observations["observe_90_game_seconds"] = {"status": route.status, "chaos": game.chaos.total(), "seconds": world.scenario_time}
	await _start_by_slam()
	await _wait_candidate()
	var prior_special: int = int(game.chaos.breakdown().special)
	_fixture_player(Vector3(9.0, 0.08, 2.6), Vector3(12.7, 1.3, -2.8))
	Engine.time_scale = 12.0
	await _advance(90.0)
	Engine.time_scale = prior_scale
	check(route.status != "resolved" and route.outcome.is_empty(), "autonomous repositioning completed the route without a fresh action")
	check(int(game.chaos.breakdown().special) == prior_special, "autonomous repositioning paid a special reward")
	observations["autonomy_90_game_seconds"] = {"status": route.status, "special_before": prior_special, "special_after": game.chaos.breakdown().special}

func _test_physical_room_connection() -> void:
	_fixture_player(Vector3(6.5, 0.08, 0.0), Vector3(9.5, 1.7, 0.0))
	player.camera.rotation = Vector3.ZERO
	player.set("_pitch", 0.0)
	var start: Vector3 = player.global_position
	var samples: Array[String] = [str(start)]
	# One uninterrupted physical trip: after this point no fixture placement is
	# used until the trip ends. The preserved shelf occupies the door center,
	# so walk around its north edge before crossing and return to z=0.
	for destination: Vector3 in [Vector3(6.5, 0.0, -1.35), Vector3(9.5, 0.0, -1.35), Vector3(9.5, 0.0, 0.0)]:
		var offset: Vector3 = destination - player.global_position
		player.rotation.y = atan2(-offset.x, -offset.z)
		var deadline: float = world.scenario_time + 1.2
		Input.action_press("move_forward")
		Input.action_press("sprint")
		while Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(destination.x, destination.z)) > 0.65 and world.scenario_time < deadline:
			await physics_frame
			samples.append(str(player.global_position))
		Input.action_release("move_forward")
		Input.action_release("sprint")
		await _advance(0.28)
	var finish: Vector3 = player.global_position
	check(finish.x >= 9.0 and finish.x < 10.2 and absf(finish.z) < 0.4, "real forward/sprint movement could not cross the east doorway around the preserved shelf from office into CEO room")
	check(finish.y > -0.2 and finish.y < 0.3, "physical east-door crossing fell through a floor seam or needed teleport recovery")
	check(route.status == "available" and game.response_heat == 0.0 and game.chaos.total() == 0, "walking into the connected room selected/scored the route")
	observations["physical_east_door_connection"] = {"start": str(start), "end": str(finish), "samples": samples, "action": "held move_forward+sprint only; short detour around existing shelf; no teleport during crossing", "route_status": route.status}
	player.rotation.y = 0.0

func _test_a_and_result() -> void:
	await _reset()
	var ceo_start: Vector3 = route.ceo.global_position
	await _begin_a()
	await _wait_candidate()
	check(route.status == "resolved" and route.outcome == "A", "A was unreachable through actual slam/pickup/carry/drop and CEO locomotion")
	check(route.ceo.global_position.distance_to(ceo_start) > 1.0, "A did not physically move the CEO")
	check(Vector2(route.ceo.global_position.x, route.ceo.global_position.z).distance_to(Vector2(PUBLIC.x, PUBLIC.z)) < 0.9, "A confirmed before actual public-zone arrival")
	check(not route.ceo.commanding, "A did not stop the CEO's orders")
	check(int(game.chaos.breakdown().terminal) == 400, "A did not award exactly 400 terminal Chaos")
	var before: int = game.chaos.total()
	for event: Dictionary in facts.duplicate(true):
		for repeat: int in range(10):
			world.scenario_event.emit(event)
	check(game.chaos.total() == before, "retransmitting actual integration facts duplicated rewards")
	var snapshot: Dictionary = {"status": route.status, "outcome": route.outcome, "ceo_position": str(route.ceo.global_position), "chaos": game.chaos.breakdown(), "fixture_log": fixture_log.duplicate()}
	game.call("_end_run")
	check(game.ended and game.chaos.is_frozen() and game.damage_ledger.is_frozen(), "result did not freeze both ledgers")
	check(game.get("_result_chaos").text.contains("Chaos Score") and game.get("_result_route").text.contains("A · 대표자 현장 배치"), "result did not show distinct Chaos and A outcome")
	check(game.get("_score_label").text.begins_with("$"), "Chaos replaced the protected dollar HUD")
	var frozen: int = game.chaos.total()
	for event: Dictionary in facts.duplicate(true):
		world.scenario_event.emit(event)
	check(game.chaos.total() == frozen and route.outcome == "A", "late result events changed the frozen route/score")
	check(game.get("_settings").get_value("records", game.ChaosScript.ROUTE_RECORD_KEY, {}).get("A", false), "result did not preserve the A route record")
	observations["actual_A_and_frozen_result"] = snapshot

func _test_b() -> void:
	await _reset()
	var ceo_start: Vector3 = route.ceo.global_position
	await _begin_b()
	await _wait_candidate()
	check(route.status == "resolved" and route.outcome == "B", "B was unreachable through actual chair manipulation and CEO locomotion")
	check(route.ceo.global_position.distance_to(ceo_start) > 1.0 and not route.ceo.commanding, "B did not visibly retreat the CEO and stop commands")
	check(Vector2(route.ceo.global_position.x, route.ceo.global_position.z).distance_to(Vector2(VISITOR.x, VISITOR.z)) < 0.9, "B confirmed before visitor-zone arrival")
	check(int(game.chaos.breakdown().terminal) == 400, "B terminal reward differs from A's 400")
	observations["actual_B"] = {"outcome": route.outcome, "ceo_position": str(route.ceo.global_position), "chair_position": str(route.command_prop.global_position), "chaos": game.chaos.breakdown(), "fixture_log": fixture_log.duplicate()}
	await _reset()
	var chair: RigidBody3D = route.command_prop
	_fixture_player(Vector3(13.5, 0.08, -1.2), chair.global_position + Vector3.UP * 0.5)
	for attempt: int in range(3):
		player.camera.look_at(chair.global_position + Vector3.UP * 0.5, Vector3.UP)
		player.set("_pitch", player.camera.rotation.x)
		player.perform_action("kick")
		await _advance(0.65)
	await _wait_candidate()
	check(route.outcome == "B" and int(game.chaos.breakdown().terminal) == 400, "direct chair kicks did not reach B without requiring intermediate turns")
	observations["direct_B_real_kicks"] = {"outcome": route.outcome, "chaos": game.chaos.breakdown(), "fixture_log": fixture_log.duplicate()}
	var settings: ConfigFile = game.get("_settings")
	settings.set_value("records", "high_score", 98765)
	settings.set_value("records", "social_damage_krw_v1", 24680000)
	game.chaos_high_score = 777
	settings.set_value("records", game.ChaosScript.RECORD_KEY, 777)
	game.call("_end_run")
	check(int(settings.get_value("records", game.ChaosScript.RECORD_KEY, 0)) >= 777, "Chaos result lowered the prior Chaos high score")
	var route_records: Dictionary = settings.get_value("records", game.ChaosScript.ROUTE_RECORD_KEY, {})
	check(route_records.get("A", false) and route_records.get("B", false), "A/B records did not accumulate independently across in-memory round resets")
	check(settings.get_value("records", "high_score", 0) == 98765 and settings.get_value("records", "social_damage_krw_v1", 0) == 24680000, "Chaos result overwrote unrelated legacy record keys")
	observations["ConfigFile_record_namespaces"] = {"chaos_best": settings.get_value("records", game.ChaosScript.RECORD_KEY), "A_and_B": route_records, "legacy_points": settings.get_value("records", "high_score"), "legacy_krw": settings.get_value("records", "social_damage_krw_v1"), "scope": "actual result writer / in-memory ConfigFile; automated test does not write user settings"}

func _test_exit_and_resume() -> void:
	await _reset()
	await _begin_a()
	var prior: int = int(game.chaos.breakdown().special)
	_fixture_player(Vector3(5.7, 0.08, 0.0), Vector3(10.0, 1.0, 0.0))
	await _advance(0.10)
	check(route.status == "suspended" and route.candidate.is_empty(), "leaving the local area did not suspend/cancel the candidate")
	await _advance(9.0)
	check(route.status == "suspended" and route.outcome.is_empty(), "old eight-second abandonment/autonomous completion survived v0.2")
	_fixture_player(Vector3(10.0, 0.08, 0.4), Vector3(12.0, 1.0, 0.0))
	await _advance(0.12)
	check(route.status == "active" and route.candidate.is_empty(), "return did not resume current content without restoring the stale candidate")
	check(int(game.chaos.breakdown().special) == prior, "exit/resume repaid special progress")
	var plaque: RigidBody3D = route.authority_props[0]
	if await _pickup(plaque, Vector3(11.7, 1.0, -0.5)):
		await _carry_and_drop(Vector3(10.0, 0.08, 0.4), Vector3(10.0, 1.0, -2.0))
		await _wait_candidate()
	check(route.status == "resolved" and route.outcome == "A", "a fresh actual manipulation could not resolve A after exit/resume")
	observations["exit_resume_and_fresh_action"] = {"status": route.status, "outcome": route.outcome, "fixture_log": fixture_log.duplicate()}

func _test_cancel_conditions() -> void:
	await _reset()
	await _begin_a()
	fixture_log.append("blocked locomotion fixture: CEO physics disabled after real A proposal")
	route.ceo.set_physics_process(false)
	await _advance(2.15)
	check(route.candidate.is_empty() and route.status != "resolved", "two seconds without locomotion progress did not cancel A")
	route.ceo.set_physics_process(true)
	await _advance(3.0)
	check(route.outcome.is_empty(), "late autonomous arrival resurrected a canceled candidate")
	observations["blocked_candidate"] = {"status": route.status, "outcome": route.outcome, "fixture_log": fixture_log.duplicate()}
	await _reset()
	await _begin_a()
	fixture_log.append("destination replacement fixture: CEO move_to visitor after real A proposal")
	route.ceo.move_to(VISITOR)
	await _advance(0.1)
	check(route.candidate.is_empty() and route.outcome.is_empty(), "destination replacement did not discard the previous cause")
	await _reset()
	await _begin_a()
	fixture_log.append("autonomous hit fixture: CEO receive_hit without a player origin")
	route.ceo.receive_hit(Vector3(0.4, 0.0, 0.4), route.ceo.global_position, 18.0)
	await _advance(0.10)
	check(route.candidate.is_empty() and route.outcome.is_empty(), "new autonomous hit did not invalidate the old player result candidate")
	check(route.status == "active", "nonlethal hit permanently failed the optional route")
	await _reset()
	await _begin_a()
	fixture_log.append("expiry clock fixture: route tick +4.01 without actor motion")
	route.call("_physics_process", 4.01)
	check(route.candidate.is_empty() and route.outcome.is_empty(), "four-second expiry did not cancel A")
	await _reset()
	await _start_by_slam()
	fixture_log.append("incapacity fixture: actual CEO receive_hit with lethal damage")
	route.ceo.receive_hit(Vector3(0.5, 0.0, 0.5), route.ceo.global_position, 200.0)
	await _advance(0.1)
	check(route.status == "failed" and route.candidate.is_empty() and route.outcome.is_empty(), "CEO incapacity did not fail only the optional route")
	check(game.playing and not game.ended and player.enabled, "CEO incapacity ended/blocked the sandbox")
	observations["expiry_destination_down"] = {"status": route.status, "sandbox_playing": game.playing, "fixture_log": fixture_log.duplicate()}

func _test_old_round_and_restart() -> void:
	await _reset()
	await _begin_a()
	var old_round: String = world.events.round_id
	var old_event: Dictionary = facts[-1].duplicate(true) if not facts.is_empty() else {}
	await _reset()
	check(world.events.round_id != old_round, "restart reused the old round ID")
	world.scenario_event.emit(old_event)
	check(game.chaos.total() == 0, "old round fact contaminated the new score")
	route.on_action(old_event, route.ceo)
	check(route.status == "available" and route.candidate.is_empty(), "old round action reached the new route")
	await _advance(4.5)
	check(route.status == "available" and route.outcome.is_empty(), "discarded old route callback completed/spoke into a new round")
	_fixture_player(Vector3(0.0, 0.08, 0.65), Vector3(0.0, 1.0, -1.0))
	player.perform_action("slam")
	await _advance(0.6)
	check(world.opening_started, "new round no longer supported the original office desk opening")
	check(int(game.chaos.breakdown().actions) == 40 and int(game.chaos.breakdown().npc_reactions) >= 30, "actual protected desk startle failed to award its first valid action/NPC reaction")
	check(route.status == "available", "original office desk incorrectly selected the CEO route")
	observations["restart_old_round_original_office"] = {"new_round": world.events.round_id, "opening_started": world.opening_started, "route_status": route.status}
	await _reset()
	await _begin_a()
	var old_game_id: int = game.get_instance_id()
	var old_round_id: String = world.events.round_id
	var old_applied_event: Dictionary = facts[-1].duplicate(true)
	# PackedScene instance gives reload_current_scene its actual saved scene path.
	game.call("_restart")
	var reload_frames: int = 0
	while (not is_instance_valid(current_scene) or current_scene.get_instance_id() == old_game_id) and reload_frames < 120:
		await process_frame
		reload_frames += 1
	check(reload_frames < 120, "actual _restart did not reload the saved main.tscn")
	if reload_frames >= 120:
		return
	game = current_scene as Node3D
	game.set("_automated_run", true)
	game.call("_resume")
	world = game.world
	player = game.player
	route = world.office_route
	world.scenario_event.connect(_capture)
	check(world.events.round_id != old_round_id and route.status == "available" and game.chaos.total() == 0, "real scene reload retained the old route or Chaos")
	world.scenario_event.emit(old_applied_event)
	route.on_action(old_applied_event, route.ceo)
	await _advance(0.1)
	check(route.status == "available" and game.chaos.total() == 0, "old applied event contaminated actual reloaded scene")
	observations["actual_saved_scene_restart"] = {"scene_path": game.scene_file_path, "old_game_id": old_game_id, "new_game_id": game.get_instance_id(), "old_event_rejected": game.chaos.total() == 0}

func _test_no_stale_command_or_motion_rewards() -> void:
	await _reset()
	fixture_log.append("prebroken command fixture: chair receive_hit outside player-contact context before route selection")
	var chair: RigidBody3D = route.command_prop
	chair.receive_hit(Vector3.ZERO, chair.global_position, 200.0)
	check(chair.damage_stage == 2, "prebroken command fixture did not break the chair")
	_fixture_player(Vector3(13.5, 0.08, -1.2), chair.global_position + Vector3.UP * 0.5)
	player.perform_action("kick")
	await _advance(0.3)
	check(str(route.candidate.get("result", "")) != "B", "new kick on already broken chair proposed a false fresh command loss")
	await _wait_candidate()
	check(route.outcome != "B" and int(game.chaos.breakdown().terminal) == 0, "already broken command furniture paid a terminal result")
	observations["prebroken_command_not_recredited"] = {"outcome": route.outcome, "terminal": game.chaos.breakdown().terminal, "fixture_log": fixture_log.duplicate()}
	await _reset()
	fixture_log.append("no-motion fixture: CEO starts at visitor destination; used only to test nonterminal movement proof")
	route.ceo.global_position = VISITOR
	route.ceo.velocity = Vector3.ZERO
	route.ceo.settle(Vector3(12.7, 1.0, -4.2), false)
	await _start_by_slam()
	await _wait_candidate()
	check(int(game.chaos.breakdown().interventions) == 0, "an intervention with no actual CEO displacement paid 100")
	observations["nonterminal_motion_required"] = {"interventions": game.chaos.breakdown().interventions, "fixture_log": fixture_log.duplicate()}
	await _reset()
	fixture_log.append("actor departure fixture: CEO removed and freed before another route tick")
	var actor: Node = route.ceo
	world.npcs.erase(actor)
	world.remove_child(actor)
	actor.queue_free()
	await process_frame
	await _advance(0.15)
	check(route.status == "failed" and route.candidate.is_empty() and game.playing, "missing CEO did not fail the optional route while keeping the sandbox playable")
	observations["actor_departure"] = {"status": route.status, "sandbox_playing": game.playing, "fixture_log": fixture_log.duplicate()}

func _run() -> void:
	print("OFFICE_SCENARIO_BEGIN actual MainScript integration")
	Engine.time_scale = 3.0
	game = MainScene.instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	game.set("_automated_run", true)
	game.call("_resume")
	world = game.world
	player = game.player
	route = world.office_route
	world.scenario_event.connect(_capture)
	print("OFFICE_SCENARIO_READY")
	await _advance(0.12)
	check(game.call("_staff_count", "department") == 5 and game.call("_staff_count", "other") == 2, "scenario changed the protected 5+2 staff roster")
	await _test_physical_room_connection()
	await _test_idle_and_autonomy()
	print("OFFICE_SCENARIO_IDLE_DONE")
	await _test_a_and_result()
	print("OFFICE_SCENARIO_A_DONE")
	await _test_b()
	print("OFFICE_SCENARIO_B_DONE")
	await _test_exit_and_resume()
	await _test_cancel_conditions()
	await _test_no_stale_command_or_motion_rewards()
	await _test_old_round_and_restart()
	observations["failures"] = failures
	print(JSON.stringify(observations, "\t"))
	paused = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.queue_free()
	await process_frame
	await process_frame
	print("OFFICE_SCENARIO_REGRESSION_OK" if failures.is_empty() else "OFFICE_SCENARIO_REGRESSION_FAILED")
	quit(0 if failures.is_empty() else 1)
