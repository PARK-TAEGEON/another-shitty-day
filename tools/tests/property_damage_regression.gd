extends SceneTree
## Real rigid-body drops/throws plus cumulative-cost and repeated-contact checks.
## godot --headless --path game --script /absolute/path/to/this/file.gd

const PropScript: Script = preload("res://scripts/prop.gd")

class HitTarget extends StaticBody3D:
	var hits: int = 0
	var damage: float = 0.0
	func receive_hit(_impulse: Vector3, _point: Vector3, amount: float) -> void:
		hits += 1
		damage += amount

var failures: Array[String] = []
var observations: Dictionary = {}
var stage: Node3D

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("PROPERTY_DAMAGE_CHECK: " + message)

func make_prop(prop_kind: String, at: Vector3, frozen: bool = false) -> RigidBody3D:
	var prop: RigidBody3D = PropScript.new()
	prop.set("kind", prop_kind)
	prop.set("display_name", prop_kind)
	prop.position = at
	prop.freeze = frozen
	stage.add_child(prop)
	return prop

func record(prop: RigidBody3D) -> Dictionary:
	var events: Dictionary = {"amounts": [], "incidents": [], "noise": [], "legacy": []}
	prop.connect("damage_assessed", func(category: String, total: int, label: String) -> void:
		events["amounts"].append({"category": category, "total": total, "label": label}))
	prop.connect("incident", func(kind: String, weight: float, _at: Vector3) -> void:
		events["incidents"].append({"kind": kind, "weight": weight}))
	prop.connect("noise", func(_at: Vector3, strength: float) -> void: events["noise"].append(strength))
	prop.connect("scored", func(kind: String, points: int, _at: Vector3) -> void: events["legacy"].append({"kind": kind, "points": points}))
	return events

func advance(frames: int) -> void:
	for frame: int in range(frames):
		await physics_frame

