extends SceneTree
## Drives the saved scene through its real movement, action and pickup handlers.
const MainScene: PackedScene = preload("res://scenes/main.tscn")
const Office: Script = preload("res://scripts/world.gd")

var game: Node3D
var world: Node3D
var player: CharacterBody3D
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FLOOR_TRANSITION_CHECK: " + message)

func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame

func _bind_scene() -> void:
	game = current_scene
	world = game.world
	player = game.player
	game.set("_automated_run", true)
	game.police_arrival.mode = "off"
	game.call("_resume")
	await _frames(18)

func _tap(action: String) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var released: InputEventAction = InputEventAction.new()
	released.action = action
	Input.parse_input_event(released)
	Input.flush_buffered_events()

func _aim(at: Vector3) -> void:
	var offset: Vector3 = at - player.camera.global_position
	player.rotation.y = atan2(-offset.x, -offset.z)
	player.set("_pitch", atan2(offset.y, Vector2(offset.x, offset.z).length()))
	player.set("_shake", 0.0)
	player.camera.rotation = Vector3(float(player.get("_pitch")), 0.0, 0.0)

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _walk_to(destination: Vector3) -> void:
	var route: PackedVector3Array = world.find_navigation_path(player.global_position, destination)
	_check(not route.is_empty(), "no same-floor route to %s" % str(destination))
	for waypoint: Vector3 in route:
		for frame: int in range(130):
			if _flat_distance(player.global_position, waypoint) < 0.15:
				break
			_aim(Vector3(waypoint.x, player.camera.global_position.y, waypoint.z))
			Input.action_press("move_forward")
			await physics_frame
	_check(_flat_distance(player.global_position, destination) < 0.25,
		"walk stopped at %s on the way to %s" % [player.global_position, destination])
	Input.action_release("move_forward")
	await _frames(12)

func _move_held(action: String, frames: int) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)
	await _frames(12)

func _lift_at(floor_id: int) -> Vector3:
	return Office.ELEVATOR_LANDING + Vector3.UP * Office.FLOOR_HEIGHTS[floor_id]

func _aim_at_lift(floor_id: int) -> void:
	_aim(Office.ELEVATOR_DOOR + Vector3.UP * Office.FLOOR_HEIGHTS[floor_id])
	await _frames(2)

func _ride_from(floor_id: int) -> void:
	await _walk_to(_lift_at(floor_id))
	await _aim_at_lift(floor_id)
	var expected: String = "E 2층 사장실" if floor_id == 0 else "E 1층 사무실"
	_check(expected in str(player.get("_last_focus")), "lift destination missing from the normal focus prompt")
	_tap("pickup")
	var landing: Vector3 = _lift_at(1 - floor_id)
	_check(player.global_position.distance_to(landing) < 0.001,
		"real E did not place player at the fixed landing %s, got %s" % [landing, player.global_position])
	_check(player.velocity == Vector3.ZERO, "lift carried movement through the transition")
	await _frames(16)
	_check(player.is_on_floor() and world.floor_index(player.global_position) == 1 - floor_id,
		"player did not settle at the destination")
	print("Lift %dF -> %dF at %s" % [floor_id + 1, 2 - floor_id, landing])

func _block_destination(at: Vector3) -> StaticBody3D:
	var blocker: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.75, 2.0, 0.75)
	collision.shape = box
	blocker.position = at + Vector3.UP
	blocker.add_child(collision)
	world.add_child(blocker)
	return blocker

