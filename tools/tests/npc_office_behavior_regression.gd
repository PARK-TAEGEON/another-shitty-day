extends SceneTree
## NPC integration checks with real physics: delayed work interruption, monetary
## deduplication, bystander threat changes, and the guard's interruptible push.
## Visual quality still requires the full office render and human play review.

const NpcScript: Script = preload("res://scripts/office_npc.gd")
const STEP: float = 1.0 / 60.0

var failures: Array[String] = []
var observations: Dictionary = {}
var stage: Node3D
var target: Node3D
var assessments: Array[Dictionary] = []
var incidents: Array[String] = []
var lines: Array[String] = []
var guard_hits: Array[float] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("NPC_OFFICE_CHECK: " + message)

func _advance(seconds: float) -> void:
	for frame: int in range(ceili(seconds / STEP)):
		await physics_frame

func _fixture() -> void:
	paused = false
	if is_instance_valid(stage):
		stage.queue_free()
		await process_frame
	assessments.clear()
	incidents.clear()
	lines.clear()
	guard_hits.clear()
	stage = Node3D.new()
	root.add_child(stage)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_collision: CollisionShape3D = CollisionShape3D.new()
	var floor_shape: BoxShape3D = BoxShape3D.new()
	floor_shape.size = Vector3(60, 0.2, 60)
	floor_collision.shape = floor_shape
	floor_body.position.y = -0.1
	floor_body.add_child(floor_collision)
	stage.add_child(floor_body)
	target = Node3D.new()
	target.position = Vector3(0, 0, 10)
	stage.add_child(target)

func _actor(at: Vector3, profile: String, activity: String, department: String = "department") -> CharacterBody3D:
	var actor: CharacterBody3D = NpcScript.new() as CharacterBody3D
	actor.position = at
	actor.set("display_name", "정 인턴" if profile == "intern" else profile)
	actor.set("personality", profile)
	actor.set("work_activity", activity)
	actor.set("affiliation", department)
	actor.set("player_target", target)
	actor.set("work_line", "이건 AI로 하면 금방 아닌가요?")
	actor.set("navigation_provider", func(_from: Vector3, destination: Vector3) -> PackedVector3Array: return PackedVector3Array([destination]))
	if department == "security":
		actor.set("role", "guard")
	actor.connect("damage_assessed", func(category: String, total: int, label: String) -> void: assessments.append({"category": category, "total": total, "label": label}))
	actor.connect("incident", func(kind: String, _weight: float, _at: Vector3) -> void: incidents.append(kind))
	actor.connect("said", func(text: String) -> void: lines.append(text))
	actor.connect("player_hit", func(amount: float) -> void: guard_hits.append(amount))
	stage.add_child(actor)
	return actor

