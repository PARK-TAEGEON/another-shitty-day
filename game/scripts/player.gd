extends CharacterBody3D
## First-person controller and deliberately authored four-action viewmodel.
const HandModel = preload("res://scripts/hand_model.gd")
const HitFeelScript = preload("res://scripts/hit_feel.gd")
const HitPresenterScript = preload("res://scripts/hit_presenter.gd")
const HitTuneScript = preload("res://scripts/hit_tune_panel.gd")
const MOTION_FPS: float = 30.0
const SLAM_PHASES: Dictionary = {
	"A": {"lift": 6, "down": 3, "hold": 2, "recover": 9},
	"B": {"lift": 8, "down": 3, "hold": 4, "recover": 13}
}
const HAND_VIEW_SCALE: float = 1.2
const CAMERA_HEIGHT: float = 1.62
const START_PITCH: float = -0.12
const START_Z: float = 0.65
const DESK_SURFACE_Y: float = 1.061

signal action_performed(kind: String, at: Vector3)
signal activity_started(kind: String)
signal focus_changed(text: String)
signal desk_requested(origin: Vector3)
signal contact_started(kind: String, target: Node3D)
signal contact_finished(kind: String, target: Node3D)

var camera: Camera3D
var enabled: bool = false
var activity_serial: int = 0
var sensitivity: float = 0.0024
var shake_scale: float = 0.55
var held_prop: RigidBody3D
var actor_hold: Node
var office_world: Node3D
var _rig_study := "--rig-slice" in OS.get_cmdline_user_args()
var _release_hand := 0.0
var _hands: Node3D
var _left: Node3D
var _right: Node3D
var _foot: Node3D
var _left_home: Vector3 = Vector3(-0.28, -0.3, -0.48)
var _right_home: Vector3 = Vector3(0.28, -0.3, -0.48)
var _pitch: float = START_PITCH
var _cooldown: float = 0.0
var _anim: float = 0.0
var _anim_duration: float = 0.38
var _anim_kind: String = ""
var _slam_confirmed: bool = false
var _slam_variant: String = "B"
var _slam_contact_time: float = 11.0 / MOTION_FPS
var _slam_pending: bool = false
var _action_serial: int = 0
var _contact_positions: Array[Vector3] = []
var _lift_positions: Array[Vector3] = []
var _contact_bases: Array[Basis] = []
var _rest_bases: Array[Basis] = []
var _lift_bases: Array[Basis] = []
var _study_to_view: Basis = Basis(Vector3.RIGHT, -START_PITCH)
var _shake: float = 0.0
var _bob: float = 0.0
var _last_focus: String = ""
var _security_push_velocity: Vector3 = Vector3.ZERO
var _hit_presenter: Node
var _hit_tune: Node

func _ready() -> void:
	_rig_study = _rig_study or bool(ProjectSettings.get_setting("asd/assets/player_arms_v2_enabled", false)) or get_tree().root.has_meta("rig_slice")
	_register_inputs()
	collision_layer = 8
	collision_mask = 7
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.29
	shape.height = 1.72
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.86
	add_child(collider)
	camera = Camera3D.new()
	camera.position.y = CAMERA_HEIGHT
	camera.fov = 77.0
	camera.near = 0.045
	camera.current = true
	add_child(camera)
	_hands = Node3D.new()
	camera.add_child(_hands)
	_left = _make_arm(-1)
	_right = _make_arm(1)
	print("ASD player arms loaded: ", "rigged_v2" if _rig_study else "legacy")
	_left_home = _contact_positions[0] + _study_to_view * Vector3(-0.055, 0.058, 0.240)
	_right_home = _contact_positions[1] + _study_to_view * Vector3(0.055, 0.058, 0.240)
	if _rig_study:
		_left_home = Vector3(-0.37, -0.35, -0.46)
		_right_home = Vector3(0.37, -0.35, -0.46)
	_foot = Node3D.new()
	_hands.add_child(_foot)
	_mesh(_foot, Vector3(0.17, 0.37, 0.19), Vector3(0, 0.17, 0.03), Color("264b50"))
	_mesh(_foot, Vector3(0.21, 0.14, 0.36), Vector3(0, 0.02, -0.08), Color("28333c"))
	_mesh(_foot, Vector3(0.215, 0.035, 0.36), Vector3(0, -0.06, -0.08), Color("ece0c7"))
	_foot.visible = false
	_update_viewmodel(0.0)
	add_to_group("player")
	_hit_presenter = HitPresenterScript.new()
	_hit_presenter.name = "HitPresenter"
	add_child(_hit_presenter)

