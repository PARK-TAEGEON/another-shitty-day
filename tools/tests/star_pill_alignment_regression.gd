extends SceneTree
## The wanted-star pill stays one size, and the five stars sit in its middle.
## godot --headless --path game --script <this file>

const MainScript: Script = preload("res://scripts/main.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("STAR_PILL_ALIGNMENT: " + message)

func _pill(stars: Node) -> Control:
	var node: Node = stars.get_parent()
	while node != null and not (node is PanelContainer):
		node = node.get_parent()
	return node as Control

func _ink(stars: Node) -> Rect2:
	var first: Control = stars.get_child(0) as Control
	var last: Control = stars.get_child(stars.get_child_count() - 1) as Control
	var left := first.get_global_rect()
	var right := last.get_global_rect()
	return Rect2(left.position, Vector2(right.end.x - left.position.x, left.size.y))

func _gaps(pill: Rect2, ink: Rect2) -> Vector4:
	return Vector4(
		ink.position.x - pill.position.x,
		pill.end.x - ink.end.x,
		ink.position.y - pill.position.y,
		pill.end.y - ink.end.y
	)

func _same(a: Rect2, b: Rect2) -> bool:
	return a.position.is_equal_approx(b.position) and a.size.is_equal_approx(b.size)

func _run() -> void:
	var game: Node = MainScript.new()
	root.add_child(game)
	game.set("_automated_run", true)
	await process_frame
	game.call("_resume")
	for _frame: int in range(6):
		await process_frame
	var stars: Node = game.get("_star_row")
	var pill: Control = _pill(stars)
	check(pill != null, "star row is not inside the wanted pill")
	var resting: Rect2 = pill.get_global_rect()
	check(is_equal_approx(resting.size.x, 240.0) and is_equal_approx(resting.size.y, 56.0), "pill is not the Final-HUD size 240x56, got %s" % resting.size)
	var states: Array[float] = [0.0, 13.0, 32.0]
	for heat: float in states:
		game.set("response_heat", heat)
		game.call("_refresh_stars", false)
		await process_frame
		var box: Rect2 = pill.get_global_rect()
		var gaps: Vector4 = _gaps(box, _ink(stars))
		check(_same(box, resting), "pill moved at heat %s: %s vs %s" % [heat, box, resting])
		check(absf(gaps.x - gaps.y) <= 2.0, "left/right margin %s/%s at heat %s" % [gaps.x, gaps.y, heat])
		check(absf(gaps.z - gaps.w) <= 2.0, "top/bottom margin %s/%s at heat %s" % [gaps.z, gaps.w, heat])
		print("STAR_PILL heat=%s rect=%s gaps=%s" % [heat, box, gaps])
	game.set("response_heat", 0.0)
	game.call("_refresh_stars", false)
	await process_frame
	game.set("response_heat", 18.0)
	game.call("_refresh_stars", true)
	for _frame: int in range(4):
		await process_frame
		var during: Rect2 = pill.get_global_rect()
		check(_same(during, resting), "pill moved during the stamp: %s vs %s" % [during, resting])
	var sound: Node = game.get("sound")
	sound.call("stop_all")
	paused = false
	game.queue_free()
	await process_frame
	print("STAR_PILL_ALIGNMENT_REGRESSION_OK" if failures.is_empty() else "STAR_PILL_ALIGNMENT_REGRESSION_FAILED")
	if not failures.is_empty():
		print(JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
