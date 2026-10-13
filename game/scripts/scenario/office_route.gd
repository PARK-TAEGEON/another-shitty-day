extends Node
## O-30..38 finite content state. Results require a fresh action and actual arrival.
const PUBLIC: Vector3 = Vector3(9.9, 0.02, -0.8)
const VISITOR: Vector3 = Vector3(12.5, 0.02, 0.8)
const AUTHORITY: Vector3 = Vector3(12.7, 0.02, -2.8)
const SUPPORT: Vector3 = Vector3(9.5, 0.02, 1.0)
const CLEANUP: Vector3 = Vector3(9.9, 1.0, -2.5)
var world: Node3D
var ceo: CharacterBody3D
var command_prop: RigidBody3D
var authority_props: Array[Node3D] = []
var status: String = "available"
var attitude: String = "authority"
var outcome: String = ""
var candidate: Dictionary = {}
var _spoken: Dictionary = {}
var _support_seen: bool = false
var _escape_started: bool = false
var _clock: float = 0.0
var _carry: Dictionary = {}
var _seen_actions: Dictionary = {}

func _ready() -> void:
	ceo.scenario_hit.connect(_on_ceo_hit)

func _on_ceo_hit() -> void:
	_cancel_candidate()
	world.cancel_scenario_speaker(ceo)
	if _living():
		ceo.settle(world.player_target.global_position, ceo.commanding)

func _observes(target: Node3D) -> bool:
	if ceo.global_position.distance_to(target.global_position) > 6.5:
		return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ceo.global_position + Vector3.UP * 1.45, target.global_position + Vector3.UP * (1.0 if target == command_prop else 0.25), 1)
	return world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func in_area(at: Vector3) -> bool:
	return at.x > 7.0 and at.x < 15.9 and at.z > -6.0 and at.z < 4.0

func _living() -> bool:
	return is_instance_valid(ceo) and ceo.is_inside_tree() and ceo.state != "down" and ceo.health > 0.0

func _say(beat: String, text: String, priority: int = 60) -> void:
	if _spoken.has(beat) or not _living():
		return
	_spoken[beat] = true
	world.queue_scenario_line(beat, ceo, text, priority)

func _cancel_candidate() -> void:
	candidate.clear()

func finish() -> void:
	_cancel_candidate()
	_carry.clear()
	if status in ["active", "suspended"]:
		status = "interrupted"

func on_action(event: Dictionary, target: Node3D) -> void:
	if event.is_empty() or str(event.get("round_id", "")) != world.events.round_id or event.get("instigator_id", "") != "player" or not bool(event.get("validated", false)) or not is_instance_valid(target):
		return
	if not _living():
		if status != "resolved":
			status = "failed"
		_cancel_candidate()
		return
	if status in ["resolved", "failed", "interrupted"] or not is_instance_valid(world.player_target):
		return
	if not in_area(world.player_target.global_position):
		return
	var kind: String = str(event.get("action_kind", ""))
	var fact: String = str(event.get("fact", ""))
	if kind == "pickup" and target in authority_props:
		_carry = {"prop": target, "origin": target.global_position, "event": event, "consumed": false}
		return
	var root_id: String = str(event.get("root_action_id", ""))
	if root_id.is_empty() or _seen_actions.has(root_id):
		return
	_seen_actions[root_id] = true
	if kind == "drop":
		_carry.clear()
	var relevant: bool = target == ceo or target in authority_props or target.global_position.distance_to(ceo.global_position) < 3.5
	relevant = relevant and (target == ceo or _observes(target))
	var violent: bool = kind in ["slam", "punch", "kick", "throw"] and fact == "action_contact"
	if status == "available":
		if not violent or not relevant:
			return
		status = "active"
		if world.opening_elapsed >= 6.5:
			world.cancel_opening_scene()
		ceo.interrupt_work()
		_say("O-31", "여기가 누구 방인 줄 알아?")
	if status == "suspended":
		status = "active"
	if status != "active":
		return
	if not relevant and violent:
		_cancel_candidate()
		return
	if not relevant:
		return
	# A new local player action supersedes the old candidate, never completes it.
	# A harmless release preserves the already-observed carry cause and its TTL.
	if kind == "drop" and target == command_prop and not candidate.is_empty() and candidate["result"] == "B" and _command_unusable():
		return
	_cancel_candidate()
	if target == command_prop and kind in ["drop", "carry", "punch", "kick", "throw"] and _command_lost(event):
		_propose("B", event, VISITOR)
		return
	if target in authority_props and kind in ["drop", "carry"]:
		if target.global_position.x < 11.0 and target.global_position.z < 0.4:
			_propose("A", event, PUBLIC)
			return
		if target.global_position.distance_to(AUTHORITY) > 0.8:
			var away: Vector3 = ceo.global_position - target.global_position
			away.y = 0.0
			var follow: Vector3 = target.global_position + away.normalized() * 1.0
			follow.y = 0.02
			_propose("authority_reversal", event, follow)
			_say("O-33", "그건 수상 실적이 아니라 실물이야!", 55)
			return
	if not violent:
		return
	if is_instance_valid(command_prop) and _command_lost(event):
		if target == command_prop or (target.global_position.distance_to(command_prop.global_position) < 2.0):
			_propose("B", event, VISITOR)
			return
	if target == ceo and ceo.global_position.distance_to(PUBLIC) < 2.0:
		_propose("A", event, PUBLIC)
	elif attitude == "supported":
		_propose("supported_reversal", event, VISITOR)
	else:
		_propose("authority_reversal", event, VISITOR)

