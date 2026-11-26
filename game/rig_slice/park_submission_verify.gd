extends SceneTree
## Starts the original packed office. Exercise Park's movement only after the
## unmodified opening releases him by making the existing close-threat call.
const MAIN := preload("res://scenes/main.tscn")
const PARK_PATH := "res://assets/rig_slice/park_office.glb"
const V2_SETTING := "asd/characters/park_visual_v2_enabled"
var game: Node3D
var park: CharacterBody3D
var model: Node3D
var errors: Array[String] = []
var result := {}
var dialogue: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok and not errors.has(message):
		errors.append(message)
		push_error(message)

func bind_actor(expected: bool) -> void:
	park = game.world.opening_coworker
	var adapter: Node = park.find_child("ParkVisualAdapter", true, false)
	model = adapter.get("loaded_model") as Node3D if adapter != null else null
	result["actual_model"] = model.scene_file_path if model != null else "procedural"
	check((model != null) == expected, "Selected Park model disagrees with requested mode")
	if model != null:
		check(model.scene_file_path == PARK_PATH, "Mounted GLB has unexpected scene_file_path")
	check(park._rig_adapter == null and park._collision.shape is CapsuleShape3D and not park._collision.disabled, "Character ownership or standing collider changed")
	var new_meshes := 0
	var old_meshes := 0
	for m: MeshInstance3D in park._visual.find_children("*", "MeshInstance3D", true, false):
		if not m.is_visible_in_tree():
			continue
		if model != null and model.is_ancestor_of(m):
			new_meshes += 1
		else:
			old_meshes += 1
	check((new_meshes > 0 and old_meshes == 0) if expected else (new_meshes == 0 and old_meshes > 0), "Missing or duplicate visible Park geometry")
	for npc: Node in get_nodes_in_group("office_npc"):
		if npc != park:
			check(npc.find_child("ParkVisualAdapter", true, false) == null, "Park adapter attached to another cast member")
	result["visible_meshes"] = {"imported": new_meshes, "procedural": old_meshes}

func node_for(label: String, legacy: Node3D) -> Node3D:
	var actual: Node3D = model.find_child(label, true, false) as Node3D if model != null else legacy
	check(actual != null, "Required pivot missing: " + label)
	return actual

func step(count: int) -> void:
	for i in count:
		await physics_frame

func sample_behavior() -> void:
	var head := node_for("ParkHead", park._head)
	var arm := node_for("ParkArmLeft", park._left_arm)
	var elbow := node_for("ParkElbowLeft", park._left_elbow)
	var leg := node_for("ParkThighLeft", park._left_leg)
	var eye := node_for("ParkEyeL", park._eyes[-1])
	var brow := node_for("ParkBrowL", park._brows[-1])
	var mouth := node_for("ParkMouth", park._mouth)
	if not errors.is_empty():
		return
	game.world.scene_dialogue.connect(func(_speaker: String, line: String, _duration: float, source: Node3D):
		if dialogue.is_empty():
			check(source == park, "Park opening line attributed to another NPC")
		dialogue.append(line)
	)
	await step(45)
	var work_angle := elbow.quaternion
	var work_delta := 0.0
	for i in 40:
		await physics_frame
		work_delta = maxf(work_delta, elbow.quaternion.angle_to(work_angle))
	check(park.opening_phase == "work" and work_delta > 0.015, "Park did not animate at his desk")
	var resting_head := head.quaternion
	var resting_arm := arm.quaternion
	var resting_brow_y := brow.position.y
	var max_brow_lift := 0.0
	var eye_y := eye.scale.y
	var mouth_y := mouth.scale.y
	var widest_eye := eye_y
	var widest_mouth := mouth_y
	var arm_delta := 0.0
	var head_delta := 0.0
	var startle_frames := 0
	var start := park.global_position
	game.player.perform_action("slam")
	for i in 600:
		await physics_frame
		if park.opening_phase == "startle":
			startle_frames += 1
			widest_eye = maxf(widest_eye, eye.scale.y)
			max_brow_lift = maxf(max_brow_lift, absf(brow.position.y - resting_brow_y))
			widest_mouth = maxf(widest_mouth, mouth.scale.y)
			arm_delta = maxf(arm_delta, resting_arm.angle_to(arm.quaternion))
			head_delta = maxf(head_delta, resting_head.angle_to(head.quaternion))
		if park.opening_phase == "released":
			break
	check(startle_frames > 30 and park.opening_phase == "released", "Full desk-slam startle or release missing")
	check(dialogue.slice(0, 3) == ["왜 그래?", "뭐야 무슨 소리야?", "이게 무슨 짓이지?"], "Original opening dialogue changed")
	check(max_brow_lift > 0.001, "Park eyebrow did not respond to the startle")
	check(widest_eye > eye_y * 1.3 and widest_mouth > mouth_y * 1.5, "Park eye/mouth did not open")
	check(arm_delta > 0.20 and head_delta > 0.08, "Startle failed to move Park's arm and head")
	var drift := start.distance_to(park.global_position)
	check(drift < 0.05, "Park left his authored position during the opening")
	# A close threat after release makes the existing AI choose its own flee target.
	var legs := leg.quaternion
	var leg_delta := 0.0
	var peak_speed := 0.0
	park.react(park.global_position, 2.0)
	for i in 150:
		await physics_frame
		leg_delta = maxf(leg_delta, legs.angle_to(leg.quaternion))
		peak_speed = maxf(peak_speed, park.velocity.length())
	var distance := start.distance_to(park.global_position)
	check(distance > 1.0 and peak_speed > 1.0 and leg_delta > 0.1 and park.state == "flee", "Released Park did not flee with visible animated legs")
	result.merge({"work_elbow_rad": work_delta, "startle_brow_lift_m": max_brow_lift, "eye_open_y_work_peak": [eye_y,widest_eye],
		"mouth_open_y_work_peak": [mouth_y,widest_mouth], "startle_arm_rad": arm_delta,
		"startle_head_rad": head_delta, "startle_frames": startle_frames, "opening_drift_m": drift,
		"opening_dialogue": dialogue.slice(0,3), "flee_distance_m":distance, "flee_leg_rad":leg_delta,
		"peak_flee_speed_mps":peak_speed})

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--test-park-setting" in args:
		ProjectSettings.set_setting(V2_SETTING, true)
	var expected := ("--park-v2" in args or bool(ProjectSettings.get_setting(V2_SETTING, false))) and not "--park-legacy" in args
	game = MAIN.instantiate()
	root.add_child(game)
	current_scene = game
	game._automated_run = true
	game._resume()
	bind_actor(expected)
	if errors.is_empty():
		await sample_behavior()
	var old_actor := park.get_instance_id()
	game._restart()
	for i in 5:
		await process_frame
	game = current_scene
	bind_actor(expected)
	check(not is_instance_id_valid(old_actor) and get_nodes_in_group("office_npc").size() == 8 and game.score == 0, "Restart retained the old Park or ledger")
	result["errors"] = errors
	print("PARK_SUBMISSION_RESULT ", JSON.stringify(result))
	game.sound.stop_all()
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if errors.is_empty() else 1)
