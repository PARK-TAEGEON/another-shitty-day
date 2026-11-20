extends SceneTree
## Punch staggers, a kick or a quick second strike launches, and Kim's nagging
## opening refuses a knockdown. Damage totals stay on the existing ledger path.
const NPC = preload("res://scripts/office_npc.gd")
const MAIN = preload("res://scenes/main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("HIT_FEEL_CHECK: " + message)

func step(count: int) -> void:
	for _i in range(count):
		await physics_frame

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var legacy: bool = "--kim-legacy" in args
	var health_only: bool = "--kim-health-only" in args
	var stage := Node3D.new()
	root.add_child(stage)
	var punch := _actor(stage, "boss", true)
	var lines: Array[String] = []
	punch.said.connect(func(text: String) -> void: lines.append(text))
	punch.receive_hit(Vector3(7, 2, 0), punch.global_position + Vector3(0, 1.4, 0), 20.0, "punch")
	check(punch.state != "down" and is_equal_approx(punch.health, 20.0), "one punch knocked down or changed damage")
	check(_has_line(lines), "punch stagger line missing")
	if not legacy and punch._rig_adapter != null:
		check(punch._rig_adapter.reaction == "Light" and not punch._rig_adapter.ragdoll_active, "punch did not stay a Light stagger")
	var kick := _actor(stage, "boss", true)
	var bill: Dictionary = {"care": 0, "work": 0, "down": 0}
	kick.damage_assessed.connect(func(category: String, amount: int, _label: String) -> void:
		if category in bill:
			bill[category] = amount
	)
	kick.scored.connect(func(kind: String, _points: int, _at: Vector3) -> void:
		if kind == "KNOCKDOWN":
			bill.down += 1
	)
	kick.receive_hit(Vector3(13, 2, 0), kick.global_position + Vector3(0, 1.3, 0), 28.0, "kick")
	var kick_downs: bool = not legacy and not health_only
	check((kick.state == "down") == kick_downs, "one kick disagreed with the Kim comparison")
	if kick_downs:
		check(int(bill.care) == 300000 and int(bill.work) == 200000 and int(bill.down) == 1, "knockdown ledger changed")
		if kick._rig_adapter != null:
			check(kick._rig_adapter.ragdoll_active, "kick did not hand the hybrid rig to physics")
			var kicked_arc: Dictionary = await _sample_flight(kick, true)
			check(float(kicked_arc.far) >= 3.0, "kick did not travel 3m, got %s" % str(kicked_arc.far))
			check(float(kicked_arc.rise) >= 1.0, "kick did not rise 1m, got %s" % str(kicked_arc.rise))
	else:
		check(is_equal_approx(kick.health, 12.0) and int(bill.care) == 0 and int(bill.down) == 0, "comparison kick changed health or billed a knockdown")
	var combo := _actor(stage, "guard", false)
	combo.receive_hit(Vector3(7, 2, 0), combo.global_position + Vector3(0, 1.3, 0), 20.0, "punch")
	check(combo.state != "down" and is_equal_approx(combo.health, 28.0), "guard punch should only stagger")
	combo.receive_hit(Vector3(7, 2, 0), combo.global_position + Vector3(0, 1.3, 0), 20.0, "punch")
	check(combo.state == "down" and is_equal_approx(combo.health, 0.0), "second punch inside the window did not launch the guard")
	var combo_arc: Dictionary = await _sample_flight(combo, false)
	check(float(combo_arc.far) >= 3.0, "second hit did not travel 3m, got %s" % str(combo_arc.far))
	check(float(combo_arc.rise) >= 1.0, "second hit did not rise 1m, got %s" % str(combo_arc.rise))
	var coworker := _actor(stage, "observer", false)
	var coworker_lines: Array[String] = []
	coworker.said.connect(func(text: String) -> void: coworker_lines.append(text))
	coworker.receive_hit(Vector3(7, 2, 0), coworker.global_position + Vector3(0, 1.3, 0), 20.0, "punch")
	check(coworker.state != "down" and _has_line(coworker_lines), "coworker punch did not stagger with the line")
	var kicked := _actor(stage, "observer", false)
	kicked.receive_hit(Vector3(13, 2, 0), kicked.global_position + Vector3(0, 1.3, 0), 28.0, "kick")
	check(kicked.state == "down", "coworker kick did not launch")
	var coworker_arc: Dictionary = await _sample_flight(kicked, false)
	check(float(coworker_arc.far) >= 3.0, "coworker kick did not travel 3m, got %s" % str(coworker_arc.far))
	check(float(coworker_arc.rise) >= 1.0, "coworker kick did not rise 1m, got %s" % str(coworker_arc.rise))
	var late := _actor(stage, "guard", false)
	var late_lines: Array[String] = []
	late.said.connect(func(text: String) -> void: late_lines.append(text))
	late.receive_hit(Vector3(7, 2, 0), late.global_position + Vector3(0, 1.3, 0), 20.0, "punch")
	check(late.state != "down", "late-window setup punch knocked the guard out")
	var window_ms: int = int(round(preload("res://scripts/hit_feel.gd").load_settings().second_hit_window * 1000.0))
	var waited_from: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - waited_from < window_ms + 120:
		await process_frame
	late_lines.clear()
	late.receive_hit(Vector3(7, 2, 0), late.global_position + Vector3(0, 1.3, 0), 20.0, "punch")
	check(late.state != "down" and late.health > 0.0, "punch after the combo window still knocked the guard out")
	check(_has_line(late_lines), "punch after the combo window did not stagger")
	stage.queue_free()
	await step(2)
	var game: Node = MAIN.instantiate()
	root.add_child(game)
	current_scene = game
	game._automated_run = true
	game._resume()
	game.police_arrival.mode = "off"
	await step(3)
	var boss: CharacterBody3D = game.world.opening_boss
	var said: Array[String] = []
	var opening_bill: Dictionary = {"care": 0}
	boss.said.connect(func(text: String) -> void: said.append(text))
	boss.damage_assessed.connect(func(category: String, amount: int, _label: String) -> void:
		if category == "care":
			opening_bill.care = amount
	)
	game.world.opening_started = true
	game.world.boss_lecture_finished = false
	check(boss.opening_blocks_knockdown(), "nagging opening did not block Kim")
	boss.receive_hit(Vector3(13, 2, 0), boss.global_position + Vector3(0, 1.3, 0), 28.0, "kick")
	check(boss.state != "down" and boss.health > 0.0 and int(opening_bill.care) == 0, "Kim was knocked out during the nagging opening")
	check(_has_line(said), "opening stagger line missing")
	game.world.boss_lecture_finished = true
	boss.receive_hit(Vector3(13, 2, 0), boss.global_position + Vector3(0, 1.3, 0), 28.0, "kick")
	check(boss.state == "down", "Kim stayed up after the nagging opening finished")
	game.sound.stop_all()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("HIT_FEEL_REGRESSION_OK")
	else:
		print("HIT_FEEL_REGRESSION_FAILED: ", failures)
	quit(0 if failures.is_empty() else 1)

func _sample_flight(actor: CharacterBody3D, use_pelvis: bool) -> Dictionary:
	var start: Vector3 = actor.global_position
	if use_pelvis and actor._rig_adapter != null:
		start = actor._rig_adapter.pelvis_position()
	var peak: float = start.y
	var far: float = 0.0
	for _i in range(80):
		await physics_frame
		var now: Vector3 = actor.global_position
		if use_pelvis and actor._rig_adapter != null and actor._rig_adapter.bodies.size() > 0:
			now = actor._rig_adapter.pelvis_position()
		peak = maxf(peak, now.y)
		far = maxf(far, Vector2(now.x - start.x, now.z - start.z).length())
	return {"far": far, "rise": peak - start.y}

func _actor(stage: Node, role_name: String, kim: bool) -> CharacterBody3D:
	var actor = NPC.new()
	actor.role = role_name
	actor.display_name = "김 팀장" if kim else role_name
	actor.use_kim_rig = kim
	if role_name == "guard":
		actor.affiliation = "security"
	stage.add_child(actor)
	return actor

func _has_line(lines: Array[String]) -> bool:
	for line: String in lines:
		if "꾸엑" in line and "뭐, 뭐야" in line:
			return true
	return false
