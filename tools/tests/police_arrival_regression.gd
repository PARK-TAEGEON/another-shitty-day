extends SceneTree
## Native Godot regression for one-shot presentation, real dispatch and camera ownership.
## godot --headless --path game --script <absolute path to this script>
## Headless verifies state only; -- --capture-police --capture-dir <dir> renders stills.
const ArrivalScript: Script = preload("res://scripts/scenario/police_arrival.gd")
const PlayerScript: Script = preload("res://scripts/player.gd")
const WorldScript: Script = preload("res://scripts/world.gd")
const MainScript: Script = preload("res://scripts/main.gd")
const CeoScript: Script = preload("res://scripts/scenario/ceo_npc.gd")
const HoldScript: Script = preload("res://scripts/scenario/ceo_hold.gd")

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

func _held_pair_full_regression(spawn: Vector3) -> void:
	# A separate open-floor fixture isolates presentation from the office's live
	# pursuit/furniture. The real E path alone creates the held relation.
	var pair_stage: Node3D = Node3D.new()
	root.add_child(pair_stage)
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.position = Vector3(30.0, -0.1, 30.0)
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(12.0, 0.2, 12.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	pair_stage.add_child(floor_body)
	var holder: CharacterBody3D = PlayerScript.new() as CharacterBody3D
	holder.position = Vector3(30.0, 0.08, 30.0)
	holder.process_mode = Node.PROCESS_MODE_PAUSABLE
	pair_stage.add_child(holder)
	holder.call("set_active", true)
	var actor: CharacterBody3D = CeoScript.new() as CharacterBody3D
	actor.set("role", "ceo")
	actor.set("health", 90.0)
	actor.set("player_target", holder)
	actor.position = Vector3(30.0, 0.04, 29.05)
	pair_stage.add_child(actor)
	var relation: Node = HoldScript.new()
	relation.set("holder", holder)
	relation.process_mode = Node.PROCESS_MODE_PAUSABLE
	holder.add_child(relation)
	holder.set("actor_hold", relation)
	var pair_arrival: Node = ArrivalScript.new()
	pair_stage.add_child(pair_arrival)
	await _advance(1.6)
	holder.call("_pickup_or_drop")
	await _advance(0.08)
	check(is_instance_valid(relation) and bool(relation.get("active")) and relation.get("target") == actor, "real E input did not create the held pair for Full")
	if not is_instance_valid(relation) or not bool(relation.get("active")):
		pair_stage.queue_free()
		await process_frame
		player.get("camera").make_current()
		return
	var age: float = float(relation.get("age"))
	var clock: float = float(world.get("scenario_time"))
	var holder_position: Vector3 = holder.global_position
	var actor_position: Vector3 = actor.global_position
	pair_arrival.call("begin", holder, spawn)
	await _advance(0.4)
	check(paused and bool(relation.get("active")) and relation.get("target") == actor and actor.get("grabbed_by") == holder, "Full lost an already validated held pair")
	check(is_equal_approx(float(relation.get("age")), age) and is_equal_approx(float(world.get("scenario_time")), clock) and holder.global_position.is_equal_approx(holder_position) and actor.global_position.is_equal_approx(actor_position), "Full consumed hold age/game time or moved a held body")
	pair_arrival.call("cancel")
	await _advance(0.1)
	check(not paused and bool(relation.get("active")) and float(relation.get("age")) > age, "Full did not resume the same held pair and its clock")
	holder.call("_pickup_or_drop")
	check(not bool(relation.get("active")), "real E could not release the held pair after Full")
	observations["actual_held_pair_freeze_resume"] = {"held_age_during_cut": age, "game_time_during_cut": clock, "same_pair_resumed": true, "real_E_released": true}
	pair_stage.queue_free()
	await process_frame
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
	actual_arrival.set("mode", "full")
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
	# Damage cannot occur while Full owns the frozen world. Resume, then let the
	# existing guard's real palm contact flow through world.player_hit and Main.
	game.call("_on_player_hit", 100.0)
	check(not bool(game.get("ended")), "paused Full accepted new player damage")
	actual_arrival.call("cancel")
	actual_player.global_position = Vector3(0.0, 0.08, 3.0)
	game.set("composure", 5.0)
	var actual_guard: Node3D
	for npc: Node3D in actual_world.get("npcs"):
		if str(npc.get("role")) == "guard":
			actual_guard = npc
	check(is_instance_valid(actual_guard), "production subdual fixture had no existing guard")
	if is_instance_valid(actual_guard):
		actual_guard.global_position = Vector3(0.0, 0.08, 4.0)
		actual_guard.set("_cooldown", 0.0)
		actual_guard.set("velocity", Vector3.ZERO)
	await _advance(0.6)
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
	# Enter while an actual punch contact is pending. Full must preserve its
	# serial and timer, freeze physics, then resolve that same contact after resume.
	var contact_target: Node3D
	for npc: Node3D in world.get("npcs"):
		if str(npc.get("display_name")) == "박 대리":
			contact_target = npc
	check(is_instance_valid(contact_target), "accepted contact fixture had no protected coworker")
	if not is_instance_valid(contact_target):
		quit(1)
		return
	contact_target.global_position = Vector3(0.0, 0.08, 2.0)
	player.global_position = Vector3(0.0, 0.08, 3.5)
	view.look_at(contact_target.global_position + Vector3.UP * 1.1, Vector3.UP)
	player.set("_pitch", view.rotation.x)
	original_transform = view.global_transform
	var target_health: float = float(contact_target.get("health"))
	var airborne: RigidBody3D = world.get("props")[0] as RigidBody3D
	airborne.global_position = Vector3(0.0, 2.2, 5.0)
	airborne.freeze = false
	airborne.linear_velocity = Vector3(2.0, 1.0, 0.0)
	var airborne_position: Vector3 = airborne.global_position
	var clock_before: float = float(world.get("scenario_time"))
	var restored_view: Dictionary = {}
	arrival.connect("finished", func() -> void:
		if restored_view.is_empty():
			restored_view["basis"] = view.global_basis
			restored_view["fov"] = view.fov
			restored_view["mouse"] = Input.mouse_mode, CONNECT_ONE_SHOT)
	player.call("perform_action", "punch")
	var serial: int = int(player.get("_action_serial"))
	arrival.call("begin", player, spawn)
	check(bool(arrival.get("active")) and bool(arrival.get("presented")), "first arrival did not begin exactly once")
	check(root.get_camera_3d() == arrival.get("_cut_camera") and root.get_camera_3d() != view, "arrival did not cut to its native camera")
	check(paused and bool(player.get("enabled")) and not player.is_processing_unhandled_input() and not player.is_physics_processing(), "Full failed to own pause or modified accepted input/enabled")
	check((arrival.get("_title") as Label).text == "POLICE ARRIVED!" and (arrival.get("_panel") as Control).is_visible_in_tree(), "arrival subtitle is missing")
	var cut: Camera3D = arrival.get("_cut_camera") as Camera3D
	var toward: Vector3 = (spawn + Vector3.UP * 1.10 - cut.global_position).normalized()
	check((-cut.global_basis.z).dot(toward) > 0.999, "cut camera did not frame the actual spawn point")
	await _advance(0.25)
	check(actions.is_empty() and int(player.get("_action_serial")) == serial and is_equal_approx(float(contact_target.get("health")), target_health), "Full resolved/deleted an accepted punch while paused")
	check(is_equal_approx(float(world.get("scenario_time")), clock_before) and airborne.global_position.is_equal_approx(airborne_position), "Full did not freeze the game clock and in-flight physical prop")
	check(assessments.size() >= dispatch_count, "arrival removed the real dispatch assessment")
	await _capture("01-first-police-arrival")
	arrival.call("begin", player, spawn)
	await _advance(ArrivalScript.DURATION + 0.15)
	check(not bool(arrival.get("active")) and completions == 1, "timeout/repeated dispatch finalized more than once")
	check(not paused and root.get_camera_3d() == view and _callbacks() == original_callbacks, "timeout did not return original pause, camera and callback state")
	await _advance(0.18)
	check(actions.size() == 1 and actions[0] == "impact" and int(player.get("_action_serial")) == serial and float(contact_target.get("health")) < target_health, "resuming Full did not resolve the same accepted real punch exactly once")
	check(float(world.get("scenario_time")) > clock_before and not airborne.global_position.is_equal_approx(airborne_position), "resuming Full did not restore game time and physical motion")
	check(is_equal_approx(float(restored_view.get("fov", -1.0)), original_fov) and (restored_view.get("basis", Basis.IDENTITY) as Basis).is_equal_approx(original_transform.basis) and restored_view.get("mouse") == original_mouse, "arrival modified FOV, view rotation or mouse ownership before the pending hit resumed")
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
	await _advance(ArrivalScript.DURATION + 0.1)
	check(not bool(player.get("enabled")) and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "timeout resurrected externally disabled player/mouse ownership")

	# New round resets the presentation, but initially disabled/menu callers
	# receive subtitle only and retain their original inactive state.
	arrival.call("reset_round")
	arrival.call("begin", player, spawn)
	check(arrival.get("_cut_camera") == null and root.get_camera_3d() == view and not bool(player.get("enabled")), "inactive start forced a cut or enabled control")
	arrival.call("cancel")
	# Short and Off preserve live physics/input, and Off still consumes first arrival.
	_reset_intro()
	arrival.set("mode", "short")
	var short_callbacks: Array[bool] = _callbacks()
	var short_clock: float = float(world.get("scenario_time"))
	arrival.call("begin", player, spawn)
	check(bool(arrival.get("active")) and not paused and root.get_camera_3d() == view and _callbacks() == short_callbacks, "Short took camera/input or paused the world")
	await _advance(0.25)
	check(float(world.get("scenario_time")) > short_clock, "Short stopped the game clock")
	await _advance(ArrivalScript.SHORT_DURATION)
	check(not bool(arrival.get("active")), "Short did not finish near one second")
	_reset_intro()
	arrival.set("mode", "off")
	var off_callbacks: Array[bool] = _callbacks()
	arrival.call("begin", player, spawn)
	check(bool(arrival.get("presented")) and not bool(arrival.get("active")) and not (arrival.get("_panel") as Control).visible and not paused and root.get_camera_3d() == view and _callbacks() == off_callbacks, "Off presented or changed pause/camera/input")
	arrival.call("begin", player, spawn)
	check(not bool(arrival.get("active")), "Off replayed after consuming the first arrival")
	_reset_intro()
	arrival.set("mode", "full")
	var before_nonblocking: Array[bool] = _callbacks()
	arrival.call("begin", player, spawn, true)
	check(root.get_camera_3d() == view and bool(player.get("enabled")) and _callbacks() == before_nonblocking and not paused, "nonblocking boundary changed local camera/control or global pause")
	await _advance(2.0)
	check(not bool(arrival.get("active")) and _callbacks() == before_nonblocking, "nonblocking subtitle failed to finish without changing control")

	# The module follows an existing menu pause rather than owning/clearing it.
	_reset_intro()
	paused = true
	arrival.call("begin", player, spawn)
	var remaining: float = float(arrival.get("_remaining"))
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
	await _held_pair_full_regression(spawn)

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
