extends Node3D
## Visual and physical ownership only. World/NPC retain dialogue and accounting.
const MODEL = preload("res://assets/characters/boss_kim/boss_kim.glb")
const PHYSICAL_BONE = preload("res://scripts/characters/kim_physical_bone.gd")
const MEDIUM_IMPULSE: float = 8.5
const HEAVY_IMPULSE: float = 11.5
var actor: CharacterBody3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var simulator: PhysicalBoneSimulator3D
var bodies: Array[PhysicalBone3D] = []
var ragdoll_active: bool = false
var reaction: String = ""
var reaction_time: float = 0.0
var reaction_duration: float = 0.0
var reaction_direction: Vector3
var clip: String = "Idle"
var animation_time: float = 0.0
var pose_updates: int = 0
var physics_impulses: int = 0
var takeover_error: float = 0.0
var _pending_impulses: Array[Dictionary] = []
var _starting: bool = false
var contact_sound_count: int = 0
var _contact_cooldown: float = 0.0
var _impact_audio: AudioStreamPlayer3D
const SOFT_IMPACT = preload("res://assets/audio/kenney/impactSoft_heavy_000.ogg")
const WOOD_IMPACT = preload("res://assets/audio/kenney/impactWood_medium_000.ogg")
const HitFeelScript = preload("res://scripts/hit_feel.gd")
var launching: bool = false
var _boost_done: bool = false
var _boost_armed: bool = false
var _boost_wait: float = 0.0
var _boost_impulse: Vector3 = Vector3.ZERO
var _flight_active: bool = false
var _flight_elapsed: float = 0.0
var _flight_duration: float = 0.70
var _flight_distance: float = 4.5
var _flight_peak: float = 1.45
var _flight_origin: Vector3 = Vector3.ZERO
var _flight_dir: Vector3 = Vector3.FORWARD
var _flight_offsets: Array[Vector3] = []
var _clamp_flight_to_room: bool = false
var _joints_relaxed: bool = false
var _joint_rest: Dictionary = {}

func _ready() -> void:
	var model: Node3D = MODEL.instantiate()
	add_child(model)
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# Imported legacy auto-simulator is empty. Use one explicit simulator.
	skeleton.animate_physical_bones = false
	for node: Node in skeleton.get_children():
		if node is PhysicalBoneSimulator3D:
			node.free()
	simulator = PhysicalBoneSimulator3D.new()
	simulator.name = "KimRagdoll"
	skeleton.add_child(simulator)
	_build_physics()
	for name: String in ["Idle", "Walk", "Idle_Talking"]:
		animation.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	animation.play("Idle")
	animation.advance(0.0)
	_impact_audio = AudioStreamPlayer3D.new()
	_impact_audio.max_distance = 16.0
	_impact_audio.max_polyphony = 1
	add_child(_impact_audio)

func _physics_process(delta: float) -> void:
	_contact_cooldown = maxf(_contact_cooldown - delta, 0.0)
	if not ragdoll_active:
		return
	if _boost_armed:
		_boost_wait = maxf(_boost_wait - delta, 0.0)
		if _boost_wait <= 0.0:
			_boost_armed = false
			_begin_scripted_flight(_boost_impulse)
	if _flight_active:
		_advance_scripted_flight(delta)
		return
	elif _joints_relaxed and not bodies.is_empty() and bodies[0].linear_velocity.length() < 0.8:
		_set_joints_relaxed(false)
	var limit: float = HitFeelScript.load_settings().max_body_speed
	for body: PhysicalBone3D in bodies:
		var velocity: Vector3 = body.linear_velocity
		if velocity.length() > limit:
			body.linear_velocity = velocity.limit_length(limit)

func _exit_tree() -> void:
	if is_instance_valid(_impact_audio):
		_impact_audio.stop()
		_impact_audio.stream = null

