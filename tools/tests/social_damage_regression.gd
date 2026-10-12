extends SceneTree
## --headless --path game --script <absolute path> [-- --ledger-only]
## The full run checks the actual main/world signal boundary and result widgets.

const LedgerScript: Script = preload("res://scripts/social_damage.gd")

var failures: Array[String] = []
var observations: Dictionary = {}
var game: Node3D

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("SOCIAL_DAMAGE_CHECK: " + message)

func _test_ledger() -> void:
	var ledger: RefCounted = LedgerScript.new()
	check(ledger.total() == 0 and not ledger.is_frozen(), "new ledger was not empty and open")
	check(ledger.assess("", "property", 200000) == 0, "empty target booked a cost")
	check(ledger.assess("monitor", "unknown", 200000) == 0, "unknown category booked a cost")
	check(ledger.assess("monitor", "property", -1) == 0, "negative assessment booked a cost")
	check(ledger.assess("monitor", "property", 100000) == 100000, "first property assessment was not booked")
	check(ledger.assess("monitor", "property", 300000) == 200000, "replacement rebooked the already-assessed repair cost")
	check(ledger.assess("monitor", "property", 300000) == 0, "repeated damage invoice was booked")
	check(ledger.assess("monitor", "property", 100000) == 0, "lower assessment reversed cumulative loss")
	check(ledger.assess("employee-a", "work", 10000) == 10000, "initial interruption was not booked")
	check(ledger.assess("employee-a", "work", 200000) == 190000, "work incapacity double-counted interruption")
	check(ledger.assess("employee-a", "care", 300000) == 300000, "independent care expense was lost")
	check(ledger.assess("employee-b", "work", 10000) == 10000, "another employee's interruption was discarded")
	check(ledger.assess("employee-c", "work", 10000) == 10000, "third employee's interruption was discarded")
	check(ledger.assess("dispatch:guard", "response", 100000) == 100000, "guard dispatch was not booked")
	check(ledger.assess("dispatch:police", "response", 500000) == 500000, "police dispatch was not booked")
	check(ledger.assess("dispatch:police", "response", 500000) == 0, "same deployment was booked twice")
	check(ledger.total() == 1420000, "documented combined example did not total 1,420,000")
	var categories: Dictionary = ledger.breakdown()
	var category_sum: int = 0
	for category: String in LedgerScript.CATEGORIES:
		category_sum += int(categories[category])
	check(category_sum == ledger.total(), "category sum disagreed with the displayed total")
	observations["example"] = {"total": ledger.total(), "categories": categories.duplicate(true), "currency": LedgerScript.format_currency(ledger.total())}
	categories["property"] = 999999999
	check(int(ledger.breakdown()["property"]) == 300000, "result snapshot could mutate the ledger")
	ledger.freeze()
	check(ledger.assess("after-end", "care", 300000) == 0 and ledger.total() == 1420000, "frozen result accepted a late expense")
	ledger.reset()
	check(ledger.total() == 0 and not ledger.is_frozen(), "reset retained a frozen/result total")
	check(ledger.assessed("monitor", "property") == 0, "reset retained target history")
	check(ledger.assess("monitor", "property", 100000) == 100000, "next round could not reuse an old target id")
	for amount: int in [0, 999, 1000, 1420000, 12345678901]:
		var expected: Dictionary = {0: "$0", 999: "$999", 1000: "$1,000", 1420000: "$1,420,000", 12345678901: "$12,345,678,901"}
		check(LedgerScript.format_currency(amount) == str(expected[amount]), "currency grouping failed for %d" % amount)
	check(LedgerScript.RECORD_KEY == "social_damage_usd_v1", "dollar currency does not use its own record key")
	observations["ledger_delta_dedup_freeze_reset"] = failures.is_empty()