func _run() -> void:
	await _fixture()
	var intern: CharacterBody3D = _actor(Vector3.ZERO, "intern", "papers")
	await _advance(0.20)
	check(bool(intern.call("is_working")), "intern did not begin working")
	check(is_instance_valid(intern.get("_work_prop")), "paper activity did not attach its document")
	check(bool(intern.call("speak_work_line")), "intern did not speak his work line")
	check(not bool(intern.call("speak_work_line")) and lines.size() == 1, "work line repeated for the same employee")
	intern.call("react", Vector3(20, 0, 0), 0.2)
	await _advance(0.20)
	check(bool(intern.call("is_working")) and assessments.is_empty(), "inaudible distant event charged a work loss")
	intern.call("react", Vector3(5, 0, 0), 1.0)
	await _advance(0.10)
	check(bool(intern.call("is_working")) and assessments.is_empty(), "distant reaction stopped work immediately")
	var before_pause: float = float(intern.get("_reaction_delay"))
	paused = true
	await _advance(0.40)
	check(is_equal_approx(float(intern.get("_reaction_delay")), before_pause), "reaction stagger advanced while paused")
	paused = false
	await _advance(0.75)
	check(not bool(intern.call("is_working")), "audible event did not stop work")
	check(assessments.size() == 1 and assessments[0]["total"] == 10000, "visible interruption did not assess exactly one work loss")
	check(not bool(intern.call("speak_work_line")), "interrupted intern delivered stale ordinary dialogue")
	intern.call("interrupt_work")
	intern.call("react", Vector3(5, 0, 0), 1.0)
	await _advance(0.8)
	check(assessments.size() == 1, "repeated attention charged the same loss twice")
	intern.call("receive_hit", Vector3.ZERO, intern.global_position, 18.0)
	intern.call("receive_hit", Vector3.ZERO, intern.global_position, 100.0)
	intern.call("receive_hit", Vector3.ZERO, intern.global_position, 100.0)
	check(incidents.size() == 2, "downed-body hit emitted another assault incident")
	check(assessments.size() == 3, "knockdown did not emit one care total and one replacement work total")
	check(assessments[1]["category"] == "care" and assessments[1]["total"] == 300000, "knockdown care total was wrong")
	check(assessments[2]["category"] == "work" and assessments[2]["total"] == 200000, "knockdown work amount was not the cumulative replacement total")
	observations["interruption_and_loss"] = assessments.duplicate(true)

	await _fixture()
	var spectator: CharacterBody3D = _actor(Vector3(5, 0, 0), "spectator", "papers", "other")
	var fearful: CharacterBody3D = _actor(Vector3(-5, 0, 0), "fearful", "copy", "other")
	spectator.call("react", Vector3.ZERO, 2.0)
	fearful.call("react", Vector3.ZERO, 2.0)
	await _advance(0.10)
	check(str(spectator.get("state")) == "idle" and str(fearful.get("state")) == "idle", "bystanders reacted instantly to a distant event")
	await _advance(0.60)
	check(str(spectator.get("state")) == "spectate", "curious bystander did not watch from a distance")
	check(str(fearful.get("state")) == "stunned", "fearful bystander skipped the frozen surprise beat")
	await _advance(0.70)
	check(str(fearful.get("state")) == "flee", "fearful bystander did not leave after the surprise beat")
	target.position = spectator.global_position + Vector3(0, 0, 1.4)
	spectator.call("react", spectator.global_position + Vector3(0, 0, 1.0), 2.0)
	await _advance(0.20)
	check(str(spectator.get("state")) == "flee", "watching bystander did not retreat from a close threat")
	check(lines.size() == 2 and assessments.size() == 2, "changing bystander reaction repeated a line or work charge")
	observations["bystanders"] = {"spectator_near_threat": spectator.get("state"), "fearful": fearful.get("state"), "line_count": lines.size(), "work_entries": assessments.size()}

	await _fixture()
	target.position = Vector3(0, 0, 1.0)
	var guard: CharacterBody3D = _actor(Vector3.ZERO, "guard", "idle", "security")
	guard.set("_cooldown", 0.0)
	await _advance(0.12)
	check(guard_hits.is_empty(), "guard hit before its palm-push windup")
	var wrists: Array = guard.get("_lecture_wrists")
	check(wrists.size() == 2 and (wrists[0] as Node3D).visible, "guard did not raise open hands")
	target.position = Vector3(0, 0, 4.0)
	await _advance(0.50)
	check(guard_hits.is_empty(), "guard push hit after the player left reach")
	guard.position = Vector3.ZERO
	guard.velocity = Vector3.ZERO
	target.position = Vector3(0, 0, 1.0)
	guard.set("_cooldown", 0.0)
	await _advance(0.35)
	check(guard_hits.size() == 1 and guard_hits[0] == 10.0, "guard did not subdue on a validated palm contact")
	await _advance(0.65)
	check(guard_hits.size() == 1, "guard repeated a hit inside the cooldown")
	check(lines.size() == 1, "guard repeated its short warning")
	guard.call("interrupt_work")
	guard.call("receive_hit", Vector3.ZERO, guard.global_position, 100.0)
	check(assessments.size() == 1 and assessments[0]["category"] == "care", "security time was counted again as general worker loss")
	observations["guard"] = {"warning_count": lines.size(), "validated_hits": guard_hits.duplicate(), "assessments": assessments.duplicate(true)}
	observations["failures"] = failures
	observations["passed"] = failures.is_empty()
	print(JSON.stringify(observations, "\t"))
	print("NPC_OFFICE_BEHAVIOR_REGRESSION_OK" if failures.is_empty() else "NPC_OFFICE_BEHAVIOR_REGRESSION_FAILED")
	stage.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