func contact_sound(at: Vector3, speed: float, furniture: bool) -> void:
	if _contact_cooldown > 0.0 or not ragdoll_active:
		return
	_contact_cooldown = .22
	contact_sound_count += 1
	# Headless checks validate the contact event, not an audio device. Running
	# hundreds of simulated seconds faster than the mixer queues stale playbacks.
	if DisplayServer.get_name() == "headless":
		return
	_impact_audio.global_position = at
	_impact_audio.stream = WOOD_IMPACT if furniture else SOFT_IMPACT
	if speed >= 3.0:
		_impact_audio.volume_db = clampf(-5.0 + speed * 0.45, -6.0, -0.5)
	else:
		_impact_audio.volume_db = clampf(-17.0 + speed * 1.4, -15.0, -8.0)
	_impact_audio.play()

func notify_impact(speed: float) -> void:
	var feel: Resource = HitFeelScript.load_settings()
	if speed < feel.impact_speed:
		return
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty() or not players[0].has_method("add_shake"):
		return
	players[0].add_shake(feel.shake_impact)

func _body(bone_name: String, length: float, radius: float, mass_value: float, swing: float, twist: float, box: Vector3 = Vector3.ZERO) -> void:
	var body: PhysicalBone3D = PHYSICAL_BONE.new()
	body.name = "Physical_" + bone_name.replace(".", "_")
	body.actor = actor
	simulator.add_child(body)
	body.bone_name = bone_name
	body.mass = mass_value
	body.friction = 0.8
	body.bounce = 0.03
	body.linear_damp = 0.25
	body.angular_damp = 1.8
	body.collision_layer = 0
	body.collision_mask = 0
	body.body_offset = Transform3D(Basis.IDENTITY, Vector3(0, length * .5, 0))
	body.joint_offset = Transform3D(Basis.IDENTITY, Vector3(0, -length * .5, 0))
	if bone_name != "Pelvis":
		body.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
		body.set("joint_constraints/swing_span", swing)
		body.set("joint_constraints/twist_span", twist)
	var shape := CollisionShape3D.new()
	if box != Vector3.ZERO:
		var box_shape := BoxShape3D.new()
		box_shape.size = box
		shape.shape = box_shape
	else:
		var capsule := CapsuleShape3D.new()
		capsule.radius = radius
		capsule.height = maxf(length, radius * 2.0)
		shape.shape = capsule
	body.add_child(shape)
	# Every limb can report the landing thud. Bounce stays on the torso only.
	PhysicsServer3D.body_set_max_contacts_reported(body.get_rid(), 4)
	bodies.append(body)

func _build_physics() -> void:
	_body("Pelvis", .16, .20, 14, 0, 0, Vector3(.54,.24,.39))
	_body("Chest", .22, .2, 22, 22, 18, Vector3(.68,.38,.39))
	_body("Head", .28, .235, 7, 32, 35)
	for side: String in ["L", "R"]:
		_body("UpperArm."+side, .34, .10, 3.8, 65, 45)
		_body("Forearm."+side, .27, .08, 2.5, 55, 12)
		_body("Hand."+side, .13, .068, 1.0, 25, 20)
		_body("UpperLeg."+side, .37, .125, 7.0, 45, 25)
		_body("LowerLeg."+side, .32, .095, 4.0, 35, 8)
		_body("Foot."+side, .20, .08, 1.5, 20, 10)

func severity(impulse: Vector3) -> String:
	if impulse.length() >= HEAVY_IMPULSE:
		return "Heavy"
	return "Medium" if impulse.length() >= MEDIUM_IMPULSE else "Light"

func should_knock_down(impulse: Vector3) -> bool:
	# A/B comparison changes only Kim's early physical takeover, never damage.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--kim-health-only" in args:
		return false
	var enabled: bool = bool(ProjectSettings.get_setting("asd/characters/kim_heavy_knockdown", true)) or "--kim-one-kick" in args
	return enabled and severity(impulse) == "Heavy"

func react_to_hit(impulse: Vector3, point: Vector3) -> void:
	reaction = severity(impulse)
	# In the health-only comparison a surviving heavy impact uses the existing
	# recoverable stagger. At zero health the caller still hands off to physics.
	if reaction == "Heavy":
		reaction = "Medium"
	reaction_duration = 1.05 if reaction == "Medium" else .42
	reaction_time = reaction_duration
	reaction_direction = actor.global_basis.inverse() * impulse.normalized()
	clip = "Hit_Head" if actor.to_local(point).y > 1.65 else "Hit_Chest"
	animation.play(clip)
	animation.advance(0.0)

