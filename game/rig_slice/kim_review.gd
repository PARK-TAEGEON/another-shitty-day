extends Node3D

const FRAMES := [1, 20, 40, 60]
const TITLES := ["A-pose", "Shoulders", "Elbows and wrists", "Fingers"]
@onready var motion: AnimationPlayer = $Kim.find_children("*", "AnimationPlayer", true, false)[0]

func _ready() -> void:
	$Camera.look_at(Vector3(0, 1.06, 0))
	motion.play("Joint_review")
	motion.speed_scale = 0.0
	pose(0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-kim="):
			var folder := arg.trim_prefix("--capture-kim=")
			DirAccess.make_dir_recursive_absolute(folder)
			for i in FRAMES.size():
				pose(i)
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var err := get_viewport().get_texture().get_image().save_jpg(folder.path_join("kim_%d.jpg" % i), .94)
				if err != OK:
					get_tree().quit(1)
					return
			get_tree().quit()

func pose(index: int) -> void:
	motion.seek(FRAMES[index] / 30.0, true)
	$Instructions.text = "%d   %s     |     1–4" % [index + 1, TITLES[index]]

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode >= KEY_1 and event.keycode <= KEY_4:
		pose(event.keycode - KEY_1)