func _hit_tune_enabled() -> bool:
	return OS.is_debug_build()

func _register_inputs() -> void:
	var keys: Dictionary = {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "sprint": KEY_SHIFT, "pickup": KEY_E, "kick": KEY_Q, "slam": KEY_F, "restart": KEY_R}
	if _hit_tune_enabled():
		keys["hit_tune"] = KEY_F8
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev: InputEventKey = InputEventKey.new()
			ev.physical_keycode = keys[action]
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("punch"):
		InputMap.add_action("punch")
		var ev: InputEventMouseButton = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("punch", ev)

func _make_arm(side: int) -> Node3D:
	# Exact v3 geometry: left thumb is local +X, right thumb is local -X.
	# The original outward sleeve bend and compact clenched fingers are retained.
	var arm: Node3D = preload("res://rig_slice/view_arm.gd").new() if _rig_study else HandModel.new()
	_hands.add_child(arm)
	arm.call("build", "left" if side < 0 else "right")
	arm.scale = Vector3.ONE * HAND_VIEW_SCALE
	for child: Node in arm.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var forward: Vector3 = Vector3(0, -0.18, -0.984).normalized()
	var local_x: Vector3 = Vector3(0, 0.984, -0.18).normalized() * -float(side)
	var source_basis: Basis = Basis(local_x, forward, local_x.cross(forward)).orthonormalized()
	_contact_bases.append(_study_to_view * source_basis)
	_rest_bases.append(_study_to_view * Basis(Vector3.RIGHT, -0.13) * source_basis)
	_lift_bases.append(_study_to_view * Basis(Vector3.UP, -float(side) * 0.08) * Basis(Vector3.RIGHT, 0.62) * Basis(Vector3.BACK, float(side) * 0.04) * source_basis)
	# Place the authored ulnar contact on the real desktop from the starting view.
	# Geometry is uniformly sized for the existing 77-degree game camera; no limb stretching.
	var min_y: float = INF
	var points: PackedVector3Array = arm.call("get_geometry_points")
	for point: Vector3 in points:
		min_y = minf(min_y, (source_basis * point).y * HAND_VIEW_SCALE)
	var relative_contact: Vector3 = Vector3(float(side) * 0.245, DESK_SURFACE_Y + 0.001 - min_y - CAMERA_HEIGHT, 0.04 - START_Z)
	if _rig_study:
		relative_contact.z += 0.055
	var contact: Vector3 = _study_to_view * relative_contact
	_contact_positions.append(contact)
	_lift_positions.append(contact + _study_to_view * Vector3(0, 0.225, 0.138))
	return arm

func _mesh(parent: Node3D, size: Vector3, at: Vector3, tint: Color) -> void:
	var visual: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	visual.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.88
	visual.material_override = mat
	visual.position = at
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)

