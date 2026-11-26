extends "../office/replay.gd"
## Measure the actual imported mug and hand during the production office replay.

class WristProbe extends Node:
	var callback: Callable

	func _process(_delta: float) -> void:
		callback.call()

var previous_wrist := Quaternion.IDENTITY
var tracking := false
var max_turn_degrees := 0.0
var max_socket_error := 0.0
var settled_frames := 0

func run() -> void:
	var probe := WristProbe.new()
	probe.callback = _sample_wrist
	probe.process_priority = 100
	root.add_child(probe)
	await super.run()
	check(settled_frames > 8 and max_socket_error < 0.0001, "settled wrist socket follows mug")
	check(max_turn_degrees < 45.0, "wrist does not snap during pickup or release")
	print("INTEGRATION_GRIP ", JSON.stringify({
		"max_wrist_turn_degrees_per_30fps_frame": max_turn_degrees,
		"settled_frames": settled_frames,
		"max_settled_socket_error_m": max_socket_error,
		"failures": failures,
	}))
	quit(0 if failures.is_empty() else 1)

func _sample_wrist() -> void:
	if not is_instance_valid(player) or not is_instance_valid(mug) or not is_instance_valid(game):
		tracking = false
		return
	if game != current_scene or mug.damage_stage > 0:
		tracking = false
		return
	var wrist: Node3D = player._right
	if player.held_prop == mug or player._mug_reach_left > 0.0:
		if tracking:
			max_turn_degrees = maxf(max_turn_degrees, rad_to_deg(previous_wrist.angle_to(wrist.quaternion)))
	tracking = true
	previous_wrist = wrist.quaternion
	if player.held_prop == mug and player._mug_reach_left <= 0.00001:
		settled_frames += 1
		var target: Vector3 = mug.to_global(player.MUG_GRIP_TARGET)
		max_socket_error = maxf(max_socket_error, wrist.to_global(player.HAND_SOCKET).distance_to(target))

func aim(at: Vector3) -> void:
	if player.held_prop != mug:
		await super.aim(at)
		return
	# Keep the input continuous while holding the cup. The original replay
	# cuts to the throw angle in one frame for its camera framing.
	await frames(6)
	var direction: Vector3 = at - player.camera.global_position
	var yaw: float = player.rotation.y
	var pitch: float = player._pitch
	var target_yaw := atan2(-direction.x, -direction.z)
	var target_pitch := atan2(direction.y, Vector2(direction.x, direction.z).length())
	for i in range(1, 13):
		player.rotation.y = lerp_angle(yaw, target_yaw, i / 12.0)
		player._pitch = lerpf(pitch, target_pitch, i / 12.0)
		await frames(1)
	await frames(6)

func photo(label: String) -> void:
	await super.photo(label)
	if label != "held":
		return
	var sampled_vertices := []
	for point: Vector3 in player._right.sample_skin(true):
		var local: Vector3 = mug.to_local(player._right.to_global(point))
		sampled_vertices.append([local.x, -local.z, local.y])
	var file := FileAccess.open("/tmp/asd-office-hand.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(sampled_vertices))
	file.close()
