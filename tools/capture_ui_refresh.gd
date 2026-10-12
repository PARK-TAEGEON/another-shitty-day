extends SceneTree
## Capture real rendered UI states, with one real player desk-slam input.
## Use --fixed-fps 60 --script <this file> -- --capture-ui --capture-dir <dir>.
## The final result image is explicitly a UI fixture, not a natural run ending.

const MainScript: Script = preload("res://scripts/main.gd")
var game: Node3D
var output_dir: String = "user://ui-refresh-review"
var observations: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for index: int in range(count):
		await process_frame

func _save(label: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var path: String = output_dir.path_join(label + ".png")
	var error: Error = root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("UI_REFRESH_CAPTURE could not save: " + path)
		quit(1)
		return
	var state: Dictionary = {
		"label": label,
		"score": int(game.get("score")),
		"score_text": str(game.get("_score_label").text),
		"phase": int(game.get("phase")),
		"menu_visible": bool(game.get("_menu").visible),
		"caption_visible": bool(game.get("_caption_panel").is_visible_in_tree()),
		"caption": str(game.get("_caption_label").text),
	}
	observations.append(state)

func _press(action: String) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("UI_REFRESH_CAPTURE requires a real rendering display")
		quit(1)
		return
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size() - 1):
		if args[index] == "--capture-dir":
			output_dir = args[index + 1]
	output_dir = ProjectSettings.globalize_path(output_dir)
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(1280, 720)
	game = MainScript.new() as Node3D
	root.add_child(game)
	game.set("_automated_run", true)
	await _frames(12)
	await _save("01-main-menu")
	game.call("_resume")
	await _frames(18)
	await _save("02-quiet-hud")
	await _press("slam")
	await _frames(60)
	await _save("03-slam-with-dialogue")
	await _frames(90)
	await _save("04-boss-peek")
	game.call("_open_menu", false)
	game.call("_show_menu_page", "settings")
	await _save("05-settings")
	game.get("_controls_button").emit_signal("pressed")
	await _save("06-controls")
	game.call("_resume")
	await _frames(6)
	game.call("_end_run")
	await _save("07-result-ui-fixture")
	var report: Dictionary = {
		"kind": "actual rendered UI review",
		"viewport": [1280, 720],
		"input": "real slam action through Input.parse_input_event",
		"result_screen": "UI fixture via _end_run; not a natural subdual replay",
		"states": observations,
	}
	var file: FileAccess = FileAccess.open(output_dir.path_join("capture-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	paused = false
	game.get("sound").call("stop_all")
	game.queue_free()
	await _frames(3)
	print("UI_REFRESH_CAPTURE_OK")
	quit(0)
