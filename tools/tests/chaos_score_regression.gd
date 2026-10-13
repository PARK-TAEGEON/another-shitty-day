extends SceneTree
## --headless --path game --script <absolute path>
## Tests the bounded scoring consumer, not visual quality or gameplay enjoyment.

const ScoreScript: Script = preload("res://scripts/scenario/chaos_score.gd")

var failures: Array[String] = []
var observations: Dictionary = {}
var _serial: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("CHAOS_SCORE_CHECK: " + message)

func _event(fact: String, root_id: String, action: String = "throw", actor: String = "employee-a") -> Dictionary:
	_serial += 1
	return {
		"round_id": "round-one",
		"event_id": "event-%d" % _serial,
		"root_action_id": root_id,
		"instigator_id": "player",
		"action_kind": action,
		"target_id": actor,
		"fact": fact,
		"route_id": "office_ceo",
	}

func _intervention(root_id: String, transition: String) -> Dictionary:
	var event: Dictionary = _event("route_intervention", root_id)
	event["transition"] = transition
	return event

func _terminal(root_id: String, outcome: String) -> Dictionary:
	var event: Dictionary = _event("route_resolved", root_id)
	event["outcome"] = outcome
	return event

func _new_score() -> RefCounted:
	var score: RefCounted = ScoreScript.new()
	score.reset("round-one")
	return score

func _test_validated_facts() -> void:
	var score: RefCounted = _new_score()
	check(score.total() == 0 and not score.is_frozen(), "new round was not empty and open")
	for invalid: Dictionary in [
		{},
		{"round_id": "round-one", "event_id": "empty-root", "root_action_id": "", "instigator_id": "player", "fact": "guard_warning"},
		{"round_id": "old-round", "event_id": "old-event", "root_action_id": "old-root", "instigator_id": "player", "fact": "police_arrived"},
		{"round_id": "round-one", "event_id": "npc-auto", "root_action_id": "npc-root", "instigator_id": "npc", "fact": "route_resolved", "route_id": "office_ceo", "outcome": "A"},
		{"round_id": "round-one", "event_id": "unvalidated", "root_action_id": "player-root", "instigator_id": "player", "fact": "guard_warning", "validated": false},
	]:
		check(score.consume(invalid) == 0, "invalid, stale, or autonomous fact paid a reward")
	check(score.route_result.is_empty(), "invalid fact recorded a special ending")
	check(score.consume(_event("action_contact", "air", "unknown")) == 0, "unknown action paid a reward")
	check(score.consume(_event("action_contact", "hit", "punch")) == 0, "contact without an NPC reaction paid action variety")
	check(score.consume(_event("npc_reaction", "other-root", "punch")) == 30, "first actual NPC reaction did not pay 30")
	check(int(score.breakdown()["actions"]) == 0, "reaction on another root validated a contact")
	var matched_reaction: Dictionary = _event("npc_reaction", "hit", "punch")
	check(score.consume(matched_reaction) == 40, "matched contact/reaction did not pay action variety")
	for replay: int in range(10):
		check(score.consume(matched_reaction) == 0, "same event replay paid again")
	check(score.consume(_event("npc_reaction", "new-root", "punch")) == 0, "same actor paid repeatedly under new roots")
	var malformed_actor: Dictionary = _event("npc_reaction", "empty-actor", "kick", "")
	check(score.consume(malformed_actor) == 0, "empty actor paid an NPC reward")
	check(score.total() == 70, "validated fact sample total should be 70")
	observations["validated_contact_and_reaction"] = score.breakdown()
	# Different ordering remains valid: the actual reaction fact may arrive first.
	score = _new_score()
	check(score.consume(_event("npc_reaction", "reverse", "slam")) == 30, "reaction-first delivery lost NPC reward")
	check(score.consume(_event("action_contact", "reverse", "slam")) == 40, "reaction-first delivery lost variety reward")
	# A contact from the same physical root cannot masquerade as another input.
	check(score.consume(_event("action_contact", "reverse", "kick")) == 0, "one root became another action kind")
	check(int(score.breakdown()["actions"]) == 40, "one root produced multiple variety rewards")

func _test_general_limits() -> void:
	var score: RefCounted = _new_score()
	for index: int in range(4):
		var action: String = ["slam", "punch", "kick", "throw"][index]
		var root_id: String = "input-%d" % index
		score.consume(_event("action_contact", root_id, action))
		score.consume(_event("npc_reaction", root_id, action, "actor-%d" % index))
	for index: int in range(10):
		score.consume(_event("npc_reaction", "extra-%d" % index, "throw", "extra-actor-%d" % index))
	for fact: String in ["work_interrupted", "guard_warning", "police_arrived"]:
		check(score.consume(_event(fact, "response-source")) == 40, "first confirmed escalation did not pay 40")
		check(score.consume(_event(fact, "another-source")) == 0, "same escalation paid under another root")
	check(score.total() == 400, "general rewards exceeded or failed to reach cap 400")
	var detail: Dictionary = score.breakdown()
	check(int(detail["actions"]) == 160 and int(detail["npc_reactions"]) == 120 and int(detail["escalation"]) == 120, "general category caps differ from 160/120/120")
	observations["general_cap"] = detail
	score.consume(_intervention("special-one", "authority_reversal"))
	score.consume(_intervention("special-two", "supported_reversal"))
	score.consume(_terminal("special-three", "A"))
	check(score.total() == ScoreScript.MAX_SCORE, "complete general and special reward set did not reach exactly 1,000")
	check(int(score.breakdown()["general"]) == 400 and int(score.breakdown()["special"]) == 600, "combined score merged the independent category caps")
	observations["combined_cap"] = score.breakdown()
	# Documented repeated-chair example is 40 + 30 + 40, regardless of repeats.
	score = _new_score()
	for index: int in range(10):
		var root_id: String = "chair-%d" % index
		score.consume(_event("action_contact", root_id))
		score.consume(_event("npc_reaction", root_id))
		score.consume(_event("work_interrupted", root_id))
	check(score.total() == 110, "repeated chair example did not stay at 110")
	observations["repeat_chair"] = score.breakdown()

