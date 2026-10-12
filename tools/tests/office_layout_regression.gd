extends SceneTree
## Exercise the actual expanded office, player controller and guard navigation.
## This checks collision and interaction outcomes, not the visual quality of poses.
## Run --headless --fixed-fps 60 --path game --script <absolute path to this file>.

const MainScript: Script = preload("res://scripts/main.gd")
const STEP: float = 1.0 / 60.0

var failures: Array[String] = []
var observations: Dictionary = {}
var game: Node3D
var world: Node3D
var player: CharacterBody3D
var guard_contacts: Array[Dictionary] = []
var clock: float = 0.0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("OFFICE_LAYOUT_CHECK: " + message)

func _advance(seconds: float) -> void:
	for frame: int in range(ceili(seconds / STEP)):
		clock += STEP
		await physics_frame

func _xyz(point: Vector3) -> Array[float]:
	return [point.x, point.y, point.z]

func _flat_distance(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x, a.global_position.z).distance_to(Vector2(b.global_position.x, b.global_position.z))

func _release() -> void:
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "sprint", "slam", "punch", "kick", "pickup"]:
		if InputMap.has_action(action):
			Input.action_release(action)

func _dispose() -> void:
	_release()
	paused = false
	if is_instance_valid(game):
		var sound: Node = game.get("sound") as Node
		if is_instance_valid(sound):
			sound.call("stop_all")
		game.queue_free()
		await process_frame
		await process_frame
	game = null

func _fixture(hold_initial_actors: bool = false) -> void:
	await _dispose()
	clock = 0.0
	guard_contacts.clear()
	game = MainScript.new() as Node3D
	root.add_child(game)
	game.set("_automated_run", true)
	game.call("_resume")
	world = game.get("world") as Node3D
	player = game.get("player") as CharacterBody3D
	if hold_initial_actors:
		# Register the exact spawn capsules before their first recovery movement.
		# Otherwise physics can conceal a bad spawn by pushing it out of a desk.
		for actor: Node3D in world.get("npcs"):
			actor.set_physics_process(false)
	await _advance(0.25)

func _solid_overlaps(actor: CharacterBody3D) -> Array[Dictionary]:
	var collision: CollisionShape3D = actor.get("_collision") as CollisionShape3D
	var capsule: CapsuleShape3D = (collision.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
	capsule.radius = maxf(capsule.radius - 0.015, 0.1)
	capsule.height = maxf(capsule.height - 0.08, capsule.radius * 2.0)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = collision.global_transform
	query.collision_mask = 1
	query.margin = 0.0
	var result: Array[Dictionary] = []
	for hit: Dictionary in actor.get_world_3d().direct_space_state.intersect_shape(query, 12):
		var body: Node3D = hit["collider"] as Node3D
		var item: Dictionary = {"solid_position": _xyz(body.global_position)}
		if body.get_parent() is MeshInstance3D:
			var solid_mesh: MeshInstance3D = body.get_parent() as MeshInstance3D
			if solid_mesh.mesh is BoxMesh:
				item["solid_size"] = _xyz((solid_mesh.mesh as BoxMesh).size)
		result.append(item)
	return result

func _line_clear(actor: Node3D) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP, player.global_position + Vector3.UP, 1)
	return actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _test_roster_and_idle() -> void:
	await _fixture(true)
	var names: Array[String] = []
	var department: int = 0
	var other: int = 0
	var overlaps: Array[Dictionary] = []
	var roster: Array[Dictionary] = []
	for actor: CharacterBody3D in world.get("npcs"):
		var name_value: String = str(actor.get("display_name"))
		names.append(name_value)
		var affiliation: String = str(actor.get("affiliation"))
		department += 1 if affiliation == "department" else 0
		other += 1 if affiliation == "other" else 0
		var solid_hits: Array[Dictionary] = _solid_overlaps(actor)
		if not solid_hits.is_empty():
			overlaps.append({"name": name_value, "actor_position": _xyz(actor.global_position), "hits": solid_hits})
		roster.append({"name": name_value, "affiliation": affiliation, "activity": actor.get("work_activity"), "position": _xyz(actor.global_position)})
	check(department == 5 and other == 2 and names.size() == 7, "expanded roster is not exactly five department employees and two other staff")
	check(names.has("정 인턴") and not names.has("정 대리"), "intern rename was not applied to the live roster")
	check(overlaps.is_empty(), "one or more initial worker capsules overlap solid furniture before physics recovery")
	for actor: Node3D in world.get("npcs"):
		actor.set_physics_process(true)
	await _advance(10.0)
	var idle_state: Array[Dictionary] = []
	for actor: Node3D in world.get("npcs"):
		idle_state.append({"name": actor.get("display_name"), "health": actor.get("health"), "state": actor.get("state"), "working": actor.call("is_working"), "position": _xyz(actor.global_position)})
		check(is_equal_approx(float(actor.get("health")), 40.0) and bool(actor.call("is_working")), "ordinary idle office injured or interrupted " + str(actor.get("display_name")))
	check(int(game.get("score")) == 0 and is_zero_approx(float(game.get("response_heat"))) and int(game.get("phase")) == 0, "idle office generated money or response heat")
	check(not bool(world.get("_disturbed")), "idle office became disturbed without player action")
	observations["initial_roster_and_idle"] = {"roster": roster, "initial_overlaps": overlaps, "after_ten_seconds": idle_state, "score": game.get("score"), "response_heat": game.get("response_heat")}

