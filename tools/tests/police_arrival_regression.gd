extends SceneTree
## Native Godot regression for one-shot presentation, real dispatch and camera ownership.
## godot --headless --path game --script <absolute path to this script>
## Headless verifies state only; -- --capture-police --capture-dir <dir> renders stills.
const ArrivalScript: Script = preload("res://scripts/scenario/police_arrival.gd")
const PlayerScript: Script = preload("res://scripts/player.gd")
const WorldScript: Script = preload("res://scripts/world.gd")
const MainScript: Script = preload("res://scripts/main.gd")

var failures: Array[String] = []
var observations: Dictionary = {}
var stage: Node3D
var player: CharacterBody3D
var world: Node3D
var arrival: Node
var completions: int = 0
var actions: Array[String] = []
var assessments: Array[Dictionary] = []

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("POLICE_ARRIVAL_CHECK: " + message)

func _advance(seconds: float) -> void:
	for frame: int in range(ceili(seconds * float(Engine.physics_ticks_per_second))):
		await physics_frame

func _capture(name_value: String) -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.has("--capture-police") or DisplayServer.get_name() == "headless":
		return
	var directory: String = "user://police-arrival-review"
	for index: int in range(args.size() - 1):
		if args[index] == "--capture-dir":
			directory = args[index + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(name_value + ".png")) == OK, "could not save rendered police evidence")

func _callbacks() -> Array[bool]:
	return [player.is_processing(), player.is_physics_processing(), player.is_processing_input(), player.is_processing_unhandled_input(), player.is_processing_unhandled_key_input(), player.is_processing_shortcut_input()]

func _reset_intro() -> void:
	arrival.call("reset_round")
	player.call("set_active", true)
	player.set_process(true)
	player.set_physics_process(true)
	player.set_process_unhandled_input(true)
	player.get("camera").make_current()

func _main_wiring_regression() -> void:
	# This second fixture exercises the production signal wiring and lifecycle,
	# not a manual call to the new presentation controller.
	var game: Node3D = MainScript.new() as Node3D
	root.add_child(game)
	game.set("_automated_run", true)
	game.call("_resume")
	var actual_world: Node3D = game.get("world") as Node3D
	var actual_player: Node3D = game.get("player") as Node3D
	var actual_arrival: Node = game.get("police_arrival") as Node
	var actual_view: Camera3D = actual_player.get("camera") as Camera3D
	await _advance(0.05)
	actual_world.call("escalate", 3)
	check(bool(actual_arrival.get("active")) and root.get_camera_3d() == actual_arrival.get("_cut_camera"), "production first police failed to cut: active=%s camera=%s peer=%s" % [actual_arrival.get("active"), actual_arrival.get("_cut_camera"), game.multiplayer.multiplayer_peer.get_class() if game.multiplayer.multiplayer_peer != null else "none"])
	var original_money: int = int(game.get("score"))
	check(original_money == 600000, "presentation wiring changed the existing guard/police response cost")
	await _advance(0.25)
	await _capture("03-main-first-police-arrival")
	var escape: InputEventAction = InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	check(paused and not bool(actual_arrival.get("active")) and not bool(actual_player.get("enabled")) and root.get_camera_3d() == actual_view, "production Esc menu did not cancel cut and preserve paused/inactive input")
	game.call("_resume")
	actual_world.emit_signal("responder_arrived", actual_world.get("npcs")[-1])
	check(not bool(actual_arrival.get("active")) and int(game.get("score")) == original_money, "duplicate arrival signal replayed cut or charged another dispatch")
	actual_world.call("reset_world")
	game.call("_reset_run_state")
	actual_world.call("escalate", 3)
	check(bool(actual_arrival.get("active")), "production round reset failed to restore first police presentation")
	game.call("_on_player_hit", 100.0)
	check(bool(game.get("ended")) and paused and not bool(actual_arrival.get("active")) and not bool(actual_player.get("enabled")) and root.get_camera_3d() == actual_view, "production subdual did not prioritize results over arrival camera/input")
	await create_timer(0.15, true).timeout
	check(not bool(actual_player.get("enabled")) and bool(game.get("ended")), "completed run resumed after cut cancellation")
	observations["production_dispatch_menu_results_reset"] = {"original_response_cost": original_money, "checked": true}
	game.get("sound").call("stop_all")
	paused = false
	game.queue_free()
	await process_frame

