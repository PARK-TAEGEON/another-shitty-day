extends SceneTree
## Replay the two desk strikes in the packed office with no asset flags.
var game: Node3D
var player: CharacterBody3D
var contacts: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	game = current_scene
	player = game.player
	game._automated_run = true
	game._resume()
	player.desk_requested.connect(_contact)
	await frames(15)
	var guard: Array[Vector3] = [player._left.position, player._right.position]
	await slam(39)
	await slam(34)
	var back_in_guard: bool = player._left.position.is_equal_approx(guard[0]) and player._right.position.is_equal_approx(guard[1])
	var correct: bool = contacts.size() == 2 and contacts[0].variant == "B" and contacts[1].variant == "A"
	for contact: Dictionary in contacts:
		for y: float in contact.skins_y_m:
			correct = correct and absf(y - 1.062) < 0.004
	print("INTEGRATION_DESK ", JSON.stringify({"contacts": contacts, "back_in_guard": back_in_guard}))
	game.sound.stop_all()
	quit(0 if correct and back_in_guard else 1)

func frames(count: int) -> void:
	for i in count:
		await process_frame

func slam(wait_frames: int) -> void:
	var pressed := InputEventAction.new()
	pressed.action = "slam"
	pressed.pressed = true
	Input.parse_input_event(pressed)
	Input.flush_buffered_events()
	var released := InputEventAction.new()
	released.action = "slam"
	Input.parse_input_event(released)
	Input.flush_buffered_events()
	await frames(wait_frames)

func _contact(_origin: Vector3) -> void:
	var minima: Array[float] = []
	for arm: Node3D in [player._left, player._right]:
		var low := INF
		for vertex: Vector3 in arm.sample_skin(true):
			low = minf(low, arm.to_global(vertex).y)
		minima.append(low)
	contacts.append({
		"variant": player._slam_variant,
		"seconds": player._anim_duration - player._anim,
		"skins_y_m": minima,
	})