func _record_guard_contact(damage: float, guard: CharacterBody3D) -> void:
	guard_contacts.append({"time": clock, "damage": damage, "distance": _flat_distance(guard, player), "line_clear": _line_clear(guard), "guard": _xyz(guard.global_position), "player": _xyz(player.global_position), "push_velocity": _xyz(player.get("_security_push_velocity"))})

func _test_cancel_and_guard_route() -> void:
	await _fixture()
	await _advance(0.75)
	check(bool(world.call("slam_desk", player.global_position)), "real starting desk did not accept the setup slam")
	await _advance(0.35)
	var boss: CharacterBody3D = world.get("opening_boss") as CharacterBody3D
	var ledger: RefCounted = game.get("damage_ledger") as RefCounted
	var boss_id: String = str(boss.get_instance_id())
	check(str(boss.get("opening_phase")) == "listen" and bool(boss.call("is_working")), "setup did not reach the boss's pre-peek listening beat")
	check(int(ledger.call("assessed", boss_id, "work")) == 0, "boss was charged before visibly interrupting work")
	game.call("_set_phase", 2)
	var booked: int = int(ledger.call("assessed", boss_id, "work"))
	check(not bool(boss.call("is_working")) and booked == 10000, "cancelling the listening boss lost his one-time work interruption assessment")
	world.call("cancel_opening_scene")
	check(int(ledger.call("assessed", boss_id, "work")) == booked, "repeated cancellation changed the boss's work assessment")
	observations["boss_listen_cancel"] = {"phase_after_cancel": boss.get("opening_phase"), "working_after_cancel": boss.call("is_working"), "booked_work": booked}
	var guard: CharacterBody3D
	for actor: CharacterBody3D in world.get("npcs"):
		if str(actor.get("role")) == "guard":
			guard = actor
	check(is_instance_valid(guard), "escalation did not spawn the actual company guard")
	if not is_instance_valid(guard):
		return
	guard.connect("player_hit", _record_guard_contact.bind(guard))
	var start: Vector3 = guard.global_position
	var player_start: Vector3 = player.global_position
	var previous: Vector3 = start
	var walked: float = 0.0
	var min_distance: float = _flat_distance(guard, player)
	var stall: float = 0.0
	var longest_stall: float = 0.0
	var overlap_frames: int = 0
	var samples: Array[Dictionary] = []
	var dispatch_time: float = clock
	for frame: int in range(900):
		await _advance(STEP)
		var movement: Vector3 = guard.global_position - previous
		movement.y = 0.0
		walked += movement.length()
		previous = guard.global_position
		min_distance = minf(min_distance, _flat_distance(guard, player))
		if not _solid_overlaps(guard).is_empty():
			overlap_frames += 1
		if movement.length() < 0.001 and _flat_distance(guard, player) > 1.5:
			stall += STEP
			longest_stall = maxf(longest_stall, stall)
		else:
			stall = 0.0
		if frame % 30 == 0:
			samples.append({"time": clock - dispatch_time, "position": _xyz(guard.global_position), "distance": _flat_distance(guard, player)})
		if not guard_contacts.is_empty():
			break
	check(not guard_contacts.is_empty(), "guard failed to reach and genuinely contact the starting player within 15 seconds")
	check(longest_stall < 2.0, "guard stalled for at least two seconds behind actual office furniture")
	check(overlap_frames == 0, "guard crossed solid office furniture along its entry route")
	if not guard_contacts.is_empty():
		check(float(guard_contacts[0]["distance"]) <= 1.42 and bool(guard_contacts[0]["line_clear"]), "guard damage was emitted outside physical contact range or through furniture")
		var impulse: Array = guard_contacts[0]["push_velocity"]
		check(Vector3(float(impulse[0]), 0, float(impulse[2])).length() > 1.0, "real guard contact did not apply the player's shove velocity")
		await _advance(0.45)
		check(Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(player_start.x, player_start.z)) > 0.10, "validated guard contact caused no real player displacement")
	observations["entry_guard_route"] = {"start": _xyz(start), "end": _xyz(guard.global_position), "seconds_to_contact": float(guard_contacts[0]["time"]) - dispatch_time if not guard_contacts.is_empty() else -1.0, "walked_metres": walked, "minimum_distance": min_distance, "longest_stall_seconds": longest_stall, "solid_overlap_frames": overlap_frames, "contacts": guard_contacts.duplicate(true), "player_displacement": player.global_position.distance_to(player_start), "samples": samples}