func _apply_world_rotation(name_value: String, rotation_value: Basis, neutral: Basis) -> void:
	var index: int = skeleton.find_bone(name_value)
	var parent: int = skeleton.get_bone_parent(index)
	var parent_basis: Basis = skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	var local_basis: Basis = parent_basis.inverse() * rotation_value * neutral
	skeleton.set_bone_pose_rotation(index, local_basis.get_rotation_quaternion())

func _neutral_limb(name_value: String) -> Basis:
	var rest: Basis = skeleton.get_bone_global_rest(skeleton.find_bone(name_value)).basis
	# Swing each A-pose segment to the authored vertical-limb neutral, retain roll.
	return Basis(Quaternion(rest.y.normalized(), Vector3.DOWN)) * rest

func update_pose(delta: float) -> void:
	if ragdoll_active or not is_instance_valid(actor):
		return
	pose_updates += 1
	transform = actor._visual.transform
	# glTF removes immutable tracks. Clear the previous procedural pose first so
	# cancelled seated/head/finger overrides cannot leak into a different clip.
	skeleton.reset_bone_poses()
	reaction_time = maxf(reaction_time - delta, 0.0)
	var requested: String = "Walk" if actor._walk_blend > .05 else ("Idle_Talking" if actor._talk_time > 0.0 else "Idle")
	if reaction_time <= 0.0 and clip != requested:
		clip = requested
		animation.play(clip, .15)
	animation.advance(delta)
	animation_time += delta
	# Reuse the accepted control rig's actual post-collision gait, peek height,
	# head tracking and three lecture gestures. UAL supplies idle/talking motion.
	var authored: bool = actor.opening_role == "boss" and not actor.opening_cancelled
	if authored or actor._walk_blend > .05:
		var torso: Basis = actor._upper_body.basis
		_apply_world_rotation("Spine", torso, skeleton.get_bone_global_rest(skeleton.find_bone("Spine")).basis)
		_apply_world_rotation("Chest", torso, skeleton.get_bone_global_rest(skeleton.find_bone("Chest")).basis)
		_apply_world_rotation("Head", torso * actor._head.basis, skeleton.get_bone_global_rest(skeleton.find_bone("Head")).basis)
		# Bone translation is local to the parent, unlike control-node coordinates.
		var head_index: int = skeleton.find_bone("Head")
		skeleton.set_bone_pose_position(head_index, skeleton.get_bone_rest(head_index).origin + Vector3(0, actor._head_drop, 0))
		for side: String in ["L", "R"]:
			# Legacy names are screen-space; new rig uses anatomical left/right.
			var arm: Node3D = actor._right_arm if side == "L" else actor._left_arm
			var elbow: Node3D = actor._right_elbow if side == "L" else actor._left_elbow
			var leg: Node3D = actor._right_leg if side == "L" else actor._left_leg
			var knee: Node3D = actor._right_knee if side == "L" else actor._left_knee
			var ankle: Node3D = actor._right_ankle if side == "L" else actor._left_ankle
			_apply_world_rotation("UpperArm."+side, torso * arm.basis, _neutral_limb("UpperArm."+side))
			_apply_world_rotation("Forearm."+side, torso * arm.basis * elbow.basis, _neutral_limb("Forearm."+side))
			var hand_index: int = 1 if side == "L" else 0
			var wrist: Basis = actor._lecture_wrists[hand_index].basis if actor._lecture_blend > .01 else Basis.IDENTITY
			_apply_world_rotation("Hand."+side, torso * arm.basis * elbow.basis * wrist, _neutral_limb("Hand."+side))
			for finger in range(4):
				var finger_bone: int = skeleton.find_bone("Finger%d.%s" % [finger,side])
				var curl: float = actor._lecture_fingers[hand_index*4+finger].rotation.x if actor._lecture_blend > .01 else .30
				skeleton.set_bone_pose_rotation(finger_bone,skeleton.get_bone_rest(finger_bone).basis.get_rotation_quaternion()*Quaternion(Vector3.RIGHT,curl))
			_apply_world_rotation("UpperLeg."+side, leg.basis, skeleton.get_bone_global_rest(skeleton.find_bone("UpperLeg."+side)).basis)
			_apply_world_rotation("LowerLeg."+side, leg.basis * knee.basis, skeleton.get_bone_global_rest(skeleton.find_bone("LowerLeg."+side)).basis)
			_apply_world_rotation("Foot."+side, leg.basis * knee.basis * ankle.basis, skeleton.get_bone_global_rest(skeleton.find_bone("Foot."+side)).basis)
	var jaw: int = skeleton.find_bone("Jaw")
	skeleton.set_bone_pose_rotation(jaw, skeleton.get_bone_rest(jaw).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, actor._mouth_open * .19))
	for side: String in ["L","R"]:
		var brow: int = skeleton.find_bone("Brow."+side)
		skeleton.set_bone_pose_position(brow,skeleton.get_bone_rest(brow).origin+Vector3(0,(actor._eye_open-.48)*.045,0))
	if reaction_time > 0.0:
		var pulse: float = sin((1.0 - reaction_time / reaction_duration) * PI) * (.34 if reaction == "Medium" else .14)
		for name_value: String in ["Chest", "Head"]:
			var index: int = skeleton.find_bone(name_value)
			var turn := Quaternion(Vector3.RIGHT, reaction_direction.z * pulse) * Quaternion(Vector3.FORWARD, reaction_direction.x * pulse)
			skeleton.set_bone_pose_rotation(index, skeleton.get_bone_pose_rotation(index) * turn)
		if reaction == "Medium":
			position += reaction_direction * sin((1.0-reaction_time/reaction_duration)*PI) * .06

