extends RefCounted
## Reads already validated gameplay facts; never emits incidents, heat, or dollars.
## Contact and an actual NPC reaction must share a player root for action variety.

const RULES_PATH: String = "res://data/scenario/chaos_score_v1.json"
const SCENARIO_ID: String = "office"
const RULESET_VERSION: String = "scenario_v0_2"
const CHAOS_VERSION: String = "chaos_v1"
const RECORD_SECTION: String = "records"
const RECORD_KEY: String = SCENARIO_ID + "_" + RULESET_VERSION + "_" + CHAOS_VERSION
const ROUTE_RECORD_KEY: String = RECORD_KEY + "_route"
const MAX_SCORE: int = 1000

var route_result: Dictionary:
	get:
		return _route_result.duplicate(true)

var _rules: Dictionary = {}
var _round_id: String = ""
var _frozen: bool = false
var _rewards: Dictionary = {}
var _seen_events: Dictionary = {}
var _contacts: Dictionary = {}
var _reactions: Dictionary = {}
var _intervention_roots: Dictionary = {}
var _route_result: Dictionary = {}
var _totals: Dictionary = {"actions": 0, "npc_reactions": 0, "escalation": 0, "interventions": 0, "terminal": 0}

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	if parsed is Dictionary:
		_rules = parsed
	else:
		push_error("Chaos scoring data could not be loaded: " + RULES_PATH)

func reset(round_id: String) -> void:
	_round_id = round_id
	_frozen = false
	_rewards.clear()
	_seen_events.clear()
	_contacts.clear()
	_reactions.clear()
	_intervention_roots.clear()
	_route_result.clear()
	_totals = {"actions": 0, "npc_reactions": 0, "escalation": 0, "interventions": 0, "terminal": 0}

func consume(event: Dictionary) -> int:
	if _frozen or _rules.is_empty() or not _valid_player_fact(event):
		return 0
	var event_id: String = str(event["event_id"])
	if _seen_events.has(event_id):
		return 0
	var fact: String = str(event.get("fact", ""))
	var root_id: String = str(event["root_action_id"])
	var before: int = total()
	_seen_events[event_id] = true
	match fact:
		"action_contact":
			var action: String = _action_kind(event)
			if _rules.get("actions", []).has(action):
				# One root is one accepted input; transferred prop contacts cannot
				# transform the same input into a second action kind.
				if not _contacts.has(root_id):
					_contacts[root_id] = event.duplicate(true)
				_award_action(root_id)
		"npc_reaction":
			var target_id: String = str(event.get("target_id", ""))
			if not target_id.is_empty():
				_reactions[root_id] = event.duplicate(true)
				_award_action(root_id)
				if _reward_count("npc:") < int(_rules.get("npc_reaction_limit", 0)):
					_award("npc:" + target_id, "npc_reactions", int(_rules.get("npc_reaction_points", 0)), event)
		"work_interrupted", "guard_warning", "police_arrived":
			if _rules.get("escalation_facts", []).has(fact):
				_award("escalation:" + fact, "escalation", int(_rules.get("escalation_points", 0)), event)
		"route_intervention":
			_award_intervention(event)
		"route_resolved":
			_award_terminal(event)
	return total() - before

func total() -> int:
	return _general_total() + _special_total()

func breakdown() -> Dictionary:
	var result: Dictionary = _totals.duplicate(true)
	result["general"] = _general_total()
	result["special"] = _special_total()
	result["total"] = total()
	result["max_score"] = int(_rules.get("general_cap", 0)) + int(_rules.get("special_cap", 0))
	return result

func freeze() -> Dictionary:
	_frozen = true
	return breakdown()

func is_frozen() -> bool:
	return _frozen

func receipts() -> Dictionary:
	# Only evidence for paid, finite reward keys is exposed to tests/results.
	return _rewards.duplicate(true)

