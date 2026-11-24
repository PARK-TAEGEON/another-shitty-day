extends SceneTree
## Collect the posed right hand in mug-local Godot coordinates at the existing rig gate.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	change_scene_to_file("res://rig_slice/verify.tscn")
	await scene_changed
	var director = current_scene
	while director.t < 225:
		await process_frame
	var samples := []
	for vertex in director.p._right.sample_skin(true):
		var local: Vector3 = director.mug.to_local(director.p._right.to_global(vertex))
		samples.append([local.x, -local.z, local.y])
	var file := FileAccess.open("/tmp/asd-office-hand.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(samples))
	file.close()
