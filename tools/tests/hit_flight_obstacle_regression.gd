extends SceneTree
## A scripted knockout must stop on a near wall, a corner, a desk and a corridor end.
const NPC = preload("res://scripts/office_npc.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("HIT_OBSTACLE_CHECK: " + message)

func step(count: int) -> void:
	for _i in range(count):
		await physics_frame

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	_floor(stage)
	await _wall_close(stage)
	await _corner(stage)
	await _desk(stage)
	await _east_corridor(stage)
	stage.queue_free()
	await process_frame
	if failures.is_empty():
		print("HIT_FLIGHT_OBSTACLE_REGRESSION_OK")
	else:
		print("HIT_FLIGHT_OBSTACLE_REGRESSION_FAILED: ", failures)
	quit(0 if failures.is_empty() else 1)

func _floor(stage: Node) -> void:
	_solid(stage, Vector3(0, -0.15, 0), Vector3(80, 0.3, 80), 1)

func _solid(stage: Node, at: Vector3, size: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = at
	stage.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body

func _kim(stage: Node, at: Vector3) -> CharacterBody3D:
	var actor = NPC.new()
	actor.role = "boss"
	actor.display_name = "김 팀장"
	actor.use_kim_rig = true
	actor.position = at
	stage.add_child(actor)
	return actor

func _watch(actor: CharacterBody3D, inside: Callable, label: String) -> void:
	var peak_speed: float = 0.0
	var lowest: float = 10.0
	for _i in range(170):
		await physics_frame
		if actor._rig_adapter == null:
			continue
		for body: PhysicalBone3D in actor._rig_adapter.bodies:
			peak_speed = maxf(peak_speed, body.linear_velocity.length())
			lowest = minf(lowest, body.global_position.y)
			check(inside.call(body.global_position), label + " left the room at " + str(body.global_position))
	check(lowest > -0.35, label + " went through the floor")
	check(peak_speed < 30.0, label + " speed ran away: " + str(peak_speed))
	var settled: float = 0.0
	if actor._rig_adapter != null:
		for body: PhysicalBone3D in actor._rig_adapter.bodies:
			settled = maxf(settled, body.linear_velocity.length())
	check(settled < 12.0, label + " still fast after landing: " + str(settled))

func _wall_close(stage: Node) -> void:
	var wall := _solid(stage, Vector3(0.9, 1.5, 0), Vector3(0.2, 3.0, 4.0), 1)
	var actor := _kim(stage, Vector3(0, 0.02, 0))
	await step(2)
	actor.receive_hit(Vector3(13, 2, 0), actor.global_position + Vector3.UP, 28.0, "kick")
	await _watch(actor, func(at: Vector3) -> bool: return at.x < 0.82, "wall 0.8m")
	check(actor._rig_adapter.contact_sound_count > 0, "wall 0.8m produced no impact")
	check(actor._rig_adapter.pelvis_position().x < 0.78, "wall 0.8m was crossed")
	actor.queue_free()
	wall.queue_free()
	await step(2)

func _corner(stage: Node) -> void:
	var wall_x := _solid(stage, Vector3(1.05, 1.5, 0.4), Vector3(0.2, 3.0, 3.0), 1)
	var wall_z := _solid(stage, Vector3(0.4, 1.5, 1.05), Vector3(3.0, 3.0, 0.2), 1)
	var actor := _kim(stage, Vector3(0, 0.02, 0))
	await step(2)
	var probe_shape := SphereShape3D.new()
	probe_shape.radius = 0.2
	var probe := PhysicsShapeQueryParameters3D.new()
	probe.shape = probe_shape
	probe.transform = Transform3D(Basis.IDENTITY, Vector3(1.05, 1.5, 0.4))
	probe.collision_mask = 3
	var direction := Vector3(1, 0.15, 1).normalized()
	actor.receive_hit(direction * 13.0, actor.global_position + Vector3.UP, 28.0, "kick")
	await _watch(actor, func(at: Vector3) -> bool: return at.x < 0.97 and at.z < 0.97, "corner")
	actor.queue_free()
	wall_x.queue_free()
	wall_z.queue_free()
	await step(2)

func _desk(stage: Node) -> void:
	var desk := _solid(stage, Vector3(1.2, 0.52, 0), Vector3(0.55, 1.04, 1.6), 2)
	var actor := _kim(stage, Vector3(0, 0.02, 0))
	await step(2)
	actor.receive_hit(Vector3(13, 2, 0), actor.global_position + Vector3.UP, 28.0, "kick")
	await _watch(actor, func(at: Vector3) -> bool: return at.x < 1.22, "desk")
	# Desk center x=1.2, size 0.55, so the front face the body flies into is x=0.925.
	for body: PhysicalBone3D in actor._rig_adapter.bodies:
		check(body.global_position.x < 0.925, "desk face crossed by %s at %s" % [body.name, str(body.global_position)])
	actor.queue_free()
	desk.queue_free()
	await step(2)

func _east_corridor(stage: Node) -> void:
	var left := _solid(stage, Vector3(2.2, 1.5, -1.05), Vector3(6.0, 3.0, 0.2), 1)
	var right := _solid(stage, Vector3(2.2, 1.5, 1.05), Vector3(6.0, 3.0, 0.2), 1)
	var end := _solid(stage, Vector3(4.3, 1.5, 0), Vector3(0.2, 3.0, 2.2), 1)
	var actor := _kim(stage, Vector3(0.3, 0.02, 0))
	await step(2)
	actor.receive_hit(Vector3(13, 2, 0), actor.global_position + Vector3.UP, 28.0, "kick")
	await _watch(actor, func(at: Vector3) -> bool: return absf(at.z) < 0.98 and at.x < 4.22 and at.x > -0.4, "east corridor")
	actor.queue_free()
	left.queue_free()
	right.queue_free()
	end.queue_free()
	await step(2)
