extends SceneTree
## Real-gameplay review clip for the cartoon pass: the actual main scene with
## juice enabled, driven only by scripted look/move and real input actions
## (slam, punch, kick, pickup, throw). Nothing is staged on the NPCs.
##   godot --path game --write-movie out.avi --fixed-fps 30 --script <this file>

var game: Node3D
var player: CharacterBody3D
var world: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(game)
	await process_frame
	await process_frame
	player = game.get("player") as CharacterBody3D
	world = game.get("world") as Node3D
	game.call("_resume")
	player.set("shake_scale", 0.6)
	world.connect("npc_struck", func(at: Vector3, power: float, down: bool) -> void:
		print("STRUCK t=%.2f power=%.2f down=%s" % [float(Engine.get_process_frames()) / 30.0, power, down]))
	await _wait(0.9)
	# 1. The accepted opening: desk slam, coworker startle, boss peeks.
	await _press("slam")
	await _wait(2.4)
	var coworker: Node3D = world.get("opening_coworker") as Node3D
	var boss: Node3D = world.get("opening_boss") as Node3D
	# 2. Punch and kick the startled coworker before he can back away.
	await _beat_down(coworker, ["kick", "punch", "kick", "punch"])
	await _turn_to(coworker.global_position + Vector3.UP * 0.2, 0.45)
	await _wait(1.4)
	# 3. The boss walks over to lecture. Meet him with a binder to the face.
	for frame: int in range(30 * 6):
		if boss.global_position.distance_to(player.global_position) < 1.9:
			break
		_aim(boss.global_position + Vector3.UP * 1.5, 0.08)
		await process_frame
	var camera: Camera3D = player.get("camera") as Camera3D
	var item: RigidBody3D = null
	var best: float = INF
	for prop: Node3D in world.get("props"):
		if not is_instance_valid(prop) or str(prop.get("kind")) not in ["mug", "paper", "binder"]:
			continue
		var at: Vector3 = _prop_center(prop as RigidBody3D)
		var reach: float = at.distance_to(camera.global_position)
		if at.y > 0.9 and reach < best:
			best = reach
			item = prop as RigidBody3D
	if item != null and best < 2.2:
		await _turn_to(_prop_center(item), 0.3)
		await _press("pickup")
		await _wait(0.25)
		print("HELD ", item.get("kind"), " ", player.get("held_prop") == item)
		await _turn_to(boss.global_position + Vector3.UP * 1.55, 0.3)
		await _press("punch") # Throws the held item.
		await _wait(0.7)
	# 4. Then knock him down.
	await _beat_down(boss, ["kick", "punch", "kick", "punch", "kick"])
	print("BOSS stars ", boss.get("_dizzy_stars").size())
	await _turn_to(boss.global_position + Vector3.UP * 0.25, 0.5)
	await _wait(2.4)
	game.get("sound").stop_all()
	quit(0)

func _beat_down(target: Node3D, moves: Array) -> void:
	# Close in once, then chain hits at the real 0.4 s cooldown while tracking the
	# target, so a startled NPC is down before its flee reaction carries it away.
	await _approach(target, 1.2, 2.5)
	for kind: String in moves:
		if str(target.get("state")) == "down":
			return
		_aim(target.global_position + Vector3.UP * (1.0 if kind == "kick" else 1.35))
		await _press(kind)
		for frame: int in range(11):
			_aim(target.global_position + Vector3.UP * 1.15, 0.5)
			await process_frame

func _wait(seconds: float) -> void:
	for frame: int in range(ceili(seconds * 30.0)):
		await process_frame

func _aim(target: Vector3, blend: float = 1.0) -> void:
	var camera: Camera3D = player.get("camera") as Camera3D
	var direction: Vector3 = target - camera.global_position
	player.rotation.y = lerp_angle(player.rotation.y, atan2(-direction.x, -direction.z), blend)
	var pitch: float = atan2(direction.y, Vector2(direction.x, direction.z).length())
	player.set("_pitch", lerpf(float(player.get("_pitch")), clampf(pitch, -1.2, 1.15), blend))

func _turn_to(target: Vector3, seconds: float) -> void:
	var frames: int = maxi(ceili(seconds * 30.0), 1)
	for frame: int in range(frames):
		_aim(target, 1.0 / float(frames - frame))
		await process_frame

func _press(action: String) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _approach(target: Node3D, range_m: float, timeout: float) -> void:
	for frame: int in range(ceili(timeout * 30.0)):
		var offset: Vector3 = target.global_position - player.global_position
		offset.y = 0.0
		if offset.length() <= range_m:
			break
		_aim(target.global_position + Vector3.UP * 1.3, 0.25)
		Input.action_press("move_forward")
		await process_frame
	Input.action_release("move_forward")
	await _wait(0.1)

func _nearest_prop(kind: String, near_at: Vector3) -> RigidBody3D:
	var closest: RigidBody3D
	var distance: float = INF
	for prop: Node3D in world.get("props"):
		if is_instance_valid(prop) and str(prop.get("kind")) == kind:
			var next_distance: float = prop.global_position.distance_to(near_at)
			if next_distance < distance:
				distance = next_distance
				closest = prop as RigidBody3D
	return closest

func _prop_center(prop: RigidBody3D) -> Vector3:
	for child: Node in prop.get_children():
		if child is CollisionShape3D:
			return (child as CollisionShape3D).global_position
	return prop.global_position
