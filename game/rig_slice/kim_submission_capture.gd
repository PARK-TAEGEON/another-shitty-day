extends SceneTree
## One uninterrupted replay in the production office. Run with --fixed-fps 30.
## The replay looks around through the player's normal yaw/pitch controls.
const MAIN = preload("res://scenes/main.tscn")
const MODEL := "res://assets/rig_slice/boss_kim_game.glb"
const CAPTURE_FPS := 30
const DOWN_REVIEW_FRAMES := 6 * CAPTURE_FPS
const EXPECTED_CLIPS := ["Idle", "Walk", "Idle_Talking"]
const OPENING_LINES := ["왜 그래?", "뭐야 무슨 소리야?", "이게 무슨 짓이지?"]

var player
var kim
var rig
var contacts: Array[String] = []
var post_hit_states: Array[String] = []
var lines: Array[String] = []
var gestures: Dictionary = {}
var clips: Dictionary = {}
var states: Dictionary = {}

func _initialize() -> void:
	call_deferred("_capture")

func _look_towards(target: Vector3, weight: float) -> void:
	var d: Vector3 = target - player.camera.global_position
	player.rotation.y = lerp_angle(player.rotation.y, atan2(-d.x, -d.z), weight)
	player._pitch = lerpf(player._pitch, atan2(d.y, Vector2(d.x, d.z).length()), weight)

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capturing the office requires a renderer.")
		quit(1)
		return
	change_scene_to_packed(MAIN)
	await scene_changed
	var game = current_scene
	var world = game.world
	player = game.player
	kim = world.opening_boss
	rig = kim._rig_adapter
	var model: Node3D
	if is_instance_valid(rig):
		for child: Node in rig.get_children():
			if child.scene_file_path == MODEL:
				model = child
	if model == null or rig.skeleton.get_bone_count() != 50 or not model.is_visible_in_tree():
		push_error("Office capture requires the visible 50-bone boss_kim_game.glb. Pass -- --kim-v2.")
		quit(1)
		return
	var punch_frame := -1
	var kick_frame := -1
	var down_frames := 0
	var sidestep_frames := 0
	game._automated_run = true
	game._resume()
	world.scene_dialogue.connect(func(_who, line, _duration, _source): lines.append(line))
	player.contact_finished.connect(func(kind, target):
		if target == kim:
			contacts.append(kind)
			post_hit_states.append(kim.state))
	for frame in range(34 * CAPTURE_FPS):
		if frame == CAPTURE_FPS:
			player.perform_action("slam")
		var t: float = world.opening_elapsed
		if world.opening_started:
			if t < 1.1:
				_look_towards(world.opening_coworker.global_position + Vector3.UP * 1.25, 0.14)
			elif kim.state == "down":
				_look_towards(rig.pelvis_position() + Vector3.UP * 0.12, 0.24)
			else:
				var level := 1.50 if punch_frame < 0 else 1.20
				_look_towards(kim.global_position + Vector3.UP * level, 0.18)
		if world.boss_lecture_finished and punch_frame < 0 and gestures.size() == 3:
			punch_frame = frame
			player.perform_action("punch")
		if (punch_frame >= 0 and frame >= punch_frame + CAPTURE_FPS and kick_frame < 0
			and player._ray(2.1).get("collider") == kim):
			kick_frame = frame
			player.perform_action("kick")
		var motion: String = rig.animation.current_animation
		if motion != "" and not clips.has(motion):
			clips[motion] = frame
		if kim.boss_lecture_gesture != "" and not gestures.has(kim.boss_lecture_gesture):
			gestures[kim.boss_lecture_gesture] = frame
		if not states.has(kim.opening_phase):
			states[kim.opening_phase] = frame
		if kim.state == "down" and rig.ragdoll_active:
			down_frames += 1
			# Walk in through the production CharacterBody controller after the fall.
			var ground_offset: Vector3 = rig.pelvis_position() - player.global_position
			var remaining := Vector2(ground_offset.x, ground_offset.z).length()
			if down_frames >= 55 and remaining > 2.55:
				Input.action_press("move_forward", 0.8)
			else:
				Input.action_release("move_forward")
			if down_frames > 85 and remaining <= 2.9 and sidestep_frames < 42:
				Input.action_press("move_right", 0.8)
				sidestep_frames += 1
			else:
				Input.action_release("move_right")
			if down_frames >= DOWN_REVIEW_FRAMES:
				break
		await process_frame

	Input.action_release("move_forward")
	Input.action_release("move_right")
	var valid: bool = (lines.slice(0, 3) == OPENING_LINES and gestures.size() == 3
		and clips.has_all(EXPECTED_CLIPS) and states.has_all(["peek", "approach"])
		and contacts == ["punch", "kick"] and post_hit_states[0] != "down"
		and post_hit_states[1] == "down" and down_frames >= DOWN_REVIEW_FRAMES)
	print("KIM_OFFICE_CAPTURE ", JSON.stringify({"model": model.scene_file_path,
		"bones": rig.skeleton.get_bone_count(), "clip_first_frame": clips,
		"phase_first_frame": states, "gesture_first_frame": gestures, "dialogue": lines,
		"punch_frame": punch_frame, "kick_frame": kick_frame, "kim_hit_by": contacts,
		"post_hit_states": post_hit_states, "ragdoll_frames": down_frames, "valid": valid}))
	game.sound.stop_all()
	quit(0 if valid else 1)
