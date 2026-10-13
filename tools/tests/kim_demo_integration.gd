extends SceneTree
## Real main scene, production attacks and ledger. Position-only combat fixture
## puts Kim in the existing clear aisle; his health/damage are never inflated.
const MAIN = preload("res://scenes/main.tscn")
var failures: Array[String] = []
var game: Node3D
var boss: CharacterBody3D
var hits: int = 0
var assessments: Dictionary = {"care": 0, "work": 0, "down": 0}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("KIM_DEMO_CHECK: " + message)

func step(count: int) -> void:
	for i in range(count): await physics_frame

func aim() -> void:
	var direction: Vector3 = boss.global_position + Vector3.UP * 1.25 - game.player.camera.global_position
	game.player.rotation.y = atan2(-direction.x, -direction.z)
	game.player._pitch = atan2(direction.y, Vector2(direction.x, direction.z).length())
	game.player._shake = 0.0
	game.player.camera.rotation = Vector3(game.player._pitch, 0, 0)

func run() -> void:
	game = MAIN.instantiate()
	root.add_child(game)
	current_scene = game
	game._automated_run = true
	game._resume()
	game.police_arrival.mode = "off"
	await step(5)
	boss = game.world.opening_boss
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var legacy: bool = "--kim-legacy" in args
	var health_only: bool = "--kim-health-only" in args
	check((boss._rig_adapter == null) == legacy, "default/rollback model mismatch")
	check(get_nodes_in_group("office_npc").size() == 8, "original 5+2 cast and CEO missing")
	for npc in get_nodes_in_group("office_npc"):
		if npc != boss:
			check(npc._rig_adapter == null and npc._visual.visible, "another character was replaced")
	if not legacy:
		check(not boss._visual.visible and boss._rig_adapter.visible, "duplicate or hidden Kim mesh")
		check(boss._rig_adapter.bodies.size() == 15, "missing real physical bones")
		check(boss._rig_adapter.clip == "Idle", "initial idle clip missing")
		# Verify production pose selection advances the skeleton, not only metadata.
		boss.opening_cancelled = true
		for motion: String in ["Walk", "Idle_Talking", "Idle"]:
			boss._walk_blend = 1.0 if motion == "Walk" else 0.0
			boss._talk_time = 1.0 if motion == "Idle_Talking" else 0.0
			boss._rig_adapter.update_pose(.2)
			check(boss._rig_adapter.clip == motion, "runtime clip selection: " + motion)
			boss._rig_adapter.update_pose(.2)
			check(boss._rig_adapter.skeleton.get_bone_global_pose(3).is_finite(), "runtime nonfinite pose")
			check(boss._rig_adapter.animation.current_animation_position > 0.0, "runtime motion did not advance")
	# Clear original opening scheduling by using the existing cancellation path.
	boss._cancel_opening()
	boss.global_position = Vector3(0, .02, 4)
	boss.velocity = Vector3.ZERO
	game.player.global_position = Vector3(0, .02, 5.15)
	game.player.velocity = Vector3.ZERO
	await step(3)
	game.player.action_performed.connect(func(kind, _at):
		if kind == "impact": hits += 1)
	boss.damage_assessed.connect(func(category, amount, _label):
		if category in assessments: assessments[category] = maxi(assessments[category], amount))
	boss.scored.connect(func(kind, _points, _at):
		if kind == "KNOCKDOWN": assessments.down += 1)
	# Frozen AI movement only keeps both comparisons on the exact same ray target.
	# Player windup, raycast, receive_hit, physics and main ledger all stay live.
	boss.set_physics_process(false)
	aim()
	game.player.perform_action("kick")
	await step(48)
	check(hits == 1, "production first kick missed")
	var first_down: bool = boss.state == "down"
	check(first_down == (not legacy and not health_only), "one-kick comparison disagreed")
	if not first_down:
		check(is_equal_approx(boss.health, 12.0), "comparison changed kick damage or initial health")
		if not legacy: check(boss._rig_adapter.reaction == "Medium", "surviving heavy hit did not stagger")
		aim()
		game.player.perform_action("kick")
		await step(48)
	check(boss.state == "down" and assessments.down == 1, "expected exactly one knockout")
	check(assessments.care == 300000 and assessments.work == 200000, "Kim assessments changed")
	if not legacy:
		check(boss._rig_adapter.ragdoll_active and boss.collision_layer == 0, "ragdoll/capsule ownership mismatch")
		var total: int = game.score
		var bone: PhysicalBone3D = boss._rig_adapter.bodies[0]
		for i in range(3): bone.receive_hit(Vector3(0, 2, 7), bone.global_position, 28)
		check(game.score == total and assessments.down == 1, "repeated physical hits rebilled")
	var report: Dictionary = {"mode": "legacy" if legacy else ("health-only" if health_only else "one-kick"), "first_kick_down": first_down, "actual_kicks": hits, "kim_assessments": assessments, "failures": failures}
	print("KIM_DEMO_RESULT ", JSON.stringify(report))
	game.sound.stop_all()
	game.queue_free()
	await process_frame
	await process_frame
	# Fresh real office, unchanged 40 HP: a real punch then a medium impulse
	# through the production receiver. This is not the separate ragdoll lab.
	game = MAIN.instantiate()
	root.add_child(game)
	current_scene = game
	game._automated_run = true
	game._resume()
	game.police_arrival.mode = "off"
	boss = game.world.opening_boss
	boss._cancel_opening()
	boss.global_position = Vector3(0, .02, 4)
	game.player.global_position = Vector3(0, .02, 5.15)
	await step(3)
	boss.set_physics_process(false)
	aim()
	game.player.perform_action("punch")
	await step(24)
	check(is_equal_approx(boss.health, 20.0) and boss.state != "down", "real Light punch failed")
	if not legacy: check(boss._rig_adapter.reaction == "Light", "Light visual response missing")
	boss.receive_hit(Vector3(9, 1, 0), boss.global_position + Vector3.UP * 1.3, 18)
	check(is_equal_approx(boss.health, 2.0) and boss.state != "down", "Medium hit should survive at original HP")
	if not legacy:
		check(boss._rig_adapter.reaction == "Medium", "Medium visual response missing")
		boss._rig_adapter.update_pose(.3)
		check(boss._rig_adapter.reaction_time > 0.0, "Medium reaction not running in demo")
		boss._rig_adapter.update_pose(1.2)
		check(boss._rig_adapter.reaction_time == 0.0 and not boss._rig_adapter.ragdoll_active, "Medium recovery failed")
	game.sound.stop_all()
	game.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty(): print("KIM_DEMO_INTEGRATION_OK")
	quit(0 if failures.is_empty() else 1)
