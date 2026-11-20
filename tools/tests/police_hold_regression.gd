extends SceneTree
## Actual Player/CEO/Hold relation and native body/occluder physics on an open floor.
## Checks local police perception, standoff, accepted contact, release and guard parity.
## Headless establishes these contracts, not visual quality or comedy.
const PoliceScript: Script = preload("res://scripts/scenario/police_npc.gd")
const NpcScript: Script = preload("res://scripts/office_npc.gd")
const PlayerScript: Script = preload("res://scripts/player.gd")
const CeoScript: Script = preload("res://scripts/scenario/ceo_npc.gd")
const HoldScript: Script = preload("res://scripts/scenario/ceo_hold.gd")
const STEP: float = 1.0 / 60.0

class MalformedRelation extends Node:
	var active: Variant
	var holder: CharacterBody3D
	var target: CharacterBody3D

var stage: Node3D
var player: CharacterBody3D
var ceo: CharacterBody3D
var hold: Node
var failures: Array[String] = []
var observations: Dictionary = {}
var warnings: Array[Dictionary] = []
var witnesses: Array[int] = []
var hits: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("POLICE_HOLD_CHECK: " + message)

func _advance(seconds: float) -> void:
	for frame: int in range(ceili(seconds / STEP)):
		await physics_frame

func _fixture(grab: bool = true) -> bool:
	paused = false
	if is_instance_valid(stage):
		stage.queue_free()
		await process_frame
	warnings.clear()
	witnesses.clear()
	hits.clear()
	stage = Node3D.new()
	root.add_child(stage)
	_obstacle(Vector3(40.0, 0.2, 40.0), Vector3(0.0, -0.1, 0.0), 1)
	player = PlayerScript.new() as CharacterBody3D
	player.position = Vector3(0.0, 0.08, 0.0)
	stage.add_child(player)
	player.call("set_active", true)
	# Match main.gd's real component setup; relation flags are left Free.
	hold = HoldScript.new()
	hold.set("holder", player)
	hold.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.add_child(hold)
	player.set("actor_hold", hold)
	ceo = CeoScript.new() as CharacterBody3D
	ceo.set("display_name", "사장 · 경찰 회귀")
	ceo.set("role", "ceo")
	ceo.set("affiliation", "executive")
	ceo.set("health", 90.0)
	ceo.set("player_target", player)
	ceo.position = Vector3(0.0, 0.04, -0.95)
	stage.add_child(ceo)
	# Native floor contact and the existing NPC's initial action recovery settle.
	await _advance(1.6)
	hold = player.get("actor_hold") as Node
	check(is_instance_valid(hold), "player has no actual actor_hold component")
	if not is_instance_valid(hold):
		return false
	if not grab:
		player.set_physics_process(false)
		return true
	# Invoke the existing E implementation with a real capsule in the real ray.
	# No active/holder/target/grabbed_by flags are assigned by this fixture.
	player.call("_pickup_or_drop")
	await _advance(0.08)
	check(bool(hold.get("active")) and hold.get("holder") == player and hold.get("target") == ceo and ceo.get("grabbed_by") == player, "actual E pickup path did not establish a validated held CEO relation")
	if not bool(hold.get("active")):
		return false
	# Keep the holder still while NPC AI and the actual hold component remain live.
	player.set_physics_process(false)
	return true

func _obstacle(size: Vector3, at: Vector3, layer: int) -> PhysicsBody3D:
	var body: PhysicsBody3D
	if layer == 2:
		var prop: RigidBody3D = RigidBody3D.new()
		prop.freeze = true
		body = prop
	else:
		body = StaticBody3D.new()
	body.position = at
	body.collision_layer = layer
	body.collision_mask = 15
	var collider: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	collider.shape = box
	body.add_child(collider)
	stage.add_child(body)
	return body

func _officer(at: Vector3, is_guard: bool = false) -> CharacterBody3D:
	var actor: CharacterBody3D = (NpcScript if is_guard else PoliceScript).new() as CharacterBody3D
	actor.position = at
	actor.set("display_name", "기존 경비" if is_guard else "목격 경찰")
	actor.set("role", "guard" if is_guard else "police")
	actor.set("affiliation", "security")
	actor.set("player_target", player)
	actor.set("navigation_provider", func(_from: Vector3, destination: Vector3) -> PackedVector3Array: return PackedVector3Array([destination]))
	if not is_guard:
		actor.set("hold_provider", func() -> Node: return hold if is_instance_valid(hold) else null)
		actor.connect("hold_observed", func(_target: CharacterBody3D) -> void: witnesses.append(actor.get_instance_id()))
	actor.connect("said", func(text_value: String) -> void: warnings.append({"id": actor.get_instance_id(), "text": text_value}))
	actor.connect("player_hit", func(amount: float) -> void: hits.append({"id": actor.get_instance_id(), "damage": amount}))
	stage.add_child(actor)
	return actor

