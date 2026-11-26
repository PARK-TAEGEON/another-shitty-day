extends SceneTree
## Run with --fixed-fps 60 and -- --kim-v2. Starts the actual office and lets
## its opening play. Only the second, chair-specific fixture positions actors.
const MAIN = preload("res://scenes/main.tscn")
const EXPECTED_MODEL := "res://assets/rig_slice/boss_kim_game.glb"
const OPENING := ["왜 그래?", "뭐야 무슨 소리야?", "이게 무슨 짓이지?"]
var failures: Array[String] = []
var observations := {}
var game: Node3D
var boss: CharacterBody3D
var rig: Node3D
var skel: Skeleton3D
var mesh_node: MeshInstance3D
var lines: Array[String] = []
var hits: Array[String] = []
var binding_samples := 0
var max_binding_error := 0.0
var max_binding_angle := 0.0
var capture_settled_skin := false

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message):
		failures.append(message)
		push_error(message)

func step(frames: int) -> void:
	for i in frames:
		await physics_frame

func identify() -> bool:
	var failures_before := failures.size()
	boss = game.world.opening_boss
	rig = boss._rig_adapter
	if not is_instance_valid(rig):
		check(false, "The office boss has no rig adapter")
		return false
	skel = rig.skeleton
	var model: Node = skel
	while model != rig and model.scene_file_path.is_empty():
		model = model.get_parent()
	observations["model"] = model.scene_file_path
	var found := model.scene_file_path == EXPECTED_MODEL and skel.get_bone_count() == 50
	check(found, "Expected the 50-bone office v2 instance, got %s (%d)" % [model.scene_file_path, skel.get_bone_count()])
	if not found:
		return false
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 1, "Expected one skinned body mesh")
	if meshes.size() != 1:
		return false
	mesh_node = meshes[0] as MeshInstance3D
	check(mesh_node.skin != null and mesh_node.get_node(mesh_node.skeleton) == skel, "Visible mesh does not use Kim's simulated skeleton")
	check(mesh_node.is_visible_in_tree() and not boss._visual.visible, "Duplicate or hidden character")
	check(rig.bodies.size() == 15, "Expected 15 physical bones")
	for body: PhysicalBone3D in rig.bodies:
		check(body.get_bone_id() == skel.find_bone(body.bone_name) and body.get_bone_id() >= 0, "Unbound physics body: " + str(body.bone_name))
		body.record_contacts = true
	for clip: String in ["Idle", "Walk", "Idle_Talking", "Hit_Head", "Hit_Chest", "Joint_review"]:
		check(rig.animation.has_animation(clip), "Missing model clip: " + clip)
	return failures.size() == failures_before

func on_dialogue(_speaker: String, line: String, _duration: float, source: Node3D) -> void:
	var expected: Node3D = game.world.opening_coworker if lines.is_empty() else boss
	check(source == expected, "Wrong opening speaker for " + line)
	lines.append(line)

func aim_at_kim() -> void:
	var player: CharacterBody3D = game.player
	var direction: Vector3 = boss.global_position + Vector3.UP * 1.25 - player.camera.global_position
	player.rotation.y = atan2(-direction.x, -direction.z)
	player._pitch = atan2(direction.y, Vector2(direction.x, direction.z).length())
	player.camera.rotation = Vector3(player._pitch, 0, 0)

# Evaluate every vertex with the exported Skin's bind poses and weights. This
# measures the rendered skeleton, including modifiers, without a GPU readback.
func skin_bounds(sample: String = "") -> AABB:
	var skin := mesh_node.skin
	var transforms: Array[Transform3D] = []
	for bind in skin.get_bind_count():
		var bone := skel.find_bone(skin.get_bind_name(bind))
		if bone < 0:
			bone = skin.get_bind_bone(bind)
		check(bone >= 0, "Invalid skin bind")
		if bone < 0:
			return AABB()
		transforms.append(skel.global_transform * skel.get_bone_global_pose(bone) * skin.get_bind_pose(bind))
	var bounds := AABB()
	var first := true
	var peak_gain := 0.0
	var severe_edges := 0
	var largest_midpoint := Vector3.ZERO
	var material := ""
	for surface in mesh_node.mesh.get_surface_count():
		var arrays := mesh_node.mesh.surface_get_arrays(surface)
		var rest: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var stride := ids.size() / rest.size()
		var posed_vertices := PackedVector3Array()
		if not sample.is_empty():
			posed_vertices.resize(rest.size())
		for vertex in rest.size():
			var posed := Vector3.ZERO
			for j in stride:
				var index := vertex * stride + j
				if weights[index] > 0.0:
					posed += (transforms[ids[index]] * rest[vertex]) * weights[index]
			if not sample.is_empty():
				posed_vertices[vertex] = posed
			check(posed.is_finite(), "Non-finite skinned vertex")
			if first:
				bounds = AABB(posed, Vector3.ZERO)
				first = false
			else:
				bounds = bounds.expand(posed)
		if sample.is_empty():
			continue
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for t in range(0, indices.size(), 3):
			for edge in 3:
				var a := indices[t + edge]
				var b := indices[t + ((edge + 1) % 3)]
				var original := rest[a].distance_to(rest[b])
				if original <= 0.001:
					continue
				var actual := posed_vertices[a].distance_to(posed_vertices[b])
				if actual - original > peak_gain:
					peak_gain = actual - original
					largest_midpoint = (rest[a] + rest[b]) * 0.5
					material = mesh_node.mesh.surface_get_material(surface).resource_name
				if actual > 2.0 * original and actual - original > 0.01:
					severe_edges += 1
	if not sample.is_empty():
		observations.get_or_add("mesh_samples", {})[sample] = {
			"largest_edge_growth_m": peak_gain, "rest_midpoint_m": [largest_midpoint.x, largest_midpoint.y, largest_midpoint.z], "material": material, "triangle_edge_occurrences_doubled_and_grew_over_1cm": severe_edges}
	return bounds

