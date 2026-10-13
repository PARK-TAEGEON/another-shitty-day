extends SceneTree
## 28-second, uninterrupted actual-game replay. Inputs use production Player.
## Camera tracking is capture-only; no NPC/score/timing is altered.
const MAIN=preload("res://scripts/main.gd")
var game: Node3D
var directory: String
var seen_gestures: Dictionary={}
var impacts: int=0

func _initialize() -> void:
	call_deferred("run")

func save_frame(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name_value+".png"))

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("A real renderer is required")
		quit(1)
		return
	directory=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(directory)
	ProjectSettings.set_setting("asd/characters/kim_rig_enabled",true)
	game=MAIN.new()
	root.add_child(game)
	game._automated_run=true
	game._resume()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var player=game.player
	var boss=game.world.opening_boss
	player.action_performed.connect(func(kind,at):
		if kind=="impact":impacts+=1)
	for frame in range(840):
		if frame==30:player.perform_action("slam")
		if frame>160:
			var target: Vector3=boss.global_position+Vector3(0,1.43,0)
			if boss.state=="down":target=boss._rig_adapter.pelvis_position()+Vector3.UP*.15
			var direction: Vector3=target-player.camera.global_position
			player.rotation.y=lerp_angle(player.rotation.y,atan2(-direction.x,-direction.z),.18)
			player._pitch=lerpf(player._pitch,atan2(direction.y,Vector2(direction.x,direction.z).length()),.16)
		if frame==600:player.perform_action("punch")
		if frame==660:player.perform_action("kick")
		if frame in [24,110,205,350,510,625,680,740,825]:
			await save_frame("office-%03d"%frame)
		if game.world.boss_lecture_active and not boss.boss_lecture_gesture.is_empty():seen_gestures[boss.boss_lecture_gesture]=true
		await process_frame
	var report={"type":"real Godot Windows Compatibility Movie Maker replay","frames":840,"fps":30,"gestures":seen_gestures.keys(),"player_impacts":impacts,"ragdoll":boss._rig_adapter.ragdoll_active,"damage_total":game.score,"state":boss.state}
	var file=FileAccess.open(directory.path_join("replay-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	game.sound.stop_all()
	print("KIM_SLICE_CAPTURE ",JSON.stringify(report))
	quit(0 if impacts==2 and boss._rig_adapter.ragdoll_active and seen_gestures.size()==3 else 1)
