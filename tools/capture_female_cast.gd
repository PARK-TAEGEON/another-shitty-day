extends SceneTree
## Actual office capture for the two updated adult women. Only the player review
## camera changes position; NPC placement, lighting, work and dialogue remain live.
## Run rendered Godot at --fixed-fps 60 with -- --capture-ui --capture-dir <dir>.

const MainScript: Script = preload("res://scripts/main.gd")
var game: Node3D
var player: CharacterBody3D
var output_dir: String = "/tmp/desk-breaker-female-cast"
var failures: Array[String] = []
var moments: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	# Keep the real game clock and physics running between stills while avoiding
	# hundreds of discarded software-rendered office frames. Every saved still
	# below restores 3D and waits for fresh completed draws.
	var previous_disable_3d: bool = root.disable_3d
	if count > 6:
		root.disable_3d = true
	for frame: int in range(count):
		await process_frame
	root.disable_3d = previous_disable_3d

func _cut(at: Vector3, target: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	var camera: Camera3D = player.get("camera") as Camera3D
	var direction: Vector3 = target - camera.global_position
	player.rotation.y = atan2(-direction.x, -direction.z)
	player.set("_pitch", atan2(direction.y, Vector2(direction.x, direction.z).length()))

func _save(label: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var path: String = output_dir.path_join(label + ".png")
	if root.get_texture().get_image().save_png(path) != OK:
		failures.append("could not save " + path)
	var workers: Array[Dictionary] = []
	for actor: Node3D in game.get("world").get("npcs"):
		if actor.get("character_gender") == "female":
			workers.append({"name": actor.get("display_name"), "gender": actor.get("character_gender"), "state": actor.get("state"), "health": actor.get("health"), "activity": actor.get("work_activity"), "working": actor.call("is_working")})
			if not bool(actor.call("is_working")) or not is_equal_approx(float(actor.get("health")), 40.0):
				failures.append("ordinary work changed for " + str(actor.get("display_name")))
	if workers.size() != 2:
		failures.append("expected exactly two women in the actual office")
	if int(game.get("score")) != 0 or not is_zero_approx(float(game.get("response_heat"))):
		failures.append("quiet camera review produced damage or an incident")
	moments.append({"image": path, "women": workers, "score": game.get("score"), "heat": game.get("response_heat"), "caption_speaker": game.get("_caption_speaker").text, "caption": game.get("_caption_label").text})
	print("FEMALE_CAST_RENDER " + path)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("FEMALE_CAST_CAPTURE requires a rendering display")
		quit(1)
		return
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size() - 1):
		if args[index] == "--capture-dir":
			output_dir = args[index + 1]
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(1600, 900)
	game = MainScript.new() as Node3D
	root.add_child(game)
	game.set("_automated_run", true)
	player = game.get("player") as CharacterBody3D
	await _frames(10)
	game.call("_resume")
	_cut(Vector3(-2.38, 0.08, -4.10), Vector3(-4.10, 1.40, -3.25))
	await _frames(195)
	await _save("01-intern-working")
	_cut(Vector3(2.35, 0.08, -4.95), Vector3(4.15, 1.34, -4.22))
	await _frames(315)
	await _save("02-junior-working")
	_cut(Vector3(0, 0.08, -7.75), Vector3(0, 1.36, -3.70))
	await _frames(160)
	await _save("03-department-wide")
	var report: Dictionary = {"passed": failures.is_empty(), "failures": failures, "kind": "actual office; camera cuts only", "moments": moments}
	var file: FileAccess = FileAccess.open(output_dir.path_join("capture-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	game.get("sound").call("stop_all")
	game.queue_free()
	await _frames(3)
	print("FEMALE_CAST_CAPTURE_OK" if failures.is_empty() else "FEMALE_CAST_CAPTURE_FAILED")
	quit(0 if failures.is_empty() else 1)