func start_ragdoll(impulse: Vector3, point: Vector3) -> void:
	if ragdoll_active:
		apply_hit(impulse, point)
		return
	ragdoll_active = true
	_starting = true
	animation.pause()
	# Freeze the current rendered pose before relinquishing the root capsule.
	actor.velocity = Vector3.ZERO
	actor.collision_layer = 0
	actor.collision_mask = 0
	actor._collision.set_deferred("disabled", true)
	_pending_impulses.append({"impulse":impulse,"point":point})
	call_deferred("_activate_physics")

func _activate_physics() -> void:
	for body: PhysicalBone3D in bodies:
		body.collision_layer = 4 # existing attack rays include NPCs
		body.collision_mask = 11 # room, props, player; no self/NPC body pairs
		body.global_transform = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(body.bone_name)) * body.body_offset
	simulator.physical_bones_add_collision_exception(actor.get_rid())
	var before: Vector3 = bodies[0].global_position
	simulator.physical_bones_start_simulation()
	takeover_error = before.distance_to(bodies[0].global_position)
	_starting = false
	for pending: Dictionary in _pending_impulses:
		apply_hit(pending.impulse, pending.point)
	_pending_impulses.clear()

func apply_hit(impulse: Vector3, point: Vector3) -> void:
	if _starting:
		_pending_impulses.append({"impulse":impulse,"point":point})
		return
	var nearest: PhysicalBone3D = bodies[0]
	for body: PhysicalBone3D in bodies:
		if body.global_position.distance_squared_to(point) < nearest.global_position.distance_squared_to(point):
			nearest = body
	# Same directional vector, mass-calibrated; clamp repeated impulses and lever arm.
	var force: Vector3 = impulse.limit_length(22.0) * 2.5
	nearest.apply_impulse(force, (point - nearest.global_position).limit_length(.25))
	physics_impulses += 1
	if launching and not _boost_done:
		_boost_done = true
		launching = false
		_boost_impulse = impulse
		# Stay real for kim_rig's two-frame pose check and the table's first contact.
		_boost_wait = maxf(HitFeelScript.load_settings().boost_delay, 0.08)
		_boost_armed = true

