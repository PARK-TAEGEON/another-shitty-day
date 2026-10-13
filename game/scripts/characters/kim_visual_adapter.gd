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
	_contact_cooldown = maxf(_contact_cooldown-delta,0.0)

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
	_impact_audio.volume_db = clampf(-17.0+speed*1.4,-15.0,-8.0)
	_impact_audio.play()

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
	if bone_name in ["Pelvis","Chest","Head"]:
		PhysicsServer3D.body_set_max_contacts_reported(body.get_rid(),4)
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

func react_to_hit(impulse: Vector3, point: Vector3) -> void:
	reaction = severity(impulse)
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

func pelvis_position() -> Vector3:
	return bodies[0].global_position