func on_modified() -> void:
	# Godot restores the pre-modifier animation pose after applying it for skinning.
	# Reading on the next physics tick would measure the cached animation instead.
	if not rig.ragdoll_active or not rig.bodies[0].is_simulating_physics():
		return
	for body: PhysicalBone3D in rig.bodies:
		var posed: Transform3D = skel.global_transform * skel.get_bone_global_pose(body.get_bone_id()) * body.body_offset
		max_binding_error = maxf(max_binding_error, posed.origin.distance_to(body.global_position))
		var rotation_error := posed.basis.orthonormalized().get_rotation_quaternion().angle_to(body.global_basis.orthonormalized().get_rotation_quaternion())
		max_binding_angle = maxf(max_binding_angle, rotation_error)
	binding_samples += 1
	if capture_settled_skin:
		capture_settled_skin = false
		var bounds := skin_bounds("settled")
		observations["settled_skin_min_y_m"] = bounds.position.y
		observations["settled_skin_height_m"] = bounds.size.y
		var pelvis: Vector3 = rig.pelvis_position()
		check(bounds.grow(0.04).has_point(pelvis), "Rendered body no longer contains the physical pelvis")
		check(bounds.position.y > -0.15 and bounds.size.y < 1.25, "Settled skin buried below the floor or still upright")

