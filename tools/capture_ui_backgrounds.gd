extends SceneTree
## Clean 1280x720 backgrounds (HUD and menu hidden) from the real game, for UI
## mockups. Uses real input actions; nothing is staged on NPCs.
##   godot --path game --script <this file> -- --output-dir <dir>

var game: Node3D
var player: CharacterBody3D
var world: Node3D
var out_dir: String = "/tmp/ui-shots"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = args.find("--output-dir")
	if i >= 0 and i + 1 < args.size():
		out_dir = args[i + 1]
	root.size = Vector2i(1280, 720)
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(game)
	await process_frame
	player = game.get("player") as CharacterBody3D
	world = game.get("world") as Node3D
	game.call("_resume")
	(game.get("juice") as Node3D).set("enabled", false)
	var only_aftermath: bool = args.has("--aftermath-only")
	await _wait(1.0)
	if only_aftermath:
		await _aftermath()
		quit(0)
		return
	await _shot("01-desk")
	await _press("slam")
	await _wait(1.75)
	await _shot("02-boss-peek")
	await _wait(3.2)
	var boss: Node3D = world.get("opening_boss") as Node3D
	for frame: int in range(150):
		if boss.global_position.distance_to(player.global_position) < 1.9:
			break
		_aim(boss.global_position + Vector3.UP * 1.55, 0.1)
		await process_frame
	for frame: int in range(20):
		_aim(boss.global_position + Vector3.UP * 1.45, 0.2)
		await process_frame
	await _shot("03-boss-close")
	await _aftermath()
	quit(0)

func _aftermath() -> void:
	var boss: Node3D = world.get("opening_boss") as Node3D
	var coworker: Node3D = world.get("opening_coworker") as Node3D
	await _press("slam")
	await _wait(2.4)
	for frame: int in range(12):
		_aim(coworker.global_position + Vector3.UP * 1.1, 0.3)
		await process_frame
	for kind: String in ["kick", "punch", "kick", "punch"]:
		if str(coworker.get("state")) == "down":
			break
		_aim(coworker.global_position + Vector3.UP * 1.1)
		await _press(kind)
		await _wait(0.42)
	await _wait(1.4)
	for frame: int in range(15):
		_aim(coworker.global_position + Vector3.UP * 0.5, 0.25)
		await process_frame
	await _shot("04-aftermath")

func _shot(label: String) -> void:
	var hud: Control = game.get("_hud") as Control
	var menu: Control = game.get("_menu") as Control
	var hud_was: bool = hud.visible
	hud.visible = false
	menu.visible = false
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(label + ".png"))
	print("UI_BG " + label)
	hud.visible = hud_was

func _wait(seconds: float) -> void:
	for frame: int in range(ceili(seconds * 30.0)):
		await process_frame

func _aim(target: Vector3, blend: float = 1.0) -> void:
	var camera: Camera3D = player.get("camera") as Camera3D
	var direction: Vector3 = target - camera.global_position
	player.rotation.y = lerp_angle(player.rotation.y, atan2(-direction.x, -direction.z), blend)
	var pitch: float = atan2(direction.y, Vector2(direction.x, direction.z).length())
	player.set("_pitch", lerpf(float(player.get("_pitch")), clampf(pitch, -1.2, 1.15), blend))

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