func _unhandled_input(event: InputEvent) -> void:
	if _hit_tune_enabled() and InputMap.has_action("hit_tune") and event.is_action_pressed("hit_tune"):
		_toggle_hit_tune()
		return
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var requested_yaw: float = rotation.y - event.relative.x * sensitivity
		rotation.y = actor_hold.limit_yaw(requested_yaw) if is_instance_valid(actor_hold) and actor_hold.active else requested_yaw
		_pitch = clampf(_pitch - event.relative.y * sensitivity, -1.2, 1.15)
	if event.is_action_pressed("pickup"):
		_pickup_or_drop()
	elif event.is_action_pressed("punch"):
		perform_action("throw" if is_instance_valid(held_prop) else "punch")
	elif event.is_action_pressed("kick"):
		perform_action("kick")
	elif event.is_action_pressed("slam"):
		perform_action("slam")

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if enabled:
		var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var direction: Vector3 = transform.basis * Vector3(input.x, 0, input.y)
		var holding_actor: bool = is_instance_valid(actor_hold) and actor_hold.active
		var speed: float = 3.8 * actor_hold.movement_scale() if holding_actor else (5.8 if Input.is_action_pressed("sprint") else 3.8)
		velocity.x = move_toward(velocity.x, direction.x * speed + _security_push_velocity.x, delta * 25.0)
		velocity.z = move_toward(velocity.z, direction.z * speed + _security_push_velocity.z, delta * 25.0)
		_bob += Vector2(velocity.x, velocity.z).length() * delta * 2.2
	else:
		velocity.x = move_toward(velocity.x, 0, delta * 25.0)
		velocity.z = move_toward(velocity.z, 0, delta * 25.0)
	_security_push_velocity = _security_push_velocity.move_toward(Vector3.ZERO, delta * 5.2)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.1
	if is_instance_valid(actor_hold) and actor_hold.active:
		var limited: Vector3 = actor_hold.limit_motion(Vector3(velocity.x, 0, velocity.z) * delta)
		velocity.x = limited.x / maxf(delta, 0.001)
		velocity.z = limited.z / maxf(delta, 0.001)
	move_and_slide()
	if global_position.y < -5.0:
		global_position = Vector3(0, 0.1, START_Z)
		velocity = Vector3.ZERO
	_update_held(delta)
	_update_focus()

func is_idle_for_boss_lecture() -> bool:
	# Looking at the speaker is allowed. A held movement key still counts as
	# activity when the desk blocks the capsule or opposing keys cancel out.
	if not enabled or _cooldown > 0.0 or _anim > 0.0 or _slam_pending:
		return false
	for action: String in ["move_left", "move_right", "move_forward", "move_back"]:
		if Input.is_action_pressed(action):
			return false
	return Vector2(velocity.x, velocity.z).length() < 0.12

func _record_activity(kind: String) -> void:
	activity_serial += 1
	activity_started.emit(kind)

func _process(delta: float) -> void:
	_anim = maxf(0.0, _anim - delta)
	_shake = move_toward(_shake, 0.0, delta * 1.8)
	_update_viewmodel(delta)
	if _rig_study:
		var extension := clampf((_right_home.z - _right.position.z) / 0.30, 0.0, 1.0)
		_right.pose_sleeve(camera, 1.0, extension if _anim_kind != "slam" or _anim <= 0.0 else 0.0)
	# Emit only after the same rendered pose has reached CONTACT. A frame crossing
	# the contact threshold is held at contact once, even under a long frame.
	if _slam_pending and enabled and _anim_kind == "slam" and _anim_duration - _anim + 0.000001 >= _slam_contact_time:
		_slam_pending = false
		desk_requested.emit(global_position)