func _command_lost(event: Dictionary) -> bool:
	if not is_instance_valid(command_prop):
		return false
	var before: Dictionary = event.get("command_before", {})
	if before.is_empty():
		return false
	var seat: Vector3 = AUTHORITY + Vector3(0.8, 0, 0)
	var previous: Vector3 = before.get("position", command_prop.global_position)
	return (int(before.get("damage", 2)) < 2 and command_prop.damage_stage >= 2) or (previous.distance_to(seat) <= 1.5 and command_prop.global_position.distance_to(seat) > 1.5)

func _command_unusable() -> bool:
	return is_instance_valid(command_prop) and (command_prop.damage_stage >= 2 or command_prop.global_position.distance_to(AUTHORITY + Vector3(0.8, 0, 0)) > 1.5)

func _propose(result: String, event: Dictionary, destination: Vector3) -> void:
	var remaining: float = 4.0 - maxf(0.0, world.scenario_time - float(event.get("time", world.scenario_time)))
	if remaining <= 0.0:
		return
	var path: PackedVector3Array = world.find_navigation_path(ceo.global_position, destination)
	if path.is_empty():
		return
	candidate = {"result": result, "event": event.duplicate(true), "destination": destination,
		"expires": _clock + remaining, "progress_at": _clock, "distance": ceo.global_position.distance_to(destination), "start": ceo.global_position}
	ceo.move_to(destination)
	if result == "A":
		_say("A-pending", "그 서류는… 내가 볼게.", 60)
	elif result == "B":
		_say("B-pending", "내 자리까지 치우면 어디서 결재해!", 60)

func _confirm() -> void:
	var result: String = candidate["result"]
	var event: Dictionary = candidate["event"]
	if result not in ["A", "B"] and ceo.global_position.distance_to(candidate["start"]) < 0.35:
		_cancel_candidate()
		return
	_cancel_candidate()
	world.record_scenario_fact(event, "npc_reaction", ceo)
	if result in ["A", "B"]:
		status = "resolved"
		outcome = result
		ceo.settle(CLEANUP if result == "A" else AUTHORITY, false)
		world.record_scenario_fact(event, "route_resolved", ceo, {"route_id": "office_ceo", "outcome": result})
		_say("O-36" + result, "내가 직접 정리할 테니까 다들 일단 퇴근해." if result == "A" else "사장실은 오늘부로… 임시 재택이야!", 65)
		world.react_to_route_result(result, ceo)
	else:
		attitude = "collapsed" if result == "supported_reversal" else "conciliatory"
		ceo.settle(world.player_target.global_position, false)
		world.record_scenario_fact(event, "route_intervention", ceo, {"route_id": "office_ceo", "transition": result})
		_say("O-35" if result == "supported_reversal" else "O-32", "내보내랬지, 일을 크게 만들랬어?" if result == "supported_reversal" else "우리 직원이지? 그건 내려놔. 말은 내가 낮출게.")

func _physics_process(delta: float) -> void:
	if not is_instance_valid(world.player_target) or world.events.frozen:
		return
	_clock += delta
	if not _living():
		_cancel_candidate()
		if is_instance_valid(ceo):
			world.cancel_scenario_speaker(ceo)
		if status != "resolved":
			status = "failed"
		return
	var nearby: bool = in_area(world.player_target.global_position)
	if not nearby:
		if status == "active":
			status = "suspended"
		_cancel_candidate()
		world.cancel_scenario_speaker(ceo)
		return
	if status == "available":
		_say("O-30", "불만은 팀장에게. 성과는 나한테.", 20)
		return
	if status == "suspended":
		status = "active"
		_say("O-38", "아까 대화는 끝난 거 아니었어?", 35)
	if status != "active":
		return
	if not _carry.is_empty() and not bool(_carry["consumed"]):
		var item: Node3D = _carry["prop"]
		if is_instance_valid(item) and item.held and item.global_position.distance_to(_carry["origin"]) > 0.8:
			_carry["consumed"] = true
			var event: Dictionary = world.record_scenario_fact(_carry["event"], "prop_moved", item, {"action_kind": "carry", "time": world.scenario_time})
			on_action(event, item)
	if not candidate.is_empty():
		if candidate["result"] == "B" and not _command_unusable():
			_cancel_candidate()
			return
		var destination: Vector3 = candidate["destination"]
		var distance: float = Vector2(ceo.global_position.x, ceo.global_position.z).distance_to(Vector2(destination.x, destination.z))
		if distance < float(candidate["distance"]) - 0.08:
			candidate["distance"] = distance
			candidate["progress_at"] = _clock
		if _clock > float(candidate["expires"]) or _clock - float(candidate["progress_at"]) > 2.0 or ceo.scenario_destination != destination:
			_cancel_candidate()
		elif distance < 0.85:
			_confirm()
		return
	# Autonomous repositioning changes attitude, never creates a result receipt.
	for actor: Node3D in world.npcs:
		if actor != ceo and world._actor_living(actor) and actor.affiliation == "security" and actor.global_position.distance_to(SUPPORT) < 2.2:
			if not _support_seen:
				_support_seen = true
				attitude = "supported"
				ceo.commanding = true
				ceo.move_to(SUPPORT + Vector3(1.0, 0, -0.8))
				_say("O-34", "당장 내보내. 회사에서 본 적도 없어.")
	if not _escape_started and ceo.global_position.distance_to(world.player_target.global_position) > 3.8:
		_escape_started = true
		ceo.move_to(SUPPORT)
		_say("O-33a", "일단 회의실에서 기다려.", 50)
	elif _escape_started and ceo.global_position.distance_to(world.player_target.global_position) < 2.0 and attitude != "supported":
		ceo.settle(world.player_target.global_position, false)
		_say("O-33b", "오늘 야근은 없어! 일은 내가 정리할게.", 50)