func _test_lift_and_hold() -> void:
	_check(world.floor_index(player.global_position) == 0 and world.floor_index(world.ceo.global_position) == 1,
		"new round placed the player or CEO on the wrong floor")
	_check(world.find_navigation_path(player.global_position, world.ceo.global_position).is_empty(),
		"one flat route ignored the elevation gap")
	await _walk_to(_lift_at(0))
	await _aim_at_lift(0)
	var blocker: StaticBody3D = _block_destination(_lift_at(1))
	await _frames(2)
	_tap("pickup")
	_check(world.floor_index(player.global_position) == 0, "lift accepted a blocked arrival")
	blocker.queue_free()
	await _frames(2)
	await _ride_from(0)
	# The upper aisle directly crosses the x/z footprint of the lower starting desk.
	var clear_aisle_end: Vector3 = Vector3(4.8, Office.EXECUTIVE_ELEVATION, -0.5)
	var upper_path: PackedVector3Array = world.find_navigation_path(
		Vector3(0.2, Office.EXECUTIVE_ELEVATION, -0.5), clear_aisle_end)
	_check(upper_path.size() == 1 and upper_path[0].is_equal_approx(clear_aisle_end),
		"lower office furniture blocked the upper aisle")

	var ceo: CharacterBody3D = world.ceo
	await _walk_to(ceo.global_position + Vector3(0.0, 0.0, 0.98))
	# Align the pair to the office opening so held sidesteps use the real doorway.
	_aim(Vector3(player.global_position.x, ceo.global_position.y + 1.1, ceo.global_position.z))
	_tap("pickup")
	var hold: Node = player.actor_hold
	_check(hold.active and hold.target == ceo and ceo.grabbed_by == player, "default CEO did not accept real E on 2F")
	var original_player: Vector3 = player.global_position
	var original_ceo: Vector3 = ceo.global_position
	await _move_held("move_back", 40)
	await _move_held("move_right", 94)
	_check(hold.active and player.global_position.distance_to(original_player) > 2.0 and
		ceo.global_position.distance_to(original_ceo) > 2.0 and player.global_position.x > 6.0 and ceo.global_position.x > 5.95,
		"held pair did not walk through the real 2F doorway: %s / %s" % [player.global_position, ceo.global_position])
	var door: StaticBody3D = world.get("_elevator_doors")[1]
	_check(not world.try_use_elevator(player, door) and hold.active, "lift transported a held pair")
	var age: float = hold.age
	var before_pause: Vector3 = player.global_position
	game.call("_open_menu", false)
	_tap("pickup")
	await process_frame
	_check(paused and hold.active and hold.age == age and player.global_position == before_pause,
		"paused E leaked or mutated the validated hold")
	game.call("_resume")
	_tap("pickup")
	_check(not hold.active and ceo.grabbed_by == null and world.floor_index(player.global_position) == 1,
		"the release E also changed floors or left a held relation")
	await _ride_from(1)

func _test_combat(floor_id: int) -> void:
	var height: float = Office.FLOOR_HEIGHTS[floor_id]
	var attack_from: Vector3 = Vector3(-0.8, height, 4.1) if floor_id == 0 else Vector3(2.0, height, 0.50)
	await _walk_to(attack_from)
	var npc: CharacterBody3D = world.opening_coworker if floor_id == 0 else world.ceo
	# Isolate launch from furniture on both floors with each floor's real actor.
	npc.global_position = Vector3(attack_from.x, height + 0.08, attack_from.z - 1.05)
	npc.velocity = Vector3.ZERO
	await _frames(8)
	var start: Vector3 = npc.global_position
	_aim(start + Vector3.UP * 1.15)
	var before: Dictionary = game.damage_ledger.breakdown()
	_tap("kick")
	var peak: float = start.y
	for frame: int in range(24):
		await physics_frame
		peak = maxf(peak, npc.global_position.y)
	_check(npc.state == "down" and _flat_distance(start, npc.global_position) > 0.35 and peak > start.y + 0.20,
		"%dF real kick did not produce an airborne knockback" % (floor_id + 1))
	await _frames(42)
	_check(world.floor_index(npc.global_position) == floor_id and npc.global_position.y >= height - 0.12,
		"downed actor fell through its floor")
	_check(int(game.damage_ledger.breakdown().care) > int(before.care), "real hit did not enter the care ledger")

	var mug: RigidBody3D
	for prop: RigidBody3D in world.props:
		if prop.kind == "mug" and world.floor_index(prop.global_position) == floor_id:
			mug = prop
			break
	_check(is_instance_valid(mug), "floor has no breakable mug")
	if mug == null:
		return
	# Keep the native collision/health and present the intact mug in a clean hit lane.
	mug.freeze = true
	mug.global_position = player.camera.global_position + Vector3(0.7, 0.0, 0.45)
	await _frames(2)
	_aim(mug.global_position)
	_tap("punch")
	await _frames(14)
	_check(mug.damage_stage == 2 and int(game.damage_ledger.breakdown().property) > int(before.property),
		"%dF real punch did not break and assess a prop" % (floor_id + 1))
	print("Combat %dF: actor %s, prop stage %d at %s" % [floor_id + 1, npc.state, mug.damage_stage, npc.global_position])

