extends SceneTree
## Actual HUD/menu signal checks at 1280×720. No screenshot claims are made here.
## godot --headless --path game --script <this file> -- --capture-ui

const MainScript: Script = preload("res://scripts/main.gd")
const LedgerScript: Script = preload("res://scripts/social_damage.gd")

var failures: Array[String] = []
var observations: Dictionary = {}
var game: Node3D

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("MINIMAL_HUD_CHECK: " + message)

func _settle() -> void:
	for frame: int in range(3):
		await process_frame

func _leaves(node: Node) -> Array[Control]:
	var result: Array[Control] = []
	if node is Control and not (node as Control).is_visible_in_tree():
		return result
	if node is Label or node is BaseButton or node is Range:
		result.append(node as Control)
	for child: Node in node.get_children():
		result.append_array(_leaves(child))
	return result

func _hud_has(text: String) -> bool:
	return _hud_texts().has(text)

func _hud_texts() -> Array[String]:
	var texts: Array[String] = []
	for leaf: Control in _leaves(game.get("_hud")):
		if leaf is Label and leaf != game.get("_focus_label") and not (leaf as Label).text.is_empty():
			texts.append((leaf as Label).text)
	return texts

func _assert_menu_layout(label: String) -> void:
	var card: Control = game.get("_menu_card") as Control
	# Compare in the card's own space so the title card's small rotation does not
	# turn neighboring rectangles into false overlaps.
	var viewport_rect: Rect2 = root.get_visible_rect()
	check(viewport_rect.size == Vector2(1280, 720), label + ": fixture is not using the required logical resolution")
	check(card.size.x <= 1280.0 and card.size.y <= 720.0, label + ": menu card exceeded 1280x720")
	check(card.position.x >= -1.0 and card.position.y >= -1.0, label + ": menu card starts off screen")
	check(card.position.x + card.size.x <= 1281.0 and card.position.y + card.size.y <= 721.0, label + ": menu card ends off screen")
	var local_bounds: Rect2 = Rect2(Vector2.ZERO, card.size).grow(8.0)
	var inverse: Transform2D = card.get_global_transform().affine_inverse()
	var leaves: Array[Control] = _leaves(card)
	var placed: Array[Rect2] = []
	for leaf: Control in leaves:
		var leaf_rect: Rect2 = Rect2(inverse * leaf.get_global_position(), leaf.size)
		check(local_bounds.encloses(leaf_rect), label + ": control extended outside the card: " + str(leaf.get("text")))
		for other: Rect2 in placed:
			check(not leaf_rect.intersects(other), label + ": visible controls overlap: " + str(leaf.get("text")))
		placed.append(leaf_rect)
	observations[label] = {"card_position": [card.position.x, card.position.y], "card_size": [card.size.x, card.size.y], "visible_controls": leaves.size()}

func _press_escape() -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	root.push_input(event)
	await _settle()