func _begin_scripted_flight(impulse: Vector3) -> void:
	if bodies.is_empty():
		return
	var feel: Resource = HitFeelScript.load_settings()
	var horizontal: Vector3 = Vector3(impulse.x, 0.0, impulse.z)
	if horizontal.length_squared() < 0.0001:
		horizontal = Vector3(impulse.x, 0.0, 1.0)
	_flight_dir = horizontal.normalized()
	_flight_origin = bodies[0].global_position
	_clamp_flight_to_room = _started_inside_room(_flight_origin)
	_flight_duration = maxf(feel.flight_time, 0.2)
	_flight_peak = feel.flight_peak
	_flight_distance = _clear_flight(_flight_origin, _flight_dir, feel.flight_distance)
	_flight_elapsed = 0.0
	_flight_offsets.clear()
	for body: PhysicalBone3D in bodies:
		_flight_offsets.append(body.global_position - _flight_origin)
		body.collision_layer = 0
		body.collision_mask = 0
		body.set("scripted", true)
	_flight_active = true
	_advance_scripted_flight(0.0)

func _advance_scripted_flight(delta: float) -> void:
	_flight_elapsed += delta
	var u: float = clampf(_flight_elapsed / _flight_duration, 0.0, 1.0)
	var desired: Vector3 = _flight_pose_pelvis(u)
	var motion: Vector3 = desired - bodies[0].global_position
	var blocked: Dictionary = _sweep_flight(bodies[0].global_position, motion)
	if blocked.is_empty():
		blocked = _pose_hits_solid(desired, u)
	if blocked.is_empty():
		blocked = _planned_burial(desired, u)
	if not blocked.is_empty():
		var stop: Vector3 = bodies[0].global_position
		if blocked.has("fraction"):
			stop = bodies[0].global_position + motion * float(blocked.fraction)
		stop += (blocked.normal as Vector3) * 0.1
		_place_flight_pose(_above_floor(stop), u)
		_crash_flight(blocked.normal, bool(blocked.furniture))
		return
	_place_flight_pose(_above_floor(desired), u)
	if u >= 1.0:
		_release_scripted_flight(false)

func _flight_pose_pelvis(u: float) -> Vector3:
	var height: float = 4.0 * _flight_peak * u * (1.0 - u)
	return _flight_origin + _flight_dir * (_flight_distance * u) + Vector3.UP * height

func _place_flight_pose(pelvis_target: Vector3, u: float) -> void:
	pelvis_target += _room_shift(_flight_pose_points(pelvis_target, u))
	var axis: Vector3 = Vector3.UP.cross(_flight_dir)
	if axis.length_squared() < 0.0001:
		axis = Vector3.RIGHT
	var pitched: Basis = Basis(axis.normalized(), lerpf(0.0, -1.05, smoothstep(0.1, 0.55, u)))
	for index in range(bodies.size()):
		var body: PhysicalBone3D = bodies[index]
		body.set("scripted", true)
		body.set("scripted_position", pelvis_target + pitched * _flight_offsets[index])
		body.linear_velocity = Vector3.ZERO

func _flight_pose_points(pelvis_target: Vector3, u: float) -> Array[Vector3]:
	var axis: Vector3 = Vector3.UP.cross(_flight_dir)
	if axis.length_squared() < 0.0001:
		axis = Vector3.RIGHT
	var pitched: Basis = Basis(axis.normalized(), lerpf(0.0, -1.05, smoothstep(0.1, 0.55, u)))
	var points: Array[Vector3] = [pelvis_target]
	for offset: Vector3 in _flight_offsets:
		points.append(pelvis_target + pitched * offset)
	return points