func _test_main_boundary() -> void:
	var main_script: Script = load("res://scripts/main.gd")
	check(main_script != null and main_script.can_instantiate(), "main script could not instantiate")
	if main_script == null or not main_script.can_instantiate():
		return
	game = main_script.new() as Node3D
	root.add_child(game)
	game.set("_automated_run", true)
	game.call("_resume")
	var world: Node3D = game.get("world") as Node3D
	var ledger: RefCounted = game.get("damage_ledger") as RefCounted
	var settings: ConfigFile = game.get("_settings") as ConfigFile
	settings.set_value("records", "high_score", 98765)
	settings.set_value("records", "social_damage_krw_v1", 24680000)
	check(game.call("_staff_count", "department") == 5 and game.call("_staff_count", "other") == 2, "main's real world did not contain the expected employee roster")
	world.emit_signal("damage_assessed", "expensive-monitor", "property", 10000000, "모니터 사용 불능")
	check(int(game.get("score")) == 10000000 and ledger.total() == 10000000, "world damage signal did not reach main's ledger")
	check(int(game.get("phase")) == 0 and float(game.get("response_heat")) == 0.0 and not bool(game.get("disturbed")), "money alone started or escalated a disturbance")
	var score_label: Label = game.get("_score_label") as Label
	check(score_label.text == "$10,000,000", "HUD did not format the ledger's exact amount")
	game.call("_on_impact", "THROW", 999999999, Vector3.ZERO)
	check(ledger.total() == 10000000 and float(game.get("response_heat")) == 0.0, "legacy point event changed money or response")
	game.call("_process", 180.0)
	check(int(game.get("phase")) == 0 and ledger.total() == 10000000, "idle time generated money or response")
	_test_caption_priority(world)
	world.emit_signal("incident_event", "ASSAULT", 3.0, Vector3.ZERO)
	check(int(game.get("phase")) == 1 and float(game.get("response_heat")) == 3.0 and ledger.total() == 10000000, "authoritative incident weight did not independently start response")
	paused = true
	var paused_elapsed: float = float(game.get("elapsed"))
	world.emit_signal("damage_assessed", "paused", "care", 300000, "일시정지")
	world.emit_signal("incident_event", "ASSAULT", 100.0, Vector3.ZERO)
	game.call("_process", 90.0)
	check(ledger.total() == 10000000 and float(game.get("response_heat")) == 3.0 and float(game.get("elapsed")) == paused_elapsed, "pause accepted new costs, incidents or elapsed time")
	paused = false
	world.emit_signal("incident_event", "ASSAULT", 5.0, Vector3.ZERO)
	check(int(game.get("phase")) == 2 and game.call("_staff_count", "security") == 1, "guard threshold did not spawn one actual responder")
	check(int(ledger.breakdown()["response"]) == 100000 and float(game.get("response_heat")) == 8.0, "guard cost was missing or recursively raised response heat")
	world.emit_signal("incident_event", "ASSAULT", 10.0, Vector3.ZERO)
	check(int(game.get("phase")) == 2, "police ignored the minimum stage delay")
	# Advance the controller's clock deliberately; this tests pending dispatch timing,
	# not locomotion or real-time arrival. The separate office regression covers those.
	game.set("elapsed", float(game.get("elapsed")) + 8.1)
	game.call("_update_response")
	check(int(game.get("phase")) == 3 and game.call("_staff_count", "security") == 2, "qualified pending police did not dispatch after its minimum delay")
	check(int(ledger.breakdown()["response"]) == 600000 and float(game.get("response_heat")) == 18.0, "police expense changed heat or was not booked")
	world.emit_signal("incident_event", "ASSAULT", 14.0, Vector3.ZERO)
	check(int(game.get("phase")) == 3, "reinforcement ignored the minimum stage delay")
	game.set("elapsed", float(game.get("elapsed")) + 10.1)
	game.call("_update_response")
	check(int(game.get("phase")) == 4 and game.call("_staff_count", "security") == 3, "reinforcement did not dispatch at the final threshold")
	check(int(ledger.breakdown()["response"]) == 1400000 and float(game.get("response_heat")) == 32.0, "reinforcement expense was missing or produced recursive escalation")
	world.call("escalate", 4)
	check(int(ledger.breakdown()["response"]) == 1400000 and game.call("_staff_count", "security") == 3, "duplicate escalation spawned or booked more responders")
	observations["controller"] = {"heat": game.get("response_heat"), "phase": game.get("phase"), "response_cost": ledger.breakdown()["response"], "responders": game.call("_staff_count", "security")}
	game.call("_clear_caption")
	var background_speaker: Node3D
	for employee: Node3D in world.get("npcs"):
		if str(employee.get("affiliation")) == "other":
			background_speaker = employee
			employee.emit_signal("said", "어… 저쪽 무슨 일이야?")
			break
	check(float(game.get("_caption_timer")) > 0.0 and game.get("_caption_source") == background_speaker, "guard-preemption fixture did not have a live ordinary caption")
	for responder: Node3D in world.get("npcs"):
		if str(responder.get("role")) == "guard":
			# Drive the guard's actual one-shot warning while an ordinary line is
			# still readable. Before the fix, its spoken flag was consumed forever
			# but main silently discarded the warning behind that older subtitle.
			responder.call("_advance_security", 0.01, 5.0, Vector3.FORWARD * 5.0)
			check(bool(responder.get("_guard_warning_spoken")), "guard did not consume its real warning trigger")
			check((game.get("_caption_label") as Label).text == "그만하시고 뒤로 물러나세요." and game.get("_caption_source") == responder, "actual guard warning was lost behind an ordinary subtitle")
			background_speaker.emit_signal("said", "늦게 들어온 구경꾼 대사")
			check(game.get("_caption_source") == responder, "ordinary bystander replaced the guard's warning")
			responder.call("_advance_security", 0.01, 5.0, Vector3.FORWARD * 5.0)
			check(game.get("_caption_source") == responder, "second security tick changed the visible warning")
			observations["guard_warning_preemption"] = "actual once-only warning preempted ordinary caption; ordinary followup did not replace it"
			break
	game.call("_end_run")
	var frozen: int = ledger.total()
	check(bool(game.get("ended")) and ledger.is_frozen() and paused, "end-run did not freeze the real ledger and simulation")
	var result_total: Label = game.get("_result_total") as Label
	check(result_total.text == LedgerScript.format_currency(frozen), "results total disagreed with HUD/ledger")
	var values: Dictionary = game.get("_result_values")
	var category_sum: int = 0
	for category: String in LedgerScript.CATEGORIES:
		var amount: int = int(ledger.breakdown()[category])
		category_sum += amount
		check((values[category] as Label).text == LedgerScript.format_currency(amount), "result category widget did not use the ledger: " + category)
	check(category_sum == frozen, "result categories did not add to frozen total")
	check(int(settings.get_value("records", "high_score", 0)) == 98765, "saving money overwrote the legacy point record")
	check(int(settings.get_value("records", "social_damage_krw_v1", 0)) == 24680000, "saving dollars overwrote the previous won record")
	check(int(settings.get_value(LedgerScript.RECORD_SECTION, LedgerScript.RECORD_KEY, 0)) >= frozen, "new currency record was not saved to its own key")
	world.emit_signal("damage_assessed", "late-body", "care", 300000, "종료 후 신호")
	world.emit_signal("incident_event", "ASSAULT", 3.0, Vector3.ZERO)
	check(ledger.total() == frozen and float(game.get("response_heat")) == 32.0, "late end-run events changed the result")
	paused = false
	world.call("reset_world")
	game.call("_reset_run_state")
	check(ledger.total() == 0 and not ledger.is_frozen() and float(game.get("response_heat")) == 0.0 and int(game.get("phase")) == 0, "reset did not clear ledger and response independently")
	check(game.call("_staff_count", "department") == 5 and game.call("_staff_count", "other") == 2 and game.call("_staff_count", "security") == 0, "reset did not restore five department employees, two others, no responders")
	world.emit_signal("damage_assessed", "expensive-monitor", "property", 100000, "새 평가")
	check(ledger.total() == 100000, "same target could not be assessed afresh after reset")
	observations["result_and_reset"] = {"frozen_total": frozen, "category_sum": category_sum, "legacy_record_preserved": int(settings.get_value("records", "high_score", 0)), "after_reset_new_assessment": ledger.total()}
	var sound: Node = game.get("sound") as Node
	sound.call("stop_all")
	game.queue_free()
	await process_frame
	await process_frame
	game = null