func _run() -> void:
	game = MainScript.new() as Node3D
	root.add_child(game)
	game.set("_automated_run", true)
	await _settle()
	check(str((game.get("_menu_title") as Label).text).contains("Another"), "start screen did not show the game title first")
	check(str((game.get("_start_button") as Button).text).contains("출근하기"), "start screen did not offer 출근하기")
	check(not (game.get("_options_panel") as Control).is_visible_in_tree(), "settings opened before the player asked")
	_assert_menu_layout("start_title")
	(game.get("_settings_button") as Button).pressed.emit()
	await _settle()
	check((game.get("_options_panel") as Control).is_visible_in_tree() and (game.get("_controls_panel") as Control).is_visible_in_tree(), "settings and controls are not shown together")
	_assert_menu_layout("start_settings")
	(game.get("_start_button") as Button).pressed.emit()
	await _settle()
	var world: Node3D = game.get("world") as Node3D
	var player: Node3D = game.get("player") as Node3D
	var ledger: RefCounted = game.get("damage_ledger") as RefCounted
	check(bool(game.get("playing")) and not paused and bool(player.get("enabled")), "start button did not enter active play")
	game.call("_clear_caption")
	world.emit_signal("damage_assessed", "ui-monitor", "property", 100000, "모니터 손상")
	world.emit_signal("impact_event", "IMPACT", 1000, Vector3.ZERO)
	world.emit_signal("dialogue", "충돌 안내를 대사로 표시하면 안 됩니다")
	game.call("_slam", Vector3(50, 0, 50))
	world.emit_signal("player_hit", 10.0)
	game.call("_process", 0.01)
	check(_hud_has("$100,000") and _hud_has("누적 피해액") and _hud_has("점수"), "damage HUD lost the score or the dollar amount")
	check(not _hud_has("충돌") and not _hud_has("IMPACT") and not _hud_has("타격"), "impact or hit text returned to the HUD")
	check(is_equal_approx(float(game.get("composure")), 90.0) and float(player.get("_shake")) > 0.0, "removing the bar also removed actual subdual feedback")
	var hud: Control = game.get("_hud") as Control
	check(hud.find_children("*", "ProgressBar", true, false).is_empty(), "an unused response or health meter is still created")
	observations["after_incident_texts"] = _hud_texts()
	var colleague: Node3D = world.get("opening_coworker") as Node3D
	world.emit_signal("ambient_dialogue", "박 대리", "왜 그래?", 2.8, colleague)
	world.emit_signal("damage_assessed", "ui-monitor", "property", 300000, "모니터 사용 불능")
	world.emit_signal("impact_event", "HIT", 1000, Vector3.ZERO)
	game.call("_slam", Vector3(50, 0, 50))
	check((game.get("_caption_label") as Label).text == "왜 그래?" and game.get("_caption_source") == colleague, "actual speaker dialogue was removed or displaced by an event")
	check((game.get("_score_label") as Label).text == "$300,000" and ledger.total() == 300000, "dollar display rescaled or changed the existing assessment amounts")
	await _press_escape()
	check(paused and not bool(player.get("enabled")) and (game.get("_menu") as Control).visible, "Esc did not pause the actual game")
	check((game.get("_controls_panel") as Control).is_visible_in_tree() and (game.get("_options_panel") as Control).is_visible_in_tree(), "pause hid settings or the controls")
	var paused_elapsed: float = float(game.get("elapsed"))
	var paused_caption: float = float(game.get("_caption_timer"))
	game.call("_process", 12.0)
	check(paused and is_equal_approx(float(game.get("elapsed")), paused_elapsed) and is_equal_approx(float(game.get("_caption_timer")), paused_caption), "viewing the pause board advanced gameplay or the current subtitle")
	_assert_menu_layout("pause")
	var options: Control = game.get("_options_panel") as Control
	var volume: HSlider = options.find_children("*", "HSlider", true, false)[0] as HSlider
	volume.value = 0.31
	check(is_equal_approx(float(game.get("_volume")), 0.31) and paused, "settings slider stopped working or resumed play")
	await _press_escape()
	check(not paused and bool(player.get("enabled")) and not (game.get("_menu") as Control).visible, "Esc from settings did not resume")
	world.emit_signal("incident_event", "ASSAULT", 8.0, player.global_position)
	check(int(game.get("phase")) == 2 and game.call("_staff_count", "security") == 1 and int(ledger.breakdown()["response"]) == 100000, "hidden response UI disabled the real guard dispatch or its assessment")
	check(_hud_has("$400,000") and _hud_has("누적 피해액"), "dispatch changed the dollar display")
	check(not _hud_has("출동") and not _hud_has("ASSAULT"), "dispatch showed a system caption")
	world.emit_signal("player_hit", 90.0)
	await _settle()
	check(bool(game.get("ended")) and paused and ledger.is_frozen(), "subdual no longer ends and freezes the round")
	check((game.get("_result_total") as Label).text == "$400,000", "result total did not preserve dollar units")
	check(not (game.get("_menu_tabs") as Control).is_visible_in_tree() and not (game.get("_controls_panel") as Control).is_visible_in_tree() and not options.is_visible_in_tree(), "settings or controls overlap the results")
	game.call("_settle_result_presentation")
	check((game.get("_result_root") as Control).visible, "the newspaper result was not shown")
	await _press_escape()
	check(paused and bool(game.get("ended")) and (game.get("_menu") as Control).visible, "Esc resumed a completed round")
	observations["final"] = {"total": ledger.total(), "currency": LedgerScript.format_currency(ledger.total()), "record_key": LedgerScript.RECORD_KEY, "phase": game.get("phase")}
	var sound: Node = game.get("sound") as Node
	sound.call("stop_all")
	paused = false
	game.queue_free()
	await _settle()
	observations["failures"] = failures
	print(JSON.stringify(observations, "\t"))
	print("MINIMAL_HUD_REGRESSION_OK" if failures.is_empty() else "MINIMAL_HUD_REGRESSION_FAILED")
	quit(0 if failures.is_empty() else 1)