func _pose_hits_solid(pelvis_target: Vector3, u: float) -> Dictionary:
	if not is_instance_valid(actor) or bodies.is_empty():
		return {}
	var axis: Vector3 = Vector3.UP.cross(_flight_dir)
	if axis.length_squared() < 0.0001:
		axis = Vector3.RIGHT
	var pitched: Basis = Basis(axis.normalized(), lerpf(0.0, -1.05, smoothstep(0.1, 0.55, u)))
	var samples: Array[Vector3] = [pelvis_target]
	for offset: Vector3 in _flight_offsets:
		samples.append(pelvis_target + pitched * offset)
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	var exclude: Array[RID] = [actor.get_rid()]
	for body: PhysicalBone3D in bodies:
		exclude.append(body.get_rid())
	var origin: Vector3 = bodies[0].global_position
	for point: Vector3 in samples:
		var end: Vector3 = point + _flight_dir * 0.34
		var ray := PhysicsRayQueryParameters3D.create(origin, end, 3)
		ray.exclude = exclude
		ray.hit_from_inside = true
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit.normal
		if normal.y > 0.72:
			continue
		var furniture: bool = false
		var collider: Object = hit.collider
		if collider is CollisionObject3D and (collider.collision_layer & 2) != 0:
			furniture = true
		return {"fraction": 0.0, "normal": normal, "furniture": furniture}
	return {}

func _above_floor(pelvis_target: Vector3) -> Vector3:
	var lowest: float = pelvis_target.y
	for offset: Vector3 in _flight_offsets:
		lowest = minf(lowest, (pelvis_target + offset).y)
	if lowest < 0.06:
		pelvis_target.y += 0.06 - lowest
	return pelvis_target

func _sweep_flight(from: Vector3, motion: Vector3) -> Dictionary:
	if motion.length_squared() < 0.000001 or not is_instance_valid(actor):
		return {}
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.38
	var exclude: Array[RID] = []
	for body: PhysicalBone3D in bodies:
		exclude.append(body.get_rid())
	exclude.append(actor.get_rid())
	var closest: float = 1.0
	var origin: Vector3 = from
	for drop: float in [0.0, 0.5]:
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.transform = Transform3D(Basis.IDENTITY, from + Vector3.DOWN * drop)
		params.motion = motion
		params.collision_mask = 3
		params.exclude = exclude
		var fractions: PackedFloat32Array = space.cast_motion(params)
		if fractions.size() > 0 and fractions[0] < closest:
			closest = fractions[0]
			origin = params.transform.origin
	if closest >= 0.995:
		return {}
	var probe_from: Vector3 = origin + motion * maxf(closest - 0.2, 0.0)
	var probe_to: Vector3 = probe_from + motion.normalized() * 0.5
	var ray := PhysicsRayQueryParameters3D.create(probe_from, probe_to, 3)
	ray.exclude = exclude
	var hit: Dictionary = space.intersect_ray(ray)
	var normal: Vector3 = -motion.normalized()
	var furniture: bool = false
	if not hit.is_empty():
		normal = hit.normal
		var collider: Object = hit.collider
		if collider is CollisionObject3D and (collider.collision_layer & 2) != 0:
			furniture = true
	# A floor under a body that is still rising is not the crash. A face is.
	if normal.y > 0.72 and motion.y >= -0.05:
		return {}
	return {"fraction": maxf(closest - 0.05, 0.0), "normal": normal, "furniture": furniture}

func _crash_flight(normal: Vector3, furniture: bool) -> void:
	_flight_active = false
	_separate_from_solids(normal)
	var slide: Vector3 = Vector3.DOWN * 2.2 + normal * 0.45
	slide = slide.limit_length(6.0)
	for body: PhysicalBone3D in bodies:
		body.set("scripted", false)
		body.collision_layer = 4
		body.collision_mask = 11
		body.linear_velocity = slide
	_set_joints_relaxed(true)
	_impact_feedback(furniture)

func _release_scripted_flight(crashed: bool) -> void:
	if crashed:
		return
	_flight_active = false
	_separate_from_solids(_flight_dir)
	var smack: Vector3 = (_flight_dir * HitFeelScript.load_settings().launch_speed + Vector3.DOWN * 2.2).limit_length(6.0)
	for body: PhysicalBone3D in bodies:
		body.set("scripted", false)
		body.collision_layer = 4
		body.collision_mask = 11
		body.linear_velocity = smack
	_set_joints_relaxed(true)

func _separate_from_solids(preferred: Vector3) -> void:
	if not is_instance_valid(actor) or bodies.is_empty():
		return
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	var exclude: Array[RID] = []
	for body: PhysicalBone3D in bodies:
		exclude.append(body.get_rid())
	exclude.append(actor.get_rid())
	for _attempt in range(14):
		if not _push_buried_bone(space, shape, exclude, preferred):
			break
	_pull_bones_inside_room()
	var lifted: Vector3 = _above_floor(bodies[0].global_position)
	_shift_bones(lifted - bodies[0].global_position)
	_pull_bones_inside_room()

