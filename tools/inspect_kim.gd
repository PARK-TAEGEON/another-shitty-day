extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var model = load("res://assets/characters/boss_kim/boss_kim.glb").instantiate()
	root.add_child(model)
	print(model.get_tree_string_pretty())
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	for i in range(skeleton.get_bone_count()):
		print("BONE ",skeleton.get_bone_name(i)," ",skeleton.get_bone_global_rest(i))
	var player: AnimationPlayer = model.find_child("AnimationPlayer",true,false)
	print("CLIPS ",player.get_animation_list())
	var bone=PhysicalBone3D.new()
	bone.joint_type=PhysicalBone3D.JOINT_TYPE_CONE
	for p in bone.get_property_list():
		if str(p.name).contains("joint"):
			print("PROPERTY ",p.name," = ",bone.get(p.name))
	bone.free()
	quit()
