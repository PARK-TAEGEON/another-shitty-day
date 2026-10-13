extends SceneTree
## 25s uninterrupted lab recording, three directions/strengths and production props.
var lab: Node3D
var directory: String
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	directory=OS.get_cmdline_user_args()[0]
	lab=load("res://tests/ragdoll_lab.tscn").instantiate()
	root.add_child(lab)
	lab.camera.fov=42
	lab.actor.health=100
	for frame in range(750):
		if frame==60:
			lab.label.text="LIGHT / head & chest reaction"
			lab.actor.receive_hit(Vector3(0,1,-7),lab.actor.position+Vector3(0,1.8,0),18)
		if frame==155:
			lab.label.text="MEDIUM / directional stagger & recovery"
			lab.actor.receive_hit(Vector3(9,1,0),lab.actor.position+Vector3(0,1.3,0),18)
		if frame==250:
			lab.reset_actor()
		if frame==285:
			lab.label.text="HEAVY / Jolt + chair contact"
			lab.actor.receive_hit(Vector3(0,2,-13),lab.actor.position+Vector3(0,1.3,0),28)
		if frame==430:lab.reset_actor()
		if frame==470:
			lab.label.text="HEAVY / side impact toward desk"
			lab.actor.receive_hit(Vector3(13,2,0),lab.actor.position+Vector3(0,1.3,0),28)
		if frame==605:lab.reset_actor()
		if frame==650:
			lab.label.text="HEAVY / back impact toward camera"
			lab.actor.receive_hit(Vector3(0,2,13),lab.actor.position+Vector3(0,1.3,0),28)
		if frame in [50,73,175,350,540,725]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory.path_join("lab-%03d.png"%frame))
		await process_frame
	print("KIM_LAB_CAPTURE_OK")
	quit()