func _warning_count(actor: Node) -> int:
	var count: int = 0
	for item: Dictionary in warnings:
		if int(item["id"]) == actor.get_instance_id() and "사장님" in str(item["text"]):
			count += 1
	return count

func _hit_count(actor: Node) -> int:
	var count: int = 0
	for item: Dictionary in hits:
		if int(item["id"]) == actor.get_instance_id():
			count += 1
	return count

func _side() -> Vector3:
	var pair: Vector3 = ceo.global_position - player.global_position
	pair.y = 0.0
	return Vector3(-pair.z, 0.0, pair.x).normalized()

func _place_close(actor: CharacterBody3D) -> void:
	actor.global_position = player.global_position + Vector3(0.0, 0.0, 0.95)
	actor.velocity = Vector3.ZERO
	actor.set("_cooldown", 0.0)

func _per_officer_visibility() -> void:
	if not await _fixture():
		return
	var side: Vector3 = _side()
	var visible: CharacterBody3D = _officer(player.global_position - side * 4.2)
	var hidden: CharacterBody3D = _officer(player.global_position + side * 4.2)
	var wall_at: Vector3 = hidden.global_position.lerp(player.global_position, 0.55)
	wall_at.y = 1.5
	var wall: PhysicsBody3D = _obstacle(Vector3(0.6, 3.0, 0.6), wall_at, 1)
	await _advance(0.08)
	check(bool(visible.get("witnessed_hold")) and not bool(hidden.get("witnessed_hold")), "police shared a global hold witness or saw through a solid wall")
	check(_warning_count(visible) == 1 and _warning_count(hidden) == 0 and witnesses == [visible.get_instance_id()], "an unseeing police officer warned/reacted to Held")
	var before: bool = bool(visible.get("witnessed_hold"))
	(player.get("camera") as Camera3D).rotation = Vector3(0.9, 2.7, 0.4)
	await _advance(0.05)
	check(before and bool(visible.get("witnessed_hold")), "police witness depended on the player's camera")
	wall.queue_free()
	await _advance(0.08)
	check(bool(hidden.get("witnessed_hold")) and _warning_count(hidden) == 1, "police did not detect a newly clear local hold relation")
	observations["per_police_solid_camera_independence"] = true

func _both_bodies_and_prop_occlusion() -> void:
	if not await _fixture():
		return
	var actor: CharacterBody3D = _officer(player.global_position + _side() * 4.0)
	await _advance(0.05)
	check(bool(actor.get("witnessed_hold")), "unobstructed holder/CEO relation was not witnessed")
	# A small blocker on the owner ray leaves the differently angled CEO ray clear.
	var owner_at: Vector3 = actor.global_position.lerp(player.global_position, 0.6)
	owner_at.y = 1.5
	var owner_blocker: PhysicsBody3D = _obstacle(Vector3(0.18, 3.0, 0.18), owner_at, 1)
	await _advance(0.05)
	check(not bool(actor.call("_sees_body", player, 1.2)) and bool(actor.call("_sees_body", ceo, 1.35)), "owner-only occlusion fixture failed to separate the two body rays")
	check(not bool(actor.get("witnessed_hold")), "seeing only CEO incorrectly activated the modifier")
	owner_blocker.queue_free()
	await _advance(0.05)
	# A physical layer-2 prop near the CEO blocks its ray while the owner is visible.
	var target_at: Vector3 = actor.global_position.lerp(ceo.global_position, 0.88)
	target_at.y = 1.5
	var target_blocker: PhysicsBody3D = _obstacle(Vector3(0.18, 3.0, 0.18), target_at, 2)
	await _advance(0.05)
	check(bool(actor.call("_sees_body", player, 1.2)) and not bool(actor.call("_sees_body", ceo, 1.35)), "CEO-only prop occlusion fixture failed to separate body rays")
	check(not bool(actor.get("witnessed_hold")), "seeing only holder or seeing through a prop activated the modifier")
	target_blocker.queue_free()
	await _advance(0.05)
	check(bool(actor.get("witnessed_hold")) and _warning_count(actor) == 1, "reacquired sight repeated the once-per-police warning or failed to restore modifier")
	actor.global_position = player.global_position + _side() * 7.5
	actor.velocity = Vector3.ZERO
	await _advance(0.05)
	check(not bool(actor.get("witnessed_hold")), "out-of-range police observed the held relation")
	observations["both_bodies_props_range_and_once"] = true

func _standoff_and_release() -> void:
	if not await _fixture():
		return
	var actor: CharacterBody3D = _officer(player.global_position + Vector3(0.0, 0.0, 0.95))
	actor.set("_cooldown", 0.0)
	await _advance(0.1)
	check(bool(actor.get("witnessed_hold")) and not bool(actor.get("_guard_push_active")) and _hit_count(actor) == 0, "witness police started a new direct push")
	await _advance(1.1)
	var distance: float = Vector2(actor.global_position.x, actor.global_position.z).distance_to(Vector2(player.global_position.x, player.global_position.z))
	check(distance >= 2.45 and distance <= 3.6 and _hit_count(actor) == 0, "witness police failed to keep physical standoff distance")
	check(str(actor.get("state")) == "pursue", "temporary concern movement leaked into normal police state")
	hold.call("release", "police-test")
	_place_close(actor)
	await _advance(0.28)
	check(not bool(actor.get("witnessed_hold")) and _hit_count(actor) == 1, "release did not immediately restore normal police contact")
	observations["new_push_standoff_release"] = {"held_distance": distance, "resumed_hits": _hit_count(actor)}