func _update_viewmodel(_delta: float) -> void:
	if not is_instance_valid(camera):
		return
	camera.rotation.x = _pitch
	camera.rotation.z = sin(Time.get_ticks_msec() * 0.063) * _shake * shake_scale * 0.025
	camera.position.y = CAMERA_HEIGHT + sin(_bob * 2) * 0.014 * shake_scale
	_left.position = _left_home
	_right.position = _right_home
	_left.quaternion = _rest_bases[0].get_rotation_quaternion()
	_right.quaternion = _rest_bases[1].get_rotation_quaternion()
	_left.call("set_grip", 0.55)
	_right.call("set_grip", 0.55)
	_foot.visible = false
	if is_instance_valid(actor_hold) and actor_hold.active:
		var grip: Node3D = _right if actor_hold.side > 0.0 else _left
		grip.position = Vector3(actor_hold.side * 0.35, -0.16, -0.55)
		grip.rotation = Vector3(-0.2, -actor_hold.side * 0.15, actor_hold.side * 0.25)
		grip.call("set_grip", 0.9)
		return
	if _rig_study and _release_hand > 0.0:
		_release_hand = maxf(0.0, _release_hand - _delta)
		_right.call("set_grip", lerpf(0.55, 0.0, minf(_release_hand * 8.0, 1.0)))
	if _rig_study and is_instance_valid(held_prop):
		var grip_target := held_prop.global_position
		if held_prop.get("kind") == "mug":
			grip_target = held_prop.to_global(Vector3(0.15305, 0.01334, -0.01783))
		var socket := Vector3(-0.003, 0.084, -0.041)
		_right.position = camera.to_local(grip_target) - _rest_bases[1] * socket * HAND_VIEW_SCALE
		_right.call("set_grip", 0.31)
	elif is_instance_valid(held_prop):
		_left.position += Vector3(-0.05, -0.05, -0.09)
		_right.position += Vector3(0.05, -0.05, -0.09)
	if _anim <= 0.0 and not _slam_pending:
		return
	if _anim_kind == "slam":
		var elapsed: float = _anim_duration - _anim
		if _slam_pending and elapsed + 0.000001 >= _slam_contact_time:
			elapsed = _slam_contact_time
		_pose_slam(elapsed)
		return
	var progress: float = 1.0 - _anim / _anim_duration
	var hit: float = sin(clampf(progress * 1.65, 0, 1) * PI)
	match _anim_kind:
		"punch":
			if _rig_study:
				var gather := sin(PI * clampf(progress / 0.17, 0.0, 1.0))
				# Reach full extension at the original hit window after winding up.
				if progress < 0.30:
					hit = smoothstep(0.12, 0.30, progress)
				_right.position += Vector3(0.014, -0.010, 0.052) * gather
			_right.position += Vector3(-0.13 * hit, 0.1 * hit, -0.42 * hit)
			_right.quaternion = (Basis(Vector3.RIGHT, -hit * 0.25) * _rest_bases[1]).get_rotation_quaternion()
			_right.call("set_grip", 1.0)
		"kick":
			_foot.visible = true
			_foot.position = Vector3(0.19, -0.9 + hit * 0.5, -0.42 - hit * 0.5)
			_foot.rotation.x = -0.6 * hit
			_left.position.x -= hit * 0.08
			_right.position.x += hit * 0.08
		"throw":
			_left.position.z -= hit * 0.2
			_right.position.z -= hit * 0.32

func _ease(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)