func _push_buried_bone(space: PhysicsDirectSpaceState3D, shape: SphereShape3D, exclude: Array[RID], preferred: Vector3) -> bool:
	for body: PhysicalBone3D in bodies:
		var probe: Dictionary = _bone_probe(body)
		shape.radius = float(probe.radius)
		for point: Vector3 in probe.points:
			var params := PhysicsShapeQueryParameters3D.new()
			params.shape = shape
			params.transform = Transform3D(Basis.IDENTITY, point)
			params.collision_mask = 3
			params.exclude = exclude
			if not space.intersect_shape(params, 1).is_empty():
				var info: Dictionary = space.get_rest_info(params)
				var away: Vector3 = preferred if info.is_empty() else info.normal
				if away.length_squared() < 0.0001:
					away = -_flight_dir
				# A floor holds the body up. The underside of a desktop is not a floor:
				# come back out through the face we flew into.
				if away.y <= 0.72:
					if away.y < -0.72:
						away = Vector3(-_flight_dir.x, 0.0, -_flight_dir.z)
					if away.length_squared() < 0.0001:
						away = Vector3.BACK
					_shift_bones(away.normalized() * 0.1)
					return true
			if body.bone_name == "Head" or body.bone_name == "Chest":
				var under: Vector3 = _underside_exit(space, point, exclude, 1)
				if under.length_squared() > 0.0001:
					_shift_bones(under * 0.1)
					return true
	return false

func _bone_probe(body: PhysicalBone3D) -> Dictionary:
	var radius := 0.16
	var points: Array[Vector3] = [body.global_position]
	if body.get_child_count() == 0 or not (body.get_child(0) is CollisionShape3D):
		return {"radius": radius, "points": points}
	var shape: Shape3D = (body.get_child(0) as CollisionShape3D).shape
	if shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		radius = capsule.radius
		var reach: float = maxf(capsule.height * 0.5 - radius, 0.0)
		if reach > 0.01:
			var axis: Vector3 = body.global_transform.basis.y
			points.append(body.global_position + axis * reach)
			points.append(body.global_position - axis * reach)
	elif shape is BoxShape3D:
		var size: Vector3 = (shape as BoxShape3D).size
		var half := size * 0.5
		radius = 0.06
		var basis := body.global_transform.basis
		var origin: Vector3 = body.global_position
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					points.append(origin + basis * Vector3(half.x * sx, half.y * sy, half.z * sz))
	return {"radius": radius, "points": points}

func _started_inside_room(point: Vector3) -> bool:
	if not is_instance_valid(actor) or not actor.has_method("clamp_to_room"):
		return false
	return actor.clamp_to_room(point).distance_squared_to(point) < 0.0004

func _planned_burial(pelvis_target: Vector3, u: float) -> Dictionary:
	if not is_instance_valid(actor) or bodies.is_empty():
		return {}
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	var exclude: Array[RID] = [actor.get_rid()]
	for body: PhysicalBone3D in bodies:
		exclude.append(body.get_rid())
	var shape := SphereShape3D.new()
	shape.radius = 0.22
	# Only the bones leading the pelvis can stop the arc. A trailing hand under
	# a desk behind him must not cancel the flight on the first frame.
	for point: Vector3 in _flight_pose_points(pelvis_target, u):
		if (point - pelvis_target).dot(_flight_dir) < 0.05:
			continue
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.transform = Transform3D(Basis.IDENTITY, point)
		params.collision_mask = 1
		params.exclude = exclude
		if not space.intersect_shape(params, 1).is_empty():
			var info: Dictionary = space.get_rest_info(params)
			if info.is_empty() or (info.normal as Vector3).y > 0.72:
				continue
			var away: Vector3 = info.normal
			if away.y < -0.45:
				away = Vector3(-_flight_dir.x, 0.0, -_flight_dir.z)
			if away.length_squared() < 0.0001:
				continue
			var furniture := false
			var collider: Object = info.get("collider")
			if collider is CollisionObject3D and (collider.collision_layer & 2) != 0:
				furniture = true
			return {"fraction": 0.0, "normal": away.normalized(), "furniture": furniture}
		var under: Vector3 = _underside_exit(space, point, exclude, 1)
		if under.length_squared() > 0.0001:
			return {"fraction": 0.0, "normal": under, "furniture": true}
	return {}

