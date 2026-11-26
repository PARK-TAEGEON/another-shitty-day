extends Node3D
## GLB skin and grip sampler. Vertices are sampled in the instantiated wrist frame,
## using the imported inverse bind matrices, including the sleeve at the elbow.
var skeleton: Skeleton3D
var motion: AnimationPlayer
var clip: StringName
var meshes: Array[MeshInstance3D] = []
var closed_points := PackedVector3Array()
var last_grip := -2.0

func build(side: String) -> void:
	var asset: PackedScene = load("res://assets/rig_slice/player_" + side + ".glb")
	var model := asset.instantiate()
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	motion = model.find_children("*", "AnimationPlayer", true, false)[0]
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := n as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		meshes.append(mesh)
	for id in motion.get_animation_list():
		if id != &"RESET":
			clip = id
	motion.play(clip)
	motion.speed_scale = 0.0
	set_grip(1.0)
	closed_points = sample_skin()

func set_grip(amount: float) -> void:
	if is_equal_approx(last_grip, amount):
		return
	last_grip = amount
	var frame: float = remap(amount, 0.55, 1.0, 20.0, 30.0) if amount >= 0.55 else remap(amount, 0.0, 0.55, 1.0, 20.0)
	motion.seek(clampf(frame / 30.0, 0.0, motion.current_animation_length), true)
	skeleton.force_update_all_bone_transforms()

func sample_skin(fingers_only := false) -> PackedVector3Array:
	var result := PackedVector3Array()
	for obj in meshes:
		if fingers_only and not obj.name.begins_with("Palm"):
			continue
		var skin := obj.skin
		var matrices: Array[Transform3D] = []
		for i in skin.get_bind_count():
			var bone := skeleton.find_bone(skin.get_bind_name(i))
			if bone < 0:
				bone = skin.get_bind_bone(i)
			matrices.append(skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(i))
		var local_space := global_transform.affine_inverse() * skeleton.global_transform
		for surface in obj.mesh.get_surface_count():
			var data := obj.mesh.surface_get_arrays(surface)
			var coords: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
			var joints: PackedInt32Array = data[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = data[Mesh.ARRAY_WEIGHTS]
			for v in coords.size():
				var value := Vector3.ZERO
				for j in 4:
					var slot := v*4+j
					if weights[slot]>0.0:
						value += weights[slot] * (matrices[joints[slot]] * coords[v])
				result.append(local_space*value)
	return result

func get_geometry_points() -> PackedVector3Array:
	return closed_points

func get_fist_points() -> PackedVector3Array:
	return sample_skin(true)

func support_vertex(world_basis: Basis) -> Vector3:
	var support := closed_points[0]
	var up := world_basis.transposed() * Vector3.UP
	var minimum := up.dot(support)
	for point in closed_points:
		var h := up.dot(point)
		if h < minimum:
			minimum = h
			support = point
	return support

func pose_sleeve(camera: Camera3D, side: float, amount: float) -> void:
	# The wrist follows the original player track. Solve the two sleeve segments
	# back towards an off-screen shoulder, and preserve the wrist transform.
	var upper := skeleton.find_bone("UpperArm" + ("_L" if side < 0 else "_R"))
	if upper < 0:
		for i in skeleton.get_bone_count():
			if skeleton.get_bone_name(i).begins_with("UpperArm"):
				upper=i
	var fore: int = skeleton.get_bone_children(upper)[0]
	var hand: int = skeleton.get_bone_children(fore)[0]
	var u := skeleton.get_bone_global_rest(upper)
	var e := skeleton.get_bone_global_rest(fore)
	var h := skeleton.get_bone_global_rest(hand)
	if amount > 0.0001:
		var shoulder := skeleton.to_local(camera.to_global(Vector3(side*.46,-.43,-.035)))
		var target := h.origin
		var axis := (target-shoulder).normalized()
		var a := u.origin.distance_to(e.origin)
		var b := e.origin.distance_to(h.origin)
		var distance := clampf(shoulder.distance_to(target),absf(a-b)+.001,a+b-.001)
		shoulder = target-axis*distance
		var pole := skeleton.to_local(camera.to_global(Vector3(side*.72,-.61,-.22))) - shoulder
		pole = (pole-axis*axis.dot(pole)).normalized()
		var along := (a*a-b*b+distance*distance)/(2*distance)
		var elbow := shoulder+axis*along+pole*sqrt(maxf(0,a*a-along*along))
		var ur := Basis(Quaternion((e.origin-u.origin).normalized(),(elbow-shoulder).normalized()))*u.basis
		var er := Basis(Quaternion((h.origin-e.origin).normalized(),(target-elbow).normalized()))*e.basis
		u=u.interpolate_with(Transform3D(ur,shoulder),amount)
		e=e.interpolate_with(Transform3D(er,elbow),amount)
	skeleton.set_bone_global_pose(upper,u)
	skeleton.set_bone_global_pose(fore,e)
	skeleton.set_bone_global_pose(hand,h)