func _pose_slam(elapsed: float) -> void:
	# Continuous-time evaluation of the accepted v3 30 fps phase table and curves.
	var config: Dictionary = SLAM_PHASES[_slam_variant]
	var frame: float = elapsed * MOTION_FPS
	var lift_f: float = float(config["lift"])
	var down_f: float = float(config["down"])
	var hold_f: float = float(config["hold"])
	var recover_f: float = float(config["recover"])
	var hands: Array[Node3D] = [_left, _right]
	for index: int in range(2):
		var side: float = -1.0 if index == 0 else 1.0
		var rest: Vector3 = _left_home if index == 0 else _right_home
		if _rig_study and (frame <= 1.1 or (_slam_pending and frame >= lift_f + down_f - 0.0001)):
			_fit_study_contact(index)
		var contact: Vector3 = _contact_positions[index]
		var lifted: Vector3 = _lift_positions[index]
		var position_value: Vector3 = rest
		var rotation_value: Quaternion = _rest_bases[index].get_rotation_quaternion()
		var grip: float = 0.55
		if frame < lift_f:
			var amount: float = _ease(clampf(frame / lift_f, 0.0, 1.0))
			position_value = rest.lerp(lifted, amount)
			position_value += _study_to_view * Vector3(side * sin(amount * PI) * 0.014, 0, sin(amount * PI) * 0.021)
			rotation_value = rotation_value.slerp(_lift_bases[index].get_rotation_quaternion(), amount)
			grip = lerpf(0.55, 1.0, minf(amount * 2.0, 1.0))
		elif frame < lift_f + down_f:
			var amount: float = pow((frame - lift_f) / down_f, 1.65)
			position_value = lifted.lerp(contact, amount)
			rotation_value = _lift_bases[index].get_rotation_quaternion().slerp(_contact_bases[index].get_rotation_quaternion(), amount)
			grip = 1.0
		elif frame < lift_f + down_f + hold_f:
			position_value = contact
			rotation_value = _contact_bases[index].get_rotation_quaternion()
			grip = 1.0
		elif frame < lift_f + down_f + hold_f + recover_f:
			var amount: float = _ease((frame - lift_f - down_f - hold_f) / recover_f)
			position_value = contact.lerp(rest, amount)
			position_value += _study_to_view * Vector3(side * sin(amount * PI) * 0.014, sin(amount * PI) * 0.044, 0)
			rotation_value = _contact_bases[index].get_rotation_quaternion().slerp(_rest_bases[index].get_rotation_quaternion(), amount)
			grip = lerpf(1.0, 0.55, amount)
		hands[index].position = position_value
		hands[index].quaternion = rotation_value
		hands[index].call("set_grip", grip)

func _fit_study_contact(index: int) -> void:
	var surface_y := DESK_SURFACE_Y + 0.001
	if is_instance_valid(office_world):
		var desk: Vector3 = office_world.desk_position
		if global_position.distance_to(desk) > 2.15:
			return
	var arm := _left if index == 0 else _right
	var contact := _contact_positions[index]
	var world_basis: Basis = camera.global_basis * _contact_bases[index]
	var contact_vertex: Vector3 = arm.support_vertex(world_basis)
	var lowest := camera.to_global(contact).y + (world_basis * contact_vertex).y * HAND_VIEW_SCALE
	contact.y += (surface_y - lowest) / camera.global_basis.y.y
	_contact_positions[index] = contact
	_lift_positions[index] = contact + _study_to_view * Vector3(0, 0.225, 0.138)

func perform_action(kind: String) -> void:
	if _cooldown > 0.0 or not enabled or (is_instance_valid(actor_hold) and actor_hold.active):
		return
	_record_activity(kind)
	if kind == "slam" and is_instance_valid(held_prop):
		_drop(false)
	_action_serial += 1
	_slam_pending = false
	_anim_kind = kind
	_anim_duration = 0.38
	if kind == "slam":
		_slam_variant = "A" if _slam_confirmed else "B"
		var config: Dictionary = SLAM_PHASES[_slam_variant]
		_anim_duration = float(config["lift"] + config["down"] + config["hold"] + config["recover"]) / MOTION_FPS
		_slam_contact_time = float(config["lift"] + config["down"]) / MOTION_FPS
	_cooldown = _anim_duration if kind == "slam" else 0.4
	_anim = _anim_duration
	if kind == "throw":
		_drop(true)
		action_performed.emit("throw", camera.global_position)
	elif kind == "slam":
		_slam_pending = true
	else:
		_commit_hit_later(kind, _action_serial)

func confirm_desk_slam() -> void:
	# The world confirms the first valid desk impact, not merely a button attempt.
	_slam_confirmed = true