func _test_caption_priority(world: Node3D) -> void:
	var boss: Node3D = world.get("opening_boss") as Node3D
	var colleague: Node3D = world.get("opening_coworker") as Node3D
	check(is_instance_valid(boss) and is_instance_valid(colleague), "caption fixtures were not available")
	if not is_instance_valid(boss) or not is_instance_valid(colleague):
		return
	game.call("_clear_caption")
	world.emit_signal("ambient_dialogue", "박 대리", "오, 오늘은 제시간에 끝내게?", 2.8, colleague)
	var caption: Label = game.get("_caption_label") as Label
	check(caption.text == "오, 오늘은 제시간에 끝내게?" and game.get("_caption_source") == colleague, "ambient dialogue did not retain the real speaker")
	world.emit_signal("ambient_dialogue", "김 팀장", "무시될 배경 대사", 2.8, boss)
	check(caption.text == "오, 오늘은 제시간에 끝내게?", "ambient dialogue overwrote a line still being read")
	world.emit_signal("scene_dialogue", "김 팀장", "우선 대사", 2.8, boss)
	check(caption.text == "우선 대사" and bool(game.get("_caption_is_scene")), "priority scene failed to replace a background line")
	world.emit_signal("ambient_dialogue", "박 대리", "뒤늦은 배경 대사", 2.8, colleague)
	check(caption.text == "우선 대사", "background dialogue replaced the priority scene")
	world.emit_signal("scene_speaker_invalidated", boss)
	check(float(game.get("_caption_timer")) == 0.0 and game.get("_caption_source") == null, "invalidated scene speaker kept a visible caption")
	world.emit_signal("ambient_dialogue", "박 대리", "지워질 배경 대사", 2.8, colleague)
	world.emit_signal("scene_speaker_invalidated", colleague)
	check(float(game.get("_caption_timer")) == 0.0 and game.get("_caption_source") == null, "invalidated background speaker kept a visible caption")
	for employee: Node3D in world.get("npcs"):
		if str(employee.get("affiliation")) == "other":
			employee.emit_signal("said", "어… 뭐야?")
			check(caption.text == "어… 뭐야?" and game.get("_caption_source") == employee, "non-opening employee's actual speech signal could not reach the HUD")
			world.emit_signal("scene_speaker_invalidated", employee)
			break
	observations["caption_priority"] = "ambient has no queue; active line protected; scene preempts; both source types invalidate; non-opening staff speak"

func _run() -> void:
	_test_ledger()
	if not OS.get_cmdline_user_args().has("--ledger-only"):
		await _test_main_boundary()
	observations["failures"] = failures
	print(JSON.stringify(observations, "\t"))
	print("SOCIAL_DAMAGE_REGRESSION_OK" if failures.is_empty() else "SOCIAL_DAMAGE_REGRESSION_FAILED")
	quit(0 if failures.is_empty() else 1)
