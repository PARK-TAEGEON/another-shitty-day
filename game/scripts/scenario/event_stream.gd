extends RefCounted
## Small single-player applied-event adapter. Money/heat retain their legacy owners.
var round_id: String = ""
var _serial: int = 0
var _action_serial: int = 0
var frozen: bool = false

func reset() -> void:
	round_id = str(Time.get_ticks_usec())
	_serial = 0
	_action_serial = 0
	frozen = false

func action(kind: String, target: Node3D, time: float) -> Dictionary:
	if frozen or not is_instance_valid(target):
		return {}
	_action_serial += 1
	return {"round_id": round_id, "root_action_id": "%s:a%d" % [round_id, _action_serial],
		"instigator_id": "player", "action_kind": kind, "target_id": str(target.get_instance_id()), "time": time}

func fact(origin: Dictionary, kind: String, target: Node3D = null, extra: Dictionary = {}) -> Dictionary:
	if frozen or origin.is_empty() or str(origin.get("round_id", "")) != round_id:
		return {}
	_serial += 1
	var event: Dictionary = origin.duplicate(true)
	event["event_id"] = "%s:e%d" % [round_id, _serial]
	event["fact"] = kind
	event["validated"] = true
	if is_instance_valid(target):
		event["target_id"] = str(target.get_instance_id())
	for key: String in extra:
		event[key] = extra[key]
	return event
