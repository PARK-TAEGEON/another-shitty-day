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

func _hud_texts() -> Array[String]:
	var texts: Array[String] = []
	for leaf: Control in _leaves(game.get("_hud")):
		if leaf is Label and leaf != game.get("_focus_label") and not (leaf as Label).text.is_empty():
			texts.append((leaf as Label).text)
	return texts

func _assert_menu_layout(label: String) -> void:
	var card: Control = game.get("_menu_card") as Control
	var card_rect: Rect2 = card.get_global_rect()
	# The headless native window can report a dummy size; layout uses the logical
	# viewport selected by the project's 1280×720 canvas stretch configuration.
	var viewport_rect: Rect2 = root.get_visible_rect()
	check(viewport_rect.size == Vector2(1280, 720), label + ": fixture is not using the required logical resolution")
	check(viewport_rect.encloses(card_rect), label + ": menu card exceeded 1280x720")
	var leaves: Array[Control] = _leaves(card)
	for index: int in range(leaves.size()):
		var leaf: Control = leaves[index]
		var leaf_rect: Rect2 = leaf.get_global_rect()
		check(card_rect.grow(0.5).encloses(leaf_rect), label + ": control extended outside the card: " + str(leaf.get("text")))
		for other_index: int in range(index + 1, leaves.size()):
			check(not leaf_rect.intersects(leaves[other_index].get_global_rect()), label + ": visible controls overlap")
	observations[label] = {"card_position": [card_rect.position.x, card_rect.position.y], "card_size": [card_rect.size.x, card_rect.size.y], "visible_controls": leaves.size()}

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
	_assert_menu_layout("start_settings")
	(game.get("_controls_button") as Button).pressed.emit()
	await _settle()
	_assert_menu_layout("start_controls")
	check((game.get("_controls_panel") as Control).is_visible_in_tree(), "controls tab is unavailable before starting")
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
	check(_hud_texts() == ["누적 피해액", "$100,000", "·"], "damage, impact, hit or failed slam produced HUD text beyond title/amount/crosshair")
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
	_assert_menu_layout("pause_settings")
	var paused_elapsed: float = float(game.get("elapsed"))
	var paused_caption: float = float(game.get("_caption_timer"))
	(game.get("_controls_button") as Button).pressed.emit()
	await _settle()
	check((game.get("_controls_panel") as Control).is_visible_in_tree() and not (game.get("_options_panel") as Control).is_visible_in_tree(), "controls tab did not replace settings")
	check((game.get("_controls_button") as Button).button_pressed and not (game.get("_settings_button") as Button).button_pressed, "selected tab indicator disagrees with the visible page")
	game.call("_process", 12.0)
	check(paused and is_equal_approx(float(game.get("elapsed")), paused_elapsed) and is_equal_approx(float(game.get("_caption_timer")), paused_caption), "viewing controls advanced gameplay or the current subtitle")
	_assert_menu_layout("pause_controls")
	(game.get("_settings_button") as Button).pressed.emit()
	var options: Control = game.get("_options_panel") as Control
	var volume: HSlider = options.get_child(0).get_child(1) as HSlider
	volume.value = 0.31
	check(is_equal_approx(float(game.get("_volume")), 0.31) and paused, "settings slider stopped working or resumed play")
	await _press_escape()
	check(not paused and bool(player.get("enabled")) and not (game.get("_menu") as Control).visible, "Esc from settings did not resume")
	world.emit_signal("incident_event", "ASSAULT", 8.0, player.global_position)
	check(int(game.get("phase")) == 2 and game.call("_staff_count", "security") == 1 and int(ledger.breakdown()["response"]) == 100000, "hidden response UI disabled the real guard dispatch or its assessment")
	check(_hud_texts() == ["누적 피해액", "$400,000", "·"], "dispatch showed a system caption or response HUD")
	world.emit_signal("player_hit", 90.0)
	await _settle()
	check(bool(game.get("ended")) and paused and ledger.is_frozen(), "subdual no longer ends and freezes the round")
	check((game.get("_result_total") as Label).text == "$400,000", "result total did not preserve dollar units")
	check(not (game.get("_menu_tabs") as Control).is_visible_in_tree() and not (game.get("_controls_panel") as Control).is_visible_in_tree() and not options.is_visible_in_tree(), "settings or controls overlap the results")
	_assert_menu_layout("results")
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