func _commit_hit_later(kind: String, serial: int) -> void:
	await get_tree().create_timer(0.11, false).timeout
	if not enabled or serial != _action_serial:
		return
	var range_m: float = 2.35 if kind == "kick" else 1.9
	var hit: Dictionary = _ray(range_m)
	var target: Node = hit.get("collider") as Node
	if target != null and target.has_method("receive_hit"):
		var feel: Resource = HitFeelScript.load_settings()
		var power: float = feel.kick_power if kind == "kick" else feel.punch_power
		var lift: float = feel.kick_lift if kind == "kick" else feel.punch_lift
		var impulse: Vector3 = -camera.global_basis.z * power + Vector3.UP * lift
		contact_started.emit(kind, target)
		target.receive_hit(impulse, hit["position"], 28.0 if kind == "kick" else 20.0, kind)
		contact_finished.emit(kind, target)
		var launched: bool = str(target.get("state")) == "down"
		add_shake(feel.shake_launch if launched else feel.shake_punch)
		if is_instance_valid(_hit_presenter) and _hit_presenter.has_method("play"):
			_hit_presenter.play(kind)
		action_performed.emit("impact", hit["position"])
	else:
		action_performed.emit("swing", camera.global_position)

func _toggle_hit_tune() -> void:
	if not _hit_tune_enabled():
		return
	if is_instance_valid(_hit_tune):
		_hit_tune.queue_free()
		_hit_tune = null
		return
	_hit_tune = HitTuneScript.new()
	_hit_tune.name = "HitTune"
	add_child(_hit_tune)

func _ray(distance: float) -> Dictionary:
	var start: Vector3 = camera.global_position
	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, start - camera.global_basis.z * distance, 7)
	params.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(params)

func _pickup_or_drop() -> void:
	if not enabled or get_tree().paused:
		return
	_record_activity("interact")
	if is_instance_valid(actor_hold) and actor_hold.active:
		actor_hold.release("input")
		return
	if is_instance_valid(held_prop):
		_drop(false)
		return
	var result: Dictionary = _ray(2.7)
	if is_instance_valid(office_world) and office_world.try_use_elevator(self, result.get("collider")):
		return
	var actor: CharacterBody3D = result.get("collider") as CharacterBody3D
	if actor != null and actor.has_method("set_grabbed"):
		if is_instance_valid(actor_hold):
			actor_hold.try_grab(actor)
		return
	var body: RigidBody3D = result.get("collider") as RigidBody3D
	if body != null and body.has_method("set_held"):
		contact_started.emit("pickup", body)
		held_prop = body
		held_prop.set_held(true)
		contact_finished.emit("pickup", body)
		action_performed.emit("pickup", body.global_position)

func _update_held(delta: float) -> void:
	if not is_instance_valid(held_prop):
		return
	var carry_anchor := Vector3(0.13, -0.14, -1.15)
	var desired: Vector3 = camera.to_global(carry_anchor)
	desired = _keep_prop_in_front_of_walls(held_prop, camera.global_position, desired)
	desired = held_prop.global_position.lerp(desired, minf(delta * 18.0, 1.0))
	# Sweep the item's real collision shape so carrying it cannot cross a wall.
	var shape_node: CollisionShape3D = _prop_collision(held_prop)
	if shape_node != null:
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = shape_node.shape
		query.transform = shape_node.global_transform
		query.collision_mask = 1
		query.exclude = [get_rid(), held_prop.get_rid()]
		query.margin = 0.01
		query.motion = desired - held_prop.global_position
		var fractions: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(query)
		if fractions.size() == 2:
			desired = held_prop.global_position + query.motion * maxf(fractions[0] - 0.01, 0.0)
	held_prop.global_position = desired
	var target_basis: Basis = Basis(Vector3.UP, rotation.y)
	var next_basis: Basis = held_prop.global_basis.slerp(target_basis, minf(delta * 12.0, 1.0)).orthonormalized()
	if shape_node != null:
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = shape_node.shape
		query.transform = Transform3D(next_basis, desired) * shape_node.transform
		query.collision_mask = 1
		query.margin = 0.015
		query.exclude = [get_rid(), held_prop.get_rid()]
		if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return
	held_prop.global_basis = next_basis