func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	stage.add_child(floor_body)

	var startup: RigidBody3D = make_prop("mug", Vector3(-8, 2.0, 0))
	var startup_events: Dictionary = record(startup)
	var ordinary: RigidBody3D = make_prop("monitor", Vector3(-5, 1.6, 0))
	var ordinary_events: Dictionary = record(ordinary)
	ordinary.call("set_held", true)
	ordinary.call("receive_hit", Vector3(7, 2, 0), ordinary.position, 20.0)
	check(ordinary.get("damage_stage") == 0 and ordinary_events["incidents"].is_empty(), "held prop accepted an attack")
	ordinary.call("set_held", false)
	ordinary.linear_velocity = Vector3(0, 0, 0.5) # Actual E-drop velocity.
	await advance(150)
	check(startup.get("damage_stage") == 0 and startup_events["amounts"].is_empty(), "unattributed startup gravity damaged a cup")
	check(startup_events["incidents"].is_empty() and startup_events["noise"].is_empty(), "startup landing made incident heat/noise")
	check(ordinary.get("damage_stage") == 0 and ordinary_events["amounts"].is_empty(), "ordinary pickup/release earned property damage")
	check(ordinary_events["incidents"].is_empty() and ordinary_events["noise"].is_empty(), "ordinary release/scrape made incident heat/noise")
	check(startup.position.y < 0.3 and ordinary.position.y < 0.8, "gravity fixtures did not actually fall onto the floor")
	observations["ordinary_physics"] = {"startup_y": startup.position.y, "ordinary_drop_y": ordinary.position.y, "startup": startup_events, "ordinary_drop": ordinary_events}

	var monitor: RigidBody3D = make_prop("monitor", Vector3(0, 2, 0), true)
	var monitor_events: Dictionary = record(monitor)
	monitor.call("receive_hit", Vector3(0.1, 0, 0), monitor.position, 1.0)
	check(monitor.get("damage_stage") == 0 and monitor_events["incidents"].is_empty(), "tiny scrape counted as a meaningful hit")
	monitor.call("receive_hit", Vector3(7, 2, 0), monitor.position, 20.0)
	check(monitor.get("damage_stage") == 1 and monitor.get("damage_total") == 100000, "one actual punch did not damage monitor for cumulative 100000")
	monitor.call("receive_hit", Vector3(7, 2, 0), monitor.position, 20.0)
	check(monitor.get("damage_stage") == 2 and monitor.get("damage_total") == 300000, "second punch did not make monitor unusable for cumulative 300000")
	monitor.call("receive_hit", Vector3(13, 2, 0), monitor.position, 28.0)
	check(monitor_events["amounts"].size() == 2 and monitor.get("damage_total") == 300000, "already-unusable monitor awarded more damage")
	check(monitor_events["incidents"].size() == 3, "fresh attack on unusable prop failed to report its physical incident")
	check(monitor_events["legacy"].size() == 1, "legacy first-damage feedback duplicated")
	check(int(monitor_events["amounts"][1]["total"]) - int(monitor_events["amounts"][0]["total"]) == 200000, "cumulative damage does not produce 200000 incremental replacement loss")
	observations["monitor_costs"] = monitor_events

	var expected_caps: Dictionary = {"mug": 10000, "printer": 450000, "keyboard": 50000, "chair": 120000, "plant": 40000, "paper": 15000, "binder": 30000}
	var type_checks: Dictionary = {}
	var number: int = 0
	for prop_kind: String in expected_caps:
		var prop: RigidBody3D = make_prop(prop_kind, Vector3(-8 + number * 2, 2, -8), true)
		var events: Dictionary = record(prop)
		for amount: float in [20.0, 28.0, 28.0]:
			prop.call("receive_hit", Vector3(7, 2, 0), prop.position, amount)
		check(prop.get("damage_stage") == 2, prop_kind + " did not reach visibly unusable state")
		check(prop.get("damage_total") == expected_caps[prop_kind], prop_kind + " cap differs from its authored fictional cost")
		var before: int = events["amounts"].size()
		prop.call("receive_hit", Vector3(13, 2, 0), prop.position, 85.0)
		check(events["amounts"].size() == before, prop_kind + " repeated terminal hit added cost")
		type_checks[prop_kind] = {"stage": prop.get("damage_stage"), "cost": prop.get("damage_total"), "assessments": before}
		number += 1
	await process_frame
	observations["all_prop_types"] = type_checks

	var thrown: RigidBody3D = make_prop("mug", Vector3(2, 1.5, 0))
	var thrown_events: Dictionary = record(thrown)
	thrown.call("set_held", true)
	thrown.call("set_held", false)
	thrown.linear_velocity = Vector3(0, 1.5, 10.5)
	thrown.call("mark_player_throw")
	var legacy_throw: RigidBody3D = make_prop("mug", Vector3(5, 1.5, 0))
	var legacy_events: Dictionary = record(legacy_throw)
	legacy_throw.call("set_held", true)
	legacy_throw.call("set_held", false)
	legacy_throw.linear_velocity = Vector3(0, 1.5, 10.5)
	var splash: RigidBody3D = make_prop("mug", Vector3(8, 1.5, 0))
	var splash_events: Dictionary = record(splash)
	splash.call("mark_player_impulse")
	splash.apply_central_impulse(Vector3(0, 2.1, 0.3))
	await advance(150)
	check(thrown.get("damage_stage") == 2 and thrown.get("damage_total") == 10000, "real activated floor throw did not break cup")
	check(thrown_events["incidents"].size() == 1 and thrown_events["incidents"][0]["kind"] == "THROW", "one thrown landing did not report exactly one THROW")
	check(legacy_throw.get("damage_stage") == 2 and legacy_events["incidents"].size() == 1, "legacy fast-release throw interface stopped working")
	check(splash.get("damage_stage") == 2 and splash.get("damage_total") == 10000, "player-attributed desk splash did not count its real cup breakage")
	check(splash_events["incidents"].is_empty(), "desk splash duplicated the world's desk incident heat")
	thrown.call("_on_body_entered", floor_body)
	thrown.call("_on_body_entered", floor_body)
	check(thrown_events["incidents"].size() == 1 and thrown_events["amounts"].size() == 1, "same landing repeated heat/cost on later contacts")
	observations["throws_and_desk_splash"] = {"explicit_throw": thrown_events.duplicate(true), "legacy_throw": legacy_events.duplicate(true), "desk_splash": splash_events.duplicate(true)}

	# The already broken cup still transmits one hit on a fresh throw. HitTarget
	# provides the same receive_hit contract as a live NPC without their AI movement.
	var target: HitTarget = HitTarget.new()
	var target_shape: CollisionShape3D = CollisionShape3D.new()
	var target_box: BoxShape3D = BoxShape3D.new()
	target_box.size = Vector3(0.25, 3.0, 2.0)
	target_shape.shape = target_box
	target.add_child(target_shape)
	target.position = Vector3(3.5, 1.5, -4)
	stage.add_child(target)
	thrown.call("set_held", true)
	thrown.global_position = Vector3(1.5, 1.5, -4)
	thrown.call("set_held", false)
	thrown.linear_velocity = Vector3(10.5, 0, 0)
	thrown.call("mark_player_throw")
	await advance(80)
	check(target.hits == 1 and is_equal_approx(target.damage, 25.0), "fresh throw of broken prop lost or duplicated target hit")
	check(thrown_events["amounts"].size() == 1, "throwing broken prop repeated replacement cost")
	check(thrown_events["incidents"].size() == 2, "fresh broken-prop throw did not add one new physical incident")
	observations["broken_prop_rethrow"] = {"target_hits": target.hits, "target_damage": target.damage, "events": thrown_events}

	var fresh: RigidBody3D = make_prop("monitor", Vector3(10, 2, -8), true)
	check(fresh.get("damage_stage") == 0 and fresh.get("damage_total") == 0 and is_zero_approx(float(fresh.get("accumulated_damage"))), "fresh round prop inherits old damage")
	observations["failures"] = failures
	print(JSON.stringify(observations, "\t"))
	stage.queue_free()
	await process_frame
	await process_frame
	print("PROPERTY_DAMAGE_REGRESSION_OK" if failures.is_empty() else "PROPERTY_DAMAGE_REGRESSION_FAILED")
	quit(0 if failures.is_empty() else 1)