func _test_special_roots_and_outcomes() -> void:
	for outcome: String in ["A", "B"]:
		for attempt: int in range(3):
			var direct: RefCounted = _new_score()
			check(direct.consume(_terminal("direct", outcome)) == 400, "direct %s terminal did not pay 400" % outcome)
			check(direct.consume(_terminal("other-terminal", "B" if outcome == "A" else "A")) == 0, "exclusive second ending paid")
			check(direct.consume(_intervention("late", "authority_reversal")) == 0, "resolved route accepted a late intervention")
			check(direct.route_result["outcome"] == outcome and direct.total() == 400, "terminal result was replaced or overpaid")
	var score: RefCounted = _new_score()
	check(score.consume(_intervention("first", "authority_reversal")) == 100, "first intervention did not pay 100")
	check(score.consume(_intervention("first", "supported_reversal")) == 0, "same root paid a second transition")
	check(score.consume(_intervention("other", "authority_reversal")) == 0, "same semantic transition paid under a different root")
	check(score.consume(_intervention("second", "supported_reversal")) == 100, "distinct root/transition did not pay another 100")
	check(score.consume(_terminal("third", "B")) == 400, "third root terminal lost its 400 reward")
	check(score.total() == 600, "two distinct interventions plus terminal did not total 600")
	observations["three_distinct_roots"] = score.breakdown()
	# The root that first earns 100 and then resolves must total 400, not 500.
	score = _new_score()
	check(score.consume(_intervention("shared", "authority_reversal")) == 100, "promotion setup did not pay 100")
	check(score.consume(_terminal("shared", "A")) == 300, "same-root terminal did not apply only the 300 upgrade")
	check(score.total() == 400 and int(score.breakdown()["interventions"]) == 0 and int(score.breakdown()["terminal"]) == 400, "same-root promotion double-counted intermediate points")
	check(score.consume(_terminal("shared", "A")) == 0, "promoted root replay paid again")
	observations["same_root_promotion"] = score.breakdown()
	# Other confirmed intermediate causes remain after promoting the terminal cause.
	score = _new_score()
	score.consume(_intervention("kept", "authority_reversal"))
	score.consume(_intervention("promoted", "supported_reversal"))
	check(score.consume(_terminal("promoted", "B")) == 300, "promotion with another cause did not return 300")
	check(score.total() == 500 and int(score.breakdown()["interventions"]) == 100, "promotion erased another root's confirmed intervention")
	observations["preserve_other_root"] = score.breakdown()
	score = _new_score()
	var wrong_route: Dictionary = _terminal("wrong-route", "A")
	wrong_route["route_id"] = "market"
	check(score.consume(wrong_route) == 0, "foreign route was scored with office rules")
	check(score.consume(_intervention("unknown", "entered_room")) == 0, "discovery/entry paid a special reward")
	check(score.consume(_terminal("invalid-outcome", "escaped")) == 0, "unknown ending paid terminal reward")

func _test_freeze_reset_and_snapshots() -> void:
	var score: RefCounted = _new_score()
	score.consume(_intervention("unfinished", "authority_reversal"))
	var frozen: Dictionary = score.freeze()
	check(score.is_frozen() and int(frozen["total"]) == 100, "freeze lost earned partial score")
	check(score.consume(_terminal("late", "A")) == 0 and score.route_result.is_empty(), "late terminal contaminated frozen result")
	frozen["total"] = 9000
	var receipts: Dictionary = score.receipts()
	for key: String in receipts:
		receipts[key]["points"] = 9000
	check(score.total() == 100 and int(score.receipts().values()[0]["points"]) == 100, "snapshot mutated live score or evidence")
	score.reset("round-two")
	check(score.total() == 0 and not score.is_frozen() and score.receipts().is_empty(), "restart retained total, freeze, or receipts")
	check(score.consume(_terminal("old", "B")) == 0, "previous round terminal paid after reset")
	var current: Dictionary = _terminal("unfinished", "B")
	current["round_id"] = "round-two"
	check(score.consume(current) == 400, "new round could not reuse a previous root")
	var result: Dictionary = score.route_result
	result["outcome"] = "A"
	check(score.route_result["outcome"] == "B", "public route result mutated internal outcome")
	check(ScoreScript.RECORD_KEY == "office_scenario_v0_2_chaos_v1", "Chaos record lacks scenario/rules/score versions")
	check(ScoreScript.RECORD_KEY != "social_damage_usd_v1" and ScoreScript.ROUTE_RECORD_KEY != ScoreScript.RECORD_KEY, "Chaos overwrites dollar or route record")
	observations["freeze_reset"] = score.breakdown()

func _run() -> void:
	_test_validated_facts()
	_test_general_limits()
	_test_special_roots_and_outcomes()
	_test_freeze_reset_and_snapshots()
	print("CHAOS_SCORE_RESULT " + JSON.stringify({"passed": failures.is_empty(), "failures": failures, "observations": observations}))
	print("CHAOS_SCORE_REGRESSION_OK" if failures.is_empty() else "CHAOS_SCORE_REGRESSION_FAILED")
	quit(0 if failures.is_empty() else 1)