func _test_response() -> void:
	await _walk_to(_lift_at(0))
	world.incident_event.emit("fixture", game.RESPONSE_THRESHOLDS[2], player.global_position)
	var guard: CharacterBody3D = world.npcs[-1]
	_check(game.phase == 2 and guard.role == "guard" and world.floor_index(guard.global_position) == 0,
		"initial response did not dispatch the office guard on 1F")
	var guard_spawn: Vector3 = guard.global_position
	await _ride_from(0)
	await _frames(85)
	_check(world.floor_index(guard.global_position) == 1 or _flat_distance(guard.global_position, guard_spawn) > 0.75,
		"guard did not move toward the lift before the fallback")
	for frame: int in range(260):
		if world.floor_index(guard.global_position) == 1:
			break
		await physics_frame
	_check(world.floor_index(guard.global_position) == 1 and guard.player_target == player,
		"the same live guard did not follow the player to 2F")
	# Drive the production threshold path while isolating the test from long delays.
	game.elapsed += game.RESPONSE_DELAYS[3]
	world.incident_event.emit("fixture", game.RESPONSE_THRESHOLDS[3] - game.response_heat, player.global_position)
	var police: CharacterBody3D = world.npcs[-1]
	_check(game.phase == 3 and police.role == "police" and world.floor_index(police.global_position) == 1,
		"first police did not dispatch on the active 2F")
	game.elapsed += game.RESPONSE_DELAYS[4]
	world.incident_event.emit("fixture", game.RESPONSE_THRESHOLDS[4] - game.response_heat, player.global_position)
	var backup: CharacterBody3D = world.npcs[-1]
	_check(game.phase == 4 and backup != police and backup.role == "police" and world.floor_index(backup.global_position) == 1,
		"backup police did not dispatch on the active 2F")
	var response_amount: int = game.damage_ledger.breakdown().response
	_check(response_amount == 1400000, "two floors changed the three original dispatch assessments")
	await _ride_from(1)
	await _frames(325)
	for npc: CharacterBody3D in [guard, police, backup]:
		_check(world.floor_index(npc.global_position) == 0 and npc.player_target == player,
			"%s was left upstairs after the return ride" % str(npc.display_name))
	_check(game.damage_ledger.breakdown().response == response_amount, "floor transfer charged dispatch twice")

func _test_upper_guard_contact() -> void:
	await _ride_from(0)
	world.incident_event.emit("fixture", game.RESPONSE_THRESHOLDS[2], player.global_position)
	var starting_composure: float = game.composure
	for frame: int in range(250):
		if game.composure < starting_composure:
			break
		await physics_frame
	_check(game.composure < starting_composure and world.floor_index(player.global_position) == 1,
		"the upper guard did not reach the player with a real physical push")

func _reset_world() -> void:
	world.reset_world()
	game.call("_reset_run_state")
	await _frames(18)

func _test_reset() -> void:
	for reload_scene: bool in [false, true]:
		await _ride_from(0)
		await _walk_to(world.ceo.global_position + Vector3(0.0, 0.0, 0.98))
		_aim(world.ceo.global_position + Vector3.UP * 1.1)
		_tap("pickup")
		_check(player.actor_hold.active, "reset/reload fixture failed to grab the real 2F CEO")
		if reload_scene:
			game.call("_restart")
			await process_frame
			await process_frame
			await _bind_scene()
		else:
			await _reset_world()
		_check(world.floor_index(player.global_position) == 0 and _flat_distance(player.global_position, Office.PLAYER_SPAWN) < 0.01 and
			not player.actor_hold.active and player.actor_hold.target == null and player.actor_hold.cooldown_remaining == 0.0 and world.ceo.grabbed_by == null,
			"reset/reload left the player upstairs or retained stale hold state")

func _run() -> void:
	change_scene_to_packed(MainScene)
	await scene_changed
	await _bind_scene()
	await _test_lift_and_hold()
	await _reset_world()
	await _test_combat(0)
	await _ride_from(0)
	await _test_combat(1)
	await _reset_world()
	await _test_response()
	await _reset_world()
	await _test_upper_guard_contact()
	await _reset_world()
	await _test_reset()
	game.sound.stop_all()
	print("FLOOR_TRANSITION_REGRESSION_OK" if failures.is_empty() else "FLOOR_TRANSITION_REGRESSION_FAILED")
	quit(0 if failures.is_empty() else 1)