func _test_meeting_access() -> void:
	await _fixture()
	player.global_position = Vector3(0, 0.08, 5.2)
	player.velocity = Vector3.ZERO
	var destination: Vector3 = Vector3(4.45, 0.08, 4.60)
	await _advance(0.2)
	var route: PackedVector3Array = world.call("find_navigation_path", player.global_position, destination)
	check(not route.is_empty(), "meeting bay had no route from the open entry aisle")
	var route_points: Array[Array] = []
	for point: Vector3 in route:
		route_points.append(_xyz(point))
	var waypoint: int = 0
	var walked: float = 0.0
	var previous: Vector3 = player.global_position
	for frame: int in range(480):
		while waypoint < route.size() and Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(route[waypoint].x, route[waypoint].z)) < 0.22:
			waypoint += 1
		if waypoint >= route.size():
			break
		var direction: Vector3 = route[waypoint] - player.global_position
		direction.y = 0.0
		player.rotation.y = atan2(-direction.x, -direction.z)
		Input.action_press("move_forward")
		await _advance(STEP)
		walked += Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(previous.x, previous.z))
		previous = player.global_position
	_release()
	await _advance(0.20)
	var remaining: float = Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(destination.x, destination.z))
	check(remaining < 0.35, "real player controller could not walk from the open aisle into the meeting bay")
	observations["meeting_access"] = {"route": route_points, "destination": _xyz(destination), "player_end": _xyz(player.global_position), "remaining_metres": remaining, "walked_metres": walked}

func _run() -> void:
	await _test_roster_and_idle()
	await _test_cancel_and_guard_route()
	await _test_meeting_access()
	await _dispose()
	observations["failures"] = failures
	observations["passed"] = failures.is_empty()
	print(JSON.stringify(observations, "\t"))
	print("OFFICE_LAYOUT_REGRESSION_OK" if failures.is_empty() else "OFFICE_LAYOUT_REGRESSION_FAILED")
	quit(0 if failures.is_empty() else 1)
