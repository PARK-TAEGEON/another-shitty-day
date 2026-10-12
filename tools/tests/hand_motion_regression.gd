extends SceneTree
## Approved B/A timing, exact desktop contact, and interruption boundaries.
## Advances controlled deltas to test threshold crossings; live movement is covered separately.

var failures: Array[String] = []
var contacts: Array[Dictionary] = []
var swings: Array[String] = []
var player: CharacterBody3D

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, detail: String) -> void:
	if not condition:
		failures.append(detail)

func _run() -> void:
	player = load("res://scripts/player.gd").new()
	player.position = Vector3(0, 0, 0.65)
	root.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.desk_requested.connect(_contact)
	player.action_performed.connect(func(kind: String, _at: Vector3) -> void: swings.append(kind))
	player.set_active(true)
	player.perform_action("slam")
	_check(player._slam_variant == "B", "first unconfirmed slam must use B")
	_check(is_equal_approx(player._anim_duration, 28.0 / 30.0), "B duration differs from 28/30 seconds")
	player._process(11.0 / 30.0 - 0.001)
	_check(contacts.is_empty(), "B emitted before contact")
	player._process(0.001)
	_check(contacts.size() == 1, "B did not emit at 11/30 seconds")
	player._process(1.0)
	player._cooldown = 0.0
	player.perform_action("slam")
	_check(player._slam_variant == "B", "missed attempt wrongly consumed B")
	player.confirm_desk_slam()
	player._process(1.0)
	player._cooldown = 0.0
	player.perform_action("slam")
	_check(player._slam_variant == "A", "confirmed desk did not switch subsequent motion to A")
	_check(is_equal_approx(player._anim_duration, 20.0 / 30.0), "A duration differs from 20/30 seconds")
	var before: int = contacts.size()
	player._process(9.0 / 30.0 - 0.001)
	_check(contacts.size() == before, "A emitted before contact")
	player._process(0.001)
	_check(contacts.size() == before + 1, "A did not emit at 9/30 seconds")
	for contact: Dictionary in contacts:
		_check(float(contact["left_error"]) < 0.00001 and float(contact["right_error"]) < 0.00001, "event emitted away from contact pose")
		_check(absf(float(contact["min_world_y"]) - 1.062) < 0.0001, "hand geometry does not meet the desktop")
		_check(float(contact["left_x"]) < 0.0 and float(contact["right_x"]) > 0.0, "screen laterality is inverted")
	player.set_active(false)
	player.set_active(true)
	player.perform_action("slam")
	player._process(0.1)
	player.set_active(false)
	player.set_active(true)
	before = contacts.size()
	player._process(1.0)
	_check(contacts.size() == before, "paused slam fired after resume")
	player.perform_action("punch")
	player.set_active(false)
	player.set_active(true)
	await create_timer(0.14).timeout
	_check(swings.is_empty(), "cancelled punch fired after resume")
	player.perform_action("punch")
	await create_timer(0.14).timeout
	_check(swings == ["swing"], "normal punch no longer emits its swing")
	print(JSON.stringify({"status": "pass" if failures.is_empty() else "fail", "failures": failures, "contacts": contacts, "swings": swings, "checks": ["B28f and A20f", "contact11f and9f", "success-confirmed switch", "event/contact pose alignment", "desktop height", "left/right placement", "pause cancellation", "normal punch"]}, "  "))
	print("HAND_MOTION_REGRESSION_OK" if failures.is_empty() else "HAND_MOTION_REGRESSION_FAILED")
	player.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _contact(_origin: Vector3) -> void:
	var hand: Node3D = player._left
	var minimum: float = INF
	var points: PackedVector3Array = hand.get_geometry_points()
	for point: Vector3 in points:
		minimum = minf(minimum, hand.to_global(point).y)
	contacts.append({"variant": player._slam_variant, "elapsed": player._anim_duration - player._anim, "left_error": player._left.position.distance_to(player._contact_positions[0]), "right_error": player._right.position.distance_to(player._contact_positions[1]), "min_world_y": minimum, "left_x": player._left.position.x, "right_x": player._right.position.x})