func _accepted_windup_and_guard() -> void:
	if not await _fixture(false):
		return
	# Start a real original windup while the actual hold component is still free.
	var actor: CharacterBody3D = _officer(player.global_position + Vector3(0.0, 0.0, 0.95))
	actor.set("_cooldown", 0.0)
	await _advance(0.05)
	check(bool(actor.get("_guard_push_active")) and _hit_count(actor) == 0, "original police windup did not start before its accepted contact")
	# The production E implementation establishes Held during the pending push;
	# neither a windup flag nor a hold relation flag is written by the fixture.
	player.call("_pickup_or_drop")
	check(bool(hold.get("active")), "actual Held did not begin during pending police contact")
	await _advance(0.08)
	check(bool(actor.get("witnessed_hold")) and bool(actor.get("_guard_push_active")), "new witness erased a previously accepted windup")
	await _advance(0.20)
	check(_hit_count(actor) == 1 and bool(actor.get("_guard_push_contact")), "previously accepted police push did not reach its inherited contact")
	observations["accepted_windup_preserved"] = true
	if not await _fixture():
		return
	var guard: CharacterBody3D = _officer(player.global_position + Vector3(0.0, 0.0, 0.95), true)
	guard.set("_cooldown", 0.0)
	await _advance(0.28)
	check(_hit_count(guard) == 1, "held CEO incorrectly changed the existing guard's direct push")
	observations["guard_unchanged"] = true

func _invalid_relation_restores_police() -> void:
	if not await _fixture():
		return
	var actor: CharacterBody3D = _officer(player.global_position + _side() * 3.0)
	await _advance(0.05)
	check(bool(actor.get("witnessed_hold")), "valid relation fixture had no witness")
	actor.set("hold_provider", Callable())
	_place_close(actor)
	await _advance(0.28)
	check(not bool(actor.get("witnessed_hold")) and _hit_count(actor) == 1, "invalid provider left police hesitation or direct-contact suppression active")
	if not await _fixture():
		return
	actor = _officer(player.global_position + _side() * 3.0)
	await _advance(0.05)
	ceo.call("receive_hit", Vector3.ZERO, ceo.global_position + Vector3.UP, 200.0)
	await _advance(0.05)
	check(str(ceo.get("state")) == "down" and not bool(actor.get("witnessed_hold")), "incapacitated CEO retained a police witness modifier")
	ceo.queue_free()
	await _advance(0.05)
	check(not bool(actor.get("witnessed_hold")), "freed CEO retained police modifier")
	observations["invalid_provider_down_and_freed_target"] = true

func _invalid_provider_payloads() -> void:
	if not await _fixture():
		return
	var actor: CharacterBody3D = _officer(player.global_position + _side() * 3.0)
	await _advance(0.05)
	var missing_properties: Node = Node.new()
	stage.add_child(missing_properties)
	actor.set("hold_provider", func() -> Node: return missing_properties)
	await _advance(0.05)
	check(not bool(actor.get("witnessed_hold")), "a provider Node with absent relation properties activated the modifier")
	var malformed: MalformedRelation = MalformedRelation.new()
	malformed.active = "false"
	malformed.holder = player
	malformed.target = ceo
	stage.add_child(malformed)
	actor.set("hold_provider", func() -> Node: return malformed)
	await _advance(0.05)
	check(not bool(actor.get("witnessed_hold")), "a non-boolean active value was treated as a validated relation")
	var arbitrary_holder: CharacterBody3D = CharacterBody3D.new()
	stage.add_child(arbitrary_holder)
	malformed.active = true
	malformed.holder = arbitrary_holder
	actor.set("player_target", arbitrary_holder)
	await _advance(0.05)
	check(not bool(actor.get("witnessed_hold")), "an arbitrary body with no enabled property activated the modifier")
	observations["missing_relation_properties_boolean_and_holder_null_safety"] = true

func _run() -> void:
	await _per_officer_visibility()
	await _both_bodies_and_prop_occlusion()
	await _standoff_and_release()
	await _accepted_windup_and_guard()
	await _invalid_relation_restores_police()
	await _invalid_provider_payloads()
	if is_instance_valid(stage):
		stage.queue_free()
		await process_frame
	observations["failures"] = failures
	print(JSON.stringify(observations, "\t"))
	print("POLICE_HOLD_REGRESSION_OK" if failures.is_empty() else "POLICE_HOLD_REGRESSION_FAILED")
	quit(0 if failures.is_empty() else 1)