func _underside_exit(space: PhysicsDirectSpaceState3D, point: Vector3, exclude: Array[RID], mask: int = 1) -> Vector3:
	var ray := PhysicsRayQueryParameters3D.create(point, point + Vector3.UP * 0.85, mask)
	ray.exclude = exclude
	ray.hit_from_inside = true
	var hit: Dictionary = space.intersect_ray(ray)
	if hit.is_empty() or (hit.normal as Vector3).y > -0.45:
		return Vector3.ZERO
	var out := Vector3(-_flight_dir.x, 0.0, -_flight_dir.z)
	if out.length_squared() < 0.0001:
		return Vector3.ZERO
	return out.normalized()

func _room_shift(points: Array[Vector3]) -> Vector3:
	if not _clamp_flight_to_room or not is_instance_valid(actor) or not actor.has_method("clamp_to_room"):
		return Vector3.ZERO
	var shift := Vector3.ZERO
	for _pass in range(3):
		var extra := Vector3.ZERO
		for point: Vector3 in points:
			var delta: Vector3 = actor.clamp_to_room(point + shift) - (point + shift)
			if absf(delta.x) > absf(extra.x):
				extra.x = delta.x
			if absf(delta.z) > absf(extra.z):
				extra.z = delta.z
		if extra.length_squared() < 0.000001:
			break
		shift += extra
	return shift

func _pull_bones_inside_room() -> void:
	var points: Array[Vector3] = []
	for body: PhysicalBone3D in bodies:
		points.append(body.global_position)
	var shift: Vector3 = _room_shift(points)
	if shift.length_squared() > 0.000001:
		_shift_bones(shift)

func _shift_bones(delta: Vector3) -> void:
	for body: PhysicalBone3D in bodies:
		var xf: Transform3D = body.global_transform
		xf.origin += delta
		PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
		body.global_transform = xf
		if bool(body.get("scripted")):
			body.set("scripted_position", xf.origin)

func _impact_feedback(furniture: bool) -> void:
	if bodies.is_empty():
		return
	contact_sound(bodies[0].global_position, 6.5, furniture)
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	if players[0].has_method("add_shake"):
		players[0].add_shake(HitFeelScript.load_settings().shake_impact)
	var presenter: Node = players[0].get_node_or_null("HitPresenter")
	if presenter != null and presenter.has_method("play"):
		presenter.play("crash")

func _clear_flight(origin: Vector3, direction: Vector3, wanted: float) -> float:
	if not is_instance_valid(actor):
		return wanted
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	var from: Vector3 = origin + Vector3.UP * 0.2
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + direction * wanted, 3)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return wanted
	# Body radius, not a 1.5m minimum. A wall 0.8m away must stop the arc.
	return maxf(origin.distance_to(hit.position) - 0.42, 0.05)

func _set_joints_relaxed(relaxed: bool) -> void:
	var scale: float = HitFeelScript.load_settings().fly_joint_scale if relaxed else 1.0
	for body: PhysicalBone3D in bodies:
		if body.bone_name == "Pelvis":
			continue
		if not _joint_rest.has(body.bone_name):
			_joint_rest[body.bone_name] = {
				"swing": float(body.get("joint_constraints/swing_span")),
				"twist": float(body.get("joint_constraints/twist_span")),
			}
		var rest: Dictionary = _joint_rest[body.bone_name]
		body.set("joint_constraints/swing_span", float(rest["swing"]) * scale)
		body.set("joint_constraints/twist_span", float(rest["twist"]) * scale)
	_joints_relaxed = relaxed

func pelvis_position() -> Vector3:
	return bodies[0].global_position