func _valid_player_fact(event: Dictionary) -> bool:
	return not _round_id.is_empty() \
		and str(event.get("round_id", "")) == _round_id \
		and not str(event.get("event_id", "")).is_empty() \
		and not str(event.get("root_action_id", "")).is_empty() \
		and str(event.get("instigator_id", "")) == "player" \
		and bool(event.get("validated", true))

func _action_kind(event: Dictionary) -> String:
	return str(event.get("action_kind", "")).to_lower()

func _award_action(root_id: String) -> void:
	if not _contacts.has(root_id) or not _reactions.has(root_id):
		return
	var contact: Dictionary = _contacts[root_id]
	var reaction: Dictionary = _reactions[root_id]
	var action: String = _action_kind(contact)
	# A reaction may omit action_kind, but an explicit mismatched kind is not proof.
	var reaction_action: String = _action_kind(reaction)
	if not reaction_action.is_empty() and reaction_action != action:
		return
	_award("action:" + action, "actions", int(_rules.get("action_points", 0)), contact)

func _award_intervention(event: Dictionary) -> void:
	if not _valid_route(event) or not _route_result.is_empty():
		return
	var transition: String = str(event.get("transition", ""))
	var root_id: String = str(event["root_action_id"])
	if not _rules.get("interventions", []).has(transition) \
		or _intervention_roots.has(root_id) \
		or _reward_count("intervention:") >= int(_rules.get("intervention_limit", 0)):
		return
	var key: String = "intervention:" + str(event.get("route_id", "")) + ":" + transition
	if _award(key, "interventions", int(_rules.get("intervention_points", 0)), event) > 0:
		_intervention_roots[root_id] = key

func _award_terminal(event: Dictionary) -> void:
	if not _valid_route(event) or not _route_result.is_empty():
		return
	var outcome: String = str(event.get("outcome", ""))
	if not _rules.get("outcomes", []).has(outcome):
		return
	var root_id: String = str(event["root_action_id"])
	# If this causal action first produced an intermediate fact, promote its
	# receipt to terminal 400: remove the old 100 and add 400 (net +300).
	if _intervention_roots.has(root_id):
		var previous_key: String = str(_intervention_roots[root_id])
		var previous: Dictionary = _rewards[previous_key]
		_totals["interventions"] = int(_totals["interventions"]) - int(previous["points"])
		previous["points"] = 0
		previous["promoted_to_terminal"] = true
		_rewards[previous_key] = previous
	var key: String = "terminal:" + str(event.get("route_id", ""))
	_award(key, "terminal", int(_rules.get("terminal_points", 0)), event)
	_route_result = {
		"route_id": str(event.get("route_id", "")),
		"outcome": outcome,
		"event_id": str(event["event_id"]),
		"root_action_id": root_id,
	}

func _valid_route(event: Dictionary) -> bool:
	return str(event.get("route_id", "")) == str(_rules.get("route_id", ""))

func _award(key: String, category: String, points: int, event: Dictionary) -> int:
	if _rewards.has(key) or points <= 0:
		return 0
	var current: int = _general_total() if category in ["actions", "npc_reactions", "escalation"] else _special_total()
	var cap_key: String = "general_cap" if category in ["actions", "npc_reactions", "escalation"] else "special_cap"
	var paid: int = mini(points, maxi(0, int(_rules.get(cap_key, 0)) - current))
	if paid <= 0:
		return 0
	_totals[category] = int(_totals[category]) + paid
	_rewards[key] = {
		"round_id": _round_id,
		"reward_key": key,
		"points": paid,
		"event_id": str(event["event_id"]),
		"root_action_id": str(event["root_action_id"]),
		"fact": str(event.get("fact", "")),
	}
	return paid

func _reward_count(prefix: String) -> int:
	var count: int = 0
	for key: String in _rewards:
		if key.begins_with(prefix):
			count += 1
	return count

func _general_total() -> int:
	return int(_totals["actions"]) + int(_totals["npc_reactions"]) + int(_totals["escalation"])

func _special_total() -> int:
	return int(_totals["interventions"]) + int(_totals["terminal"])