func opening_and_hits() -> void:
	game.world.scene_dialogue.connect(on_dialogue)
	game.player.contact_started.connect(func(kind: String, target: Node):
		if target == boss:
			hits.append(kind)
	)
	rig.simulator.modification_processed.connect(on_modified)
	await step(60)
	var start := boss.global_position
	var seated_bounds := skin_bounds("seated")
	var hidden_top := seated_bounds.end.y
	var walk_lowest := INF
	var peek_top := -INF
	var peak_recorded := false
	var walk_start := Quaternion.IDENTITY
	var walk_delta := 0.0
	var talk_start := Quaternion.IDENTITY
	var head_start := Quaternion.IDENTITY
	var head_delta := 0.0
	var talk_delta := 0.0
	var clip_frames := {}
	var leg := skel.find_bone("UpperLeg.L")
	var arm := skel.find_bone("Forearm.L")
	var head := skel.find_bone("Head")
	game.player.perform_action("slam")
	for i in 1600:
		await physics_frame
		var clip: String = rig.animation.current_animation
		var frames: int = clip_frames.get(clip, 0)
		clip_frames[clip] = frames + 1
		if boss.opening_phase == "peek" and i % 12 == 0:
			peek_top = maxf(peek_top, skin_bounds().end.y)
			if peek_top > 2.0 and not peak_recorded:
				skin_bounds("peek")
				peak_recorded = true
		if clip == "Walk":
			if frames == 24:
				skin_bounds("walk")
			if frames % 24 == 0:
				walk_lowest = minf(walk_lowest, skin_bounds().position.y)
			if frames == 0:
				walk_start = skel.get_bone_pose_rotation(leg)
			walk_delta = maxf(walk_delta, walk_start.angle_to(skel.get_bone_pose_rotation(leg)))
		if clip == "Idle_Talking" and boss.boss_lecture_gesture != "":
			if frames == 28:
				skin_bounds("lecture")
			if frames == 0:
				talk_start = skel.get_bone_pose_rotation(arm)
				head_start = skel.get_bone_pose_rotation(head)
			head_delta = maxf(head_delta, head_start.angle_to(skel.get_bone_pose_rotation(head)))
			talk_delta = maxf(talk_delta, talk_start.angle_to(skel.get_bone_pose_rotation(arm)))
		if game.world.boss_lecture_finished:
			break
	check(lines.size() == 6 and lines.slice(0, 3) == OPENING, "Opening or lecture dialogue missing")
	var travel := boss.global_position.distance_to(start)
	check(travel > 1.5 and walk_delta > 0.10, "No measurable walk on the new skeleton")
	check(talk_delta > 0.10 and head_delta > 0.02, "Lecture did not move the new forearm and head")
	check(seated_bounds.position.y > -0.05 and walk_lowest > -0.05, "Seated or walking shoes buried more than 3 cm below the floor")
	check(hidden_top < 1.56 and peek_top > 1.70, "New head missed the original 1.54 m divider beat")
	for clip: String in ["Idle", "Walk", "Idle_Talking"]:
		check(clip_frames.get(clip, 0) > 5, "Opening did not sustain " + clip)
	observations.merge({"dialogue": lines, "opening_clip_frames": clip_frames, "approach_displacement_m": travel,
		"seated_top_m": hidden_top, "seated_min_y_m": seated_bounds.position.y, "walking_min_y_m": walk_lowest, "peek_top_m": peek_top, "walk_leg_angle_rad": walk_delta, "lecture_forearm_angle_rad": talk_delta, "lecture_head_angle_rad": head_delta})
	aim_at_kim()
	game.player.perform_action("punch")
	await step(8)
	skin_bounds("punch")
	check(boss.health == 20.0 and rig.reaction == "Light" and str(rig.animation.current_animation) in ["Hit_Head", "Hit_Chest"], "Production punch did not stagger Kim using a hit clip")
	Input.action_press("move_forward")
	await step(19)
	Input.action_release("move_forward")
	await step(16)
	aim_at_kim()
	game.player.perform_action("kick")
	await step(320)
	check(hits == ["punch", "kick"] and boss.state == "down" and rig.ragdoll_active, "Production ray contacts or knockout failed")
	capture_settled_skin = true
	await step(3)
	check(binding_samples > 60 and max_binding_error < 0.02 and max_binding_angle < 0.01 and not capture_settled_skin, "Physics and rendered skeleton diverged")
	observations.merge({"contacts": hits, "knockdown_hp": boss.health, "binding_frames": binding_samples,
		"max_body_to_posed_bone_error_m": max_binding_error, "max_body_to_posed_bone_error_rad": max_binding_angle, "resting_pelvis_y_m": rig.pelvis_position().y})

func restart_and_chair() -> void:
	var old_model := skel.get_instance_id()
	var old_boss := boss.get_instance_id()
	game._restart()
	for i in 5:
		await process_frame
	game = current_scene
	game._automated_run = true
	game._resume()
	check(not is_instance_id_valid(old_boss) and not is_instance_id_valid(old_model), "Reload retained the old boss or skeleton")
	if not identify():
		return
	check(not rig.ragdoll_active and game.score == 0 and get_nodes_in_group("office_npc").size() == 8, "Reload carried down state or ledger into the next run")
	var chair: RigidBody3D
	for prop: Node3D in game.world.props:
		if prop.get("display_name") == "내 의자":
			chair = prop as RigidBody3D
	check(chair != null, "Original player's office chair missing")
	if chair == null:
		return
	await step(30)
	var start := chair.global_position
	# An isolated, repeatable second run. Leave the production chair in place
	# and line up the two actors; its collision, mass, and the attack stay live.
	boss._cancel_opening()
	boss.global_position = start + Vector3(0, 0.04, -0.68)
	game.player.global_position = boss.global_position + Vector3(0, 0, -1.2)
	await step(3)
	aim_at_kim()
	game.player.perform_action("kick")
	await step(320)
	var touches: Array[String] = []
	for bone: PhysicalBone3D in rig.bodies:
		if bone.contact_ids.has(chair.get_instance_id()):
			touches.append(str(bone.bone_name))
	var travel := start.distance_to(chair.global_position)
	observations.merge({"contacted_chair": chair.display_name, "chair_contact_bones": touches, "chair_travel_m": travel})
	check(rig.ragdoll_active and not touches.is_empty(), "No real bone/chair contact after the second kick")

func run() -> void:
	game = MAIN.instantiate()
	root.add_child(game)
	current_scene = game
	game._automated_run = true
	game._resume()
	if identify():
		await opening_and_hits()
		await restart_and_chair()
	observations["failures"] = failures
	print("KIM_SUBMISSION_RESULT ", JSON.stringify(observations))
	Input.action_release("move_forward")
	game.sound.stop_all()
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