func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	world = WorldScript.new() as Node3D
	stage.add_child(world)
	player = PlayerScript.new() as CharacterBody3D
	player.position = Vector3(0, 0.08, 0.65)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	stage.add_child(player)
	player.call("set_active", true)
	world.set("player_target", player)
	world.connect("damage_assessed", func(target: String, category: String, amount: int, _label_value: String) -> void:
		assessments.append({"id": target, "category": category, "amount": amount}))
	player.connect("action_performed", func(kind: String, _at: Vector3) -> void: actions.append(kind))
	arrival = ArrivalScript.new()
	stage.add_child(arrival)
	arrival.connect("finished", func() -> void: completions += 1)
	await _advance(0.5)
	var view: Camera3D = player.get("camera") as Camera3D
	var original_callbacks: Array[bool] = _callbacks()
	var original_transform: Transform3D = view.global_transform
	var original_fov: float = view.fov
	var original_mouse: Input.MouseMode = Input.mouse_mode
	world.call("escalate", 3)
	var police: Node3D
	for npc: Node3D in world.get("npcs"):
		if str(npc.get("display_name")) == "출동 경찰":
			police = npc
	check(is_instance_valid(police), "the existing finite dispatcher did not create the first police officer")
	if not is_instance_valid(police):
		quit(1)
		return
	var spawn: Vector3 = police.global_position
	var dispatch_count: int = assessments.size()
	# Enter while an actual punch contact is pending. set_active(false) would
	# delete it; the arrival owns callbacks only and must preserve this acceptance.
	player.call("perform_action", "punch")
	var serial: int = int(player.get("_action_serial"))
	arrival.call("begin", player, spawn)
	check(bool(arrival.get("active")) and bool(arrival.get("presented")), "first arrival did not begin exactly once")
	check(root.get_camera_3d() == arrival.get("_cut_camera") and root.get_camera_3d() != view, "arrival did not cut to its native camera")
	check(not paused and bool(player.get("enabled")) and not player.is_processing_unhandled_input() and not player.is_physics_processing(), "arrival changed global pause/enabled or left new input and locomotion active")
	check((arrival.get("_title") as Label).text == "POLICE ARRIVED!" and (arrival.get("_panel") as Control).is_visible_in_tree(), "arrival subtitle is missing")
	var cut: Camera3D = arrival.get("_cut_camera") as Camera3D
	var toward: Vector3 = (spawn + Vector3.UP * 1.10 - cut.global_position).normalized()
	check((-cut.global_basis.z).dot(toward) > 0.999, "cut camera did not frame the actual spawn point")
	await _advance(0.25)
	check(actions.size() == 1 and actions[0] in ["impact", "swing"] and int(player.get("_action_serial")) == serial, "arrival deleted or duplicated an accepted punch contact")
	check(assessments.size() >= dispatch_count, "arrival removed the real dispatch assessment")
	await _capture("01-first-police-arrival")
	arrival.call("begin", player, spawn)
	await _advance(1.9)
	check(not bool(arrival.get("active")) and completions == 1, "timeout/repeated dispatch finalized more than once")
	check(root.get_camera_3d() == view and _callbacks() == original_callbacks, "timeout did not return original camera and callback state")
	check(is_equal_approx(view.fov, original_fov) and view.global_basis.is_equal_approx(original_transform.basis) and Input.mouse_mode == original_mouse, "arrival modified FOV, view rotation or mouse ownership")
	await _capture("02-player-view-restored")
	arrival.call("begin", player, spawn)
	check(not bool(arrival.get("active")) and root.get_camera_3d() == view, "same round replayed the first-arrival cut")
	observations["actual_dispatch_and_return"] = {"dispatch_assessments": dispatch_count, "accepted_action": actions[0], "finished_count": completions, "duration": ArrivalScript.DURATION}

	# Cancellation is idempotent. End/menu disables after cancel; no outstanding
	# timer is allowed to bring input or camera back in a completed run.
	_reset_intro()
	arrival.call("begin", player, spawn)
	arrival.call("cancel")
	arrival.call("cancel")
	player.call("set_active", false)
	await _advance(2.1)
	check(completions == 2 and not bool(player.get("enabled")) and root.get_camera_3d() == view, "cancel/end was followed by a stale re-enable or camera change")
	# Even an owner that disables during the cut cannot be re-enabled by timeout.
	_reset_intro()
	arrival.call("begin", player, spawn)
	player.call("set_active", false)
	await _advance(2.0)
	check(not bool(player.get("enabled")) and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "timeout resurrected externally disabled player/mouse ownership")

	# New round resets the presentation, but initially disabled/menu callers
	# receive subtitle only and retain their original inactive state.
	arrival.call("reset_round")
	arrival.call("begin", player, spawn)
	check(arrival.get("_cut_camera") == null and root.get_camera_3d() == view and not bool(player.get("enabled")), "inactive start forced a cut or enabled control")
	arrival.call("cancel")
	_reset_intro()
	var before_nonblocking: Array[bool] = _callbacks()
	arrival.call("begin", player, spawn, true)
	check(root.get_camera_3d() == view and bool(player.get("enabled")) and _callbacks() == before_nonblocking and not paused, "nonblocking boundary changed local camera/control or global pause")
	await _advance(2.0)
	check(not bool(arrival.get("active")) and _callbacks() == before_nonblocking, "nonblocking subtitle failed to finish without changing control")

	# The module follows an existing menu pause rather than owning/clearing it.
	_reset_intro()
	arrival.call("begin", player, spawn)
	var remaining: float = float(arrival.get("_remaining"))
	paused = true
	await create_timer(0.15, true).timeout
	check(is_equal_approx(float(arrival.get("_remaining")), remaining) and paused, "presentation advanced or cleared an existing user pause")
	arrival.call("cancel")
	check(paused and root.get_camera_3d() == view, "cancel unexpectedly resumed an existing user pause")
	paused = false

	# Skip owns Space for this one event only, preserving unrelated game input.
	_reset_intro()
	arrival.call("begin", player, spawn)
	var space: InputEventKey = InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	root.push_input(space)
	await process_frame
	check(not bool(arrival.get("active")) and root.get_camera_3d() == view, "Space failed to skip and restore the view")

	# A newer view owner wins over this presentation's saved camera.
	_reset_intro()
	arrival.call("begin", player, spawn)
	var external_camera: Camera3D = Camera3D.new()
	stage.add_child(external_camera)
	external_camera.make_current()
	arrival.call("cancel")
	check(root.get_camera_3d() == external_camera, "cancel overwrote a newer camera owner")
	external_camera.queue_free()
	view.make_current()
	await process_frame

	# Missing camera falls back; losing the actual player safely finalizes.
	_reset_intro()
	view.clear_current()
	arrival.call("begin", player, spawn)
	check(arrival.get("_cut_camera") == null and bool(player.get("enabled")), "missing camera failed to degrade to subtitle-only")
	arrival.call("cancel")
	view.make_current()
	_reset_intro()
	arrival.call("begin", player, spawn)
	player.queue_free()
	await process_frame
	await process_frame
	check(not bool(arrival.get("active")), "deleted player left an active camera/input restoration")
	observations["cancellation_nonblocking_pause_skip_ownership"] = "checked"
	stage.queue_free()
	await process_frame
	await _main_wiring_regression()
	observations["failures"] = failures
	print(JSON.stringify(observations, "\t"))
	print("POLICE_ARRIVAL_REGRESSION_OK" if failures.is_empty() else "POLICE_ARRIVAL_REGRESSION_FAILED")
	quit(0 if failures.is_empty() else 1)
