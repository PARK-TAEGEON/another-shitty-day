extends SceneTree
## Regression: held props must stay inside the room and never teleport on release.
## Run through tools/test.ps1, or:
## godot --headless --path game --script /absolute/repo/tools/tests/wall_throw_regression.gd
## The fixture keeps player/NPC motion still; cups and existing room geometry use physics.

const WorldScript: Script = preload("res://scripts/world.gd")
const PlayerScript: Script = preload("res://scripts/player.gd")
const PropScript: Script = preload("res://scripts/prop.gd")

var failures: Array[String] = []
var observations: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("WALL_THROW_CHECK: " + message)

func coordinates(point: Vector3) -> Array[float]:
	return [point.x, point.y, point.z]

func aim(player: CharacterBody3D, yaw: float, pitch: float) -> void:
	player.rotation = Vector3(0, yaw, 0)
	player.set("_pitch", pitch)
	player.call("_update_viewmodel", 0.0)

func _run() -> void:
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var world: Node3D = WorldScript.new()
	stage.add_child(world)
	var player: CharacterBody3D = PlayerScript.new()
	player.position = Vector3(6.2, 0.1, -1.0)
	stage.add_child(player)
	world.set("player_target", player)
	player.set("enabled", true)
	# Hold the requested fixture pose steady; the actual cup and room still use physics.
	player.set_physics_process(false)
	player.set_process(false)
	for npc: Node3D in world.get("npcs"):
		npc.set_physics_process(false)
	for prop: RigidBody3D in world.get("props"):
		prop.freeze = true
	var events: Array[String] = []
	player.connect("action_performed", func(kind: String, _at: Vector3) -> void: events.append(kind))
	aim(player, -PI * 0.5, 0.0)
	var cup: RigidBody3D = PropScript.new()
	cup.set("kind", "mug")
	cup.set("display_name", "Wall check cup")
	cup.position = Vector3(7.15, 1.72, -1.0)
	cup.freeze = true
	stage.add_child(cup)
	await physics_frame
	await physics_frame
	var ray: Dictionary = player.call("_ray", 2.7)
	check(ray.get("collider") == cup, "near-wall setup camera ray did not find the cup")
	player.call("_pickup_or_drop")
	check(player.get("held_prop") == cup and bool(cup.get("held")), "camera pickup did not hold the near-wall cup")
	# Move an already picked-up item toward the wall, as a player approaching it would.
	player.global_position = Vector3(7.65, 0.1, -1.0)
	aim(player, -PI * 0.5, 0.0)
	await physics_frame
	var max_held_x: float = cup.global_position.x
	for frame: int in range(30):
		player.call("_update_held", 1.0 / 60.0)
		max_held_x = maxf(max_held_x, cup.global_position.x)
		await physics_frame
	var before: Vector3 = cup.global_position
	check(max_held_x < 8.0, "held cup crossed the x=8 room boundary")
	player.call("perform_action", "throw")
	var immediate: Vector3 = cup.global_position
	var release_velocity: Vector3 = cup.linear_velocity
	check(player.get("held_prop") == null and not cup.freeze, "wall throw did not release the held item")
	check(before.distance_to(immediate) <= 0.000001, "wall throw teleported the cup at release")
	check(immediate.x < 8.0, "wall throw began outside the x=8 room boundary")
	check(cup.continuous_cd, "wall throw did not enable CCD")
	var max_after_x: float = immediate.x
	for frame: int in range(40):
		await physics_frame
		max_after_x = maxf(max_after_x, cup.global_position.x)
	var after_40: Vector3 = cup.global_position
	check(after_40.x < 8.0 and max_after_x < 8.0, "thrown cup crossed the room wall during 40 physics frames")
	observations["wall_throw"] = {
		"player": coordinates(player.global_position),
		"camera_forward": coordinates(-player.get("camera").global_basis.z),
		"camera_pickup_succeeded": ray.get("collider") == cup,
		"held_updates": 30,
		"maximum_held_x": max_held_x,
		"before_throw": coordinates(before),
		"immediate_after_throw": coordinates(immediate),
		"release_displacement": before.distance_to(immediate),
		"release_velocity": coordinates(release_velocity),
		"maximum_x_during_40_frames": max_after_x,
		"after_40_frames": coordinates(after_40),
		"events": events.duplicate()
	}
	# Use the existing desk mug and the real camera query for the ordinary path.
	var desk_mug: RigidBody3D
	for prop: RigidBody3D in world.get("props"):
		if str(prop.get("kind")) == "mug" and prop.position.distance_to(Vector3(0.72, 1.19, -0.2)) < 0.05:
			desk_mug = prop
			break
	check(is_instance_valid(desk_mug), "original personal-desk mug was not found")
	if is_instance_valid(desk_mug):
		player.global_position = Vector3(0.72, 0.1, 1.25)
		player.set("_cooldown", 0.0)
		aim(player, 0.0, atan2(desk_mug.global_position.y - 1.72, 1.25 - desk_mug.global_position.z))
		await physics_frame
		await physics_frame
		var normal_ray: Dictionary = player.call("_ray", 2.7)
		check(normal_ray.get("collider") == desk_mug, "normal camera ray did not select the desk mug")
		events.clear()
		player.call("_pickup_or_drop")
		check(player.get("held_prop") == desk_mug, "normal pickup did not hold the desk mug")
		for frame: int in range(12):
			player.call("_update_held", 1.0 / 60.0)
			await physics_frame
		var normal_before: Vector3 = desk_mug.global_position
		player.call("perform_action", "throw")
		var normal_immediate: Vector3 = desk_mug.global_position
		var normal_velocity: Vector3 = desk_mug.linear_velocity
		check(normal_before.distance_to(normal_immediate) <= 0.000001, "normal throw teleported the mug at release")
		check(not desk_mug.freeze and desk_mug.collision_layer == 2 and desk_mug.collision_mask == 15, "normal throw did not restore prop physics")
		check(normal_velocity.length() > 8.0, "normal perform_action throw did not give the mug velocity")
		check(events == ["pickup", "throw"], "normal pickup/throw did not emit the expected action events")
		for frame: int in range(40):
			await physics_frame
		observations["normal_desk_mug"] = {
			"camera_ray_succeeded": normal_ray.get("collider") == desk_mug,
			"before_throw": coordinates(normal_before),
			"immediate_after_throw": coordinates(normal_immediate),
			"release_displacement": normal_before.distance_to(normal_immediate),
			"release_velocity": coordinates(normal_velocity),
			"after_40_frames": coordinates(desk_mug.global_position),
			"events": events.duplicate()
		}
	observations["failures"] = failures
	var output: String = JSON.stringify(observations, "\t")
	print(output)
	stage.queue_free()
	await process_frame
	await process_frame
	print("WALL_THROW_REGRESSION_OK" if failures.is_empty() else "WALL_THROW_REGRESSION_FAILED")
	quit(0 if failures.is_empty() else 1)
