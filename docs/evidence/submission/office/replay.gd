extends SceneTree
## Run against the main scene at fixed 30 fps. Action events go through player input.
const OUT := "/tmp/asd-office-review"
var game
var player
var monitor
var mug
var failures: Array[String] = []
var closeup: Camera3D
var visual := DisplayServer.get_name() != "headless"

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in count:
		await process_frame

func check(ok: bool, label: String) -> void:
	print("CHECK ", label, " ", ok)
	if not ok:
		failures.append(label)

func photo(label: String) -> void:
	if visual:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(OUT.path_join(label + ".jpg"), 0.9)

func action(label: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = label
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(2)

func aim(at: Vector3) -> void:
	var d: Vector3 = at - player.camera.global_position
	player.rotation.y = atan2(-d.x, -d.z)
	player._pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.2, 1.15)
	await frames(6)

func focus(prop: Node3D, offset: Vector3, height: float) -> void:
	var target := prop.global_position + Vector3.UP * height
	closeup.global_position = target + offset
	closeup.look_at(target)
	closeup.make_current()
	await frames(2)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	game = current_scene
	player = game.player
	game._resume()
	await frames(24)
	monitor = game.world.props[0]
	for prop in game.world.props:
		if prop.kind == "mug":
			mug = prop
			break
	await photo("opening")
	await aim(mug.global_position)
	await action("pickup")
	check(player.held_prop == mug, "camera ray picked up mug")
	await frames(12)
	await photo("held")
	await action("pickup")
	check(player.held_prop == null and not mug.freeze, "drop returned mug to physics")
	await frames(4)
	await aim(mug.global_position)
	await action("pickup")
	check(player.held_prop == mug, "picked mug up again")
	await aim(Vector3(-7.8, 1.3, .25))
	await action("punch")
	await frames(58)
	check(player.held_prop == null and mug.damage_stage == 2, "thrown mug reached terminal stage")
	check(mug.damage_total == 10000 and game.damage_ledger.breakdown()["property"] >= 10000, "throw booked property cost")
	closeup = Camera3D.new()
	game.add_child(closeup)
	game._hud.hide()
	await focus(mug, Vector3(.15,.25,.37), -.03)
	await photo("mug-broken")
	await focus(monitor, Vector3(.14,.16,.79), .19)
	await photo("monitor-normal")
	monitor.receive_hit(Vector3.ZERO, monitor.global_position, 16.0)
	check(monitor.damage_stage == 1 and monitor.damage_total == 100000, "monitor intermediate cost")
	await frames(12)
	await photo("monitor-damaged")
	monitor.receive_hit(Vector3.ZERO, monitor.global_position, 24.0)
	check(monitor.damage_stage == 2 and monitor.damage_total == 300000, "monitor terminal cost")
	await frames(12)
	await photo("monitor-broken")
	game._restart()
	await scene_changed
	game = current_scene
	game._resume()
	await frames(5)
	check(game.score == 0 and game.world.props[0].damage_stage == 0, "restart cleared ledger and restored monitor")
	for prop in game.world.props:
		if prop.kind == "mug":
			check(prop.damage_stage == 0, "restart restored mug")
			closeup = Camera3D.new()
			game.add_child(closeup)
			game._hud.hide()
			await focus(prop, Vector3(.26,.23,.32), 0)
			await photo("mug-normal")
			break
	print("OFFICE_REVIEW ", failures)
	quit(0 if failures.is_empty() else 1)