func _keep_prop_in_front_of_walls(item: RigidBody3D, origin: Vector3, desired: Vector3) -> Vector3:
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, desired, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return desired
	var normal: Vector3 = hit["normal"]
	var shape_node: CollisionShape3D = _prop_collision(item)
	var radius: float = 0.2
	var center_offset: Vector3 = Vector3.ZERO
	if shape_node != null and shape_node.shape is BoxShape3D:
		var half: Vector3 = (shape_node.shape as BoxShape3D).size * 0.5
		var axes: Basis = item.global_basis * shape_node.basis
		radius = absf(normal.dot(axes.x)) * half.x + absf(normal.dot(axes.y)) * half.y + absf(normal.dot(axes.z)) * half.z
		center_offset = item.global_basis * shape_node.position
	return (hit["position"] as Vector3) + normal * (radius + 0.035) - center_offset

func _prop_collision(item: RigidBody3D) -> CollisionShape3D:
	for child: Node in item.get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
	return null

func _drop(throw_item: bool) -> void:
	if not is_instance_valid(held_prop):
		held_prop = null
		return
	if _rig_study:
		_release_hand = 0.28
	var item: RigidBody3D = held_prop
	contact_started.emit("throw" if throw_item else "drop", item)
	held_prop = null
	item.set_held(false)
	# Release at the last collision-checked position; never teleport through scenery.
	item.continuous_cd = true
	if throw_item:
		item.linear_velocity = -camera.global_basis.z * 10.5 + Vector3.UP * 1.5
		item.angular_velocity = Vector3(3, 1, -2)
		if item.has_method("mark_player_throw"):
			item.call("mark_player_throw")
	else:
		item.linear_velocity = -camera.global_basis.z * 0.5
	contact_finished.emit("throw" if throw_item else "drop", item)

func _update_focus() -> void:
	var text: String = ""
	if is_instance_valid(actor_hold) and actor_hold.active:
		pass # Existing focus hint is reused only for a Free target.
	elif is_instance_valid(held_prop):
		text = str(held_prop.get("display_name"))
	elif enabled:
		var hit: Dictionary = _ray(2.7)
		var body: Node = hit.get("collider") as Node
		if body != null and body.has_method("set_grabbed"):
			text = "%s  ·  E 붙잡기" % body.get("display_name")
		elif body != null and body.has_method("set_held"):
			text = "%s  ·  E 집기" % body.get("display_name")
		elif is_instance_valid(office_world):
			text = office_world.elevator_hint(self, body)
	if text != _last_focus:
		_last_focus = text
		focus_changed.emit(text)

func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func receive_security_push(direction: Vector3, strength: float = 2.4) -> void:
	if not enabled:
		return
	if is_instance_valid(actor_hold):
		actor_hold.release("player_hit")
	var horizontal: Vector3 = Vector3(direction.x, 0, direction.z)
	if horizontal.length_squared() < 0.001:
		return
	_security_push_velocity = horizontal.normalized() * clampf(strength, 0.0, 3.5)
	add_shake(0.30)

func place_at(at: Vector3, yaw: float, pitch: float) -> void:
	_cancel_action()
	velocity = Vector3.ZERO
	_shake = 0.0
	_bob = 0.0
	_pitch = pitch
	global_position = at
	rotation.y = yaw
	_update_viewmodel(0.0)
	reset_physics_interpolation()

func reset_position(at: Vector3) -> void:
	release_held()
	_slam_confirmed = false
	place_at(at, 0.0, START_PITCH)

func _cancel_action() -> void:
	_security_push_velocity = Vector3.ZERO
	_action_serial += 1
	_slam_pending = false
	_anim = 0.0
	_cooldown = 0.0
	_anim_kind = ""

func set_active(active: bool) -> void:
	enabled = active
	if not active:
		# Pausing or ending a run must not release an old delayed attack on resume.
		_cancel_action()
		_update_viewmodel(0.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if active else Input.MOUSE_MODE_VISIBLE

func release_held() -> void:
	_drop(false)
