extends Node3D
## A small office, a growing disturbance, and one finite social-loss account per round.
const WorldScript = preload("res://scripts/world.gd")
const PlayerScript = preload("res://scripts/player.gd")
const SoundScript = preload("res://scripts/audio.gd")
const SocialDamageScript = preload("res://scripts/social_damage.gd")
const ChaosScript = preload("res://scripts/scenario/chaos_score.gd")
const PoliceArrivalScript = preload("res://scripts/scenario/police_arrival.gd")
var chaos: RefCounted = ChaosScript.new()
var chaos_high_score: int = 0
var police_arrival: Node
var _result_chaos: Label
var _result_route: Label
var _caption_priority: int = 0
const RESPONSE_THRESHOLDS: Array[float] = [0.0, 0.0, 8.0, 18.0, 32.0]
const RESPONSE_DELAYS: Array[float] = [0.0, 0.0, 0.0, 8.0, 10.0]
const FONT = preload("res://assets/fonts/KoreanUI.ttf")
const CREAM: Color = Color("f1e8d6")
const INK: Color = Color("173b3f")
const ORANGE: Color = Color("ed805b")

var world: Node3D
var player: CharacterBody3D
var sound: Node
var damage_ledger: RefCounted = SocialDamageScript.new()
var score: int = 0
var response_heat: float = 0.0
var _response_changed_at: float = 0.0
var high_score: int = 0
var composure: float = 100.0
var phase: int = 0
var elapsed: float = 0.0
var disturbed_time: float = 0.0
var disturbed: bool = false
var playing: bool = false
var ended: bool = false
var _restarting: bool = false
var _automated_run: bool = false
var _capture_failed: bool = false
var _settings: ConfigFile = ConfigFile.new()
var _volume: float = 0.7
var _caption_timer: float = 0.0
var _hud: Control
var _score_label: Label
var _focus_label: Label
var _caption_label: Label
var _caption_panel: PanelContainer
var _caption_speaker: Label
var _caption_source: Node3D
var _caption_is_scene: bool = false
var _menu: Control
var _menu_card: PanelContainer
var _menu_title: Label
var _menu_subtitle: Label
var _menu_tabs: HBoxContainer
var _menu_pages: Control
var _settings_button: Button
var _controls_button: Button
var _options_panel: VBoxContainer
var _controls_panel: GridContainer
var _result_panel: VBoxContainer
var _result_total: Label
var _result_record: Label
var _result_values: Dictionary = {}
var _start_button: Button
var _restart_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_automated_run = args.has("--smoke-test") or args.has("--capture-demo") or args.has("--capture-opening") or args.has("--capture-lecture") or args.has("--capture-office") or args.has("--capture-ui")
	_settings.load("user://settings.cfg")
	chaos_high_score = maxi(0, int(_settings.get_value(ChaosScript.RECORD_SECTION, ChaosScript.RECORD_KEY, 0)))
	high_score = maxi(0, int(_settings.get_value(SocialDamageScript.RECORD_SECTION, SocialDamageScript.RECORD_KEY, 0)))
	if _automated_run:
		high_score = 0
	_volume = float(_settings.get_value("options", "volume", 0.7))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(_volume, 0.001)))
	world = WorldScript.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	player = PlayerScript.new()
	player.position = Vector3(0, 0.08, 0.65)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.sensitivity = float(_settings.get_value("options", "sensitivity", 0.0024))
	player.shake_scale = float(_settings.get_value("options", "shake", 0.55))
	world.player_target = player
	world.scenario_line_can_start = func(priority: int) -> bool: return _caption_timer <= 0.0 or _caption_priority < priority
	chaos.reset(world.events.round_id)
	police_arrival = PoliceArrivalScript.new()
	add_child(police_arrival)
	world.scenario_event.connect(_on_scenario_event)
	world.scenario_dialogue.connect(_scenario_caption)
	world.responder_arrived.connect(_on_responder_arrived)
	sound = SoundScript.new()
	add_child(sound)
	world.impact_event.connect(_on_impact)
	world.damage_assessed.connect(_on_damage_assessed)
	world.incident_event.connect(_on_incident)
	world.ambient_dialogue.connect(_ambient_caption)
	world.opening_began.connect(_clear_caption)
	world.scene_dialogue.connect(_scene_caption)
	world.scene_speaker_invalidated.connect(_invalidate_speaker)
	world.first_disturbance.connect(_first_disturbance)
	world.player_hit.connect(_on_player_hit)
	player.action_performed.connect(_on_action)
	player.activity_started.connect(world.notify_player_activity)
	player.focus_changed.connect(_set_focus)
	player.desk_requested.connect(_slam)
	player.contact_started.connect(world.begin_player_contact)
	player.contact_finished.connect(world.end_player_contact)
	_build_ui()
	_open_menu(true)
	if args.has("--smoke-test"):
		call_deferred("_smoke_test")
	elif args.has("--capture-demo"):
		call_deferred("_capture_demo")
	elif args.has("--capture-opening"):
		call_deferred("_capture_opening")
	elif args.has("--capture-lecture"):
		call_deferred("_capture_opening", true)
	elif args.has("--capture-office"):
		call_deferred("_capture_office")

func _process(delta: float) -> void:
	if playing and not ended and not get_tree().paused:
		elapsed += delta
		if disturbed:
			disturbed_time += delta
			_update_response()
		_caption_timer = maxf(0.0, _caption_timer - delta)
		if (_caption_is_scene or _caption_source != null) and not _speaker_available(_caption_source, _caption_is_scene):
			_clear_caption()
		_caption_panel.visible = _caption_timer > 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if playing and not ended:
			if _menu.visible:
				_resume()
			else:
				_open_menu(false)
	elif event.is_action_pressed("restart") and playing:
		_restart()

func _style(background: Color, radius: int = 12, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = background
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	if border.a > 0:
		box.border_color = border
		box.set_border_width_all(1)
	return box

func _label(text: String, size: int, color: Color = CREAM) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _full(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _centered(control: Control, y: float, width: float, height: float) -> void:
	control.anchor_left = 0.5
	control.anchor_right = 0.5
	control.anchor_top = 0.5
	control.anchor_bottom = 0.5
	control.offset_left = -width * 0.5
	control.offset_right = width * 0.5
	control.offset_top = y
	control.offset_bottom = y + height

func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root: Control = Control.new()
	_full(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_hud = Control.new()
	_full(_hud)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hud)
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(24, 24)
	panel.custom_minimum_size = Vector2(252, 86)
	var score_style: StyleBoxFlat = _style(Color("eee5d2"), 10, Color("b7c8ba"))
	score_style.content_margin_left = 16
	score_style.content_margin_right = 16
	score_style.content_margin_top = 10
	score_style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", score_style)
	_hud.add_child(panel)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	panel.add_child(stack)
	stack.add_child(_label("누적 피해액", 14, Color("497574")))
	_score_label = _label(SocialDamageScript.format_currency(0), 30, INK)
	stack.add_child(_score_label)
	var crosshair: Label = _label("·", 35)
	_centered(crosshair, -24, 24, 40)
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.add_theme_constant_override("outline_size", 4)
	crosshair.add_theme_color_override("font_outline_color", INK)
	_hud.add_child(crosshair)
	_focus_label = _label("", 15)
	_centered(_focus_label, 34, 500, 28)
	_focus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_focus_label.add_theme_constant_override("outline_size", 5)
	_focus_label.add_theme_color_override("font_outline_color", Color("163035"))
	_focus_label.visible = false
	_hud.add_child(_focus_label)
	_caption_panel = PanelContainer.new()
	_caption_panel.anchor_left = 0.5
	_caption_panel.anchor_right = 0.5
	_caption_panel.anchor_top = 1.0
	_caption_panel.anchor_bottom = 1.0
	_caption_panel.offset_left = -400
	_caption_panel.offset_right = 400
	_caption_panel.offset_top = -152
	_caption_panel.offset_bottom = -46
	_caption_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_panel.add_theme_stylebox_override("panel", _style(Color(0.035, 0.06, 0.075, 0.95), 9, Color(0.75, 0.80, 0.77, 0.3)))
	_hud.add_child(_caption_panel)
	var caption_stack: VBoxContainer = VBoxContainer.new()
	caption_stack.add_theme_constant_override("separation", 5)
	caption_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	_caption_panel.add_child(caption_stack)
	_caption_speaker = _label("", 16, Color("b6dcd0"))
	_caption_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_stack.add_child(_caption_speaker)
	_caption_label = _label("", 28, Color("fffaf0"))
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption_label.add_theme_constant_override("outline_size", 2)
	_caption_label.add_theme_color_override("font_outline_color", Color("101a20"))
	caption_stack.add_child(_caption_label)
	_caption_panel.visible = false
	_menu = Control.new()
	_full(_menu)
	root.add_child(_menu)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.055, 0.14, 0.16, 0.88)
	_full(shade)
	_menu.add_child(shade)
	var card: PanelContainer = PanelContainer.new()
	_menu_card = card
	_centered(card, -310, 652, 620)
	card.add_theme_stylebox_override("panel", _style(Color("eee5d2"), 20, Color("b8c9ba")))
	_menu.add_child(card)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	_menu_title = _label("DESK BREAKER", 38, INK)
	col.add_child(_menu_title)
	_menu_subtitle = _label("평범한 회사 운영지원팀.\n오늘도 급한 일은 전부 내 책상으로 온다.", 16, INK)
	_menu_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_menu_subtitle)
	_menu_tabs = HBoxContainer.new()
	_menu_tabs.add_theme_constant_override("separation", 8)
	col.add_child(_menu_tabs)
	var tabs: ButtonGroup = ButtonGroup.new()
	_settings_button = _tab_button("설정", tabs)
	_settings_button.pressed.connect(_show_menu_page.bind("settings"))
	_menu_tabs.add_child(_settings_button)
	_controls_button = _tab_button("조작법", tabs)
	_controls_button.pressed.connect(_show_menu_page.bind("controls"))
	_menu_tabs.add_child(_controls_button)
	_menu_pages = Control.new()
	_menu_pages.custom_minimum_size.y = 216
	col.add_child(_menu_pages)
	_options_panel = VBoxContainer.new()
	_full(_options_panel)
	_options_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_options_panel.add_theme_constant_override("separation", 20)
	_menu_pages.add_child(_options_panel)
	_add_option(_options_panel, "음량", 0.0, 1.0, _volume, func(value: float) -> void:
		_volume = value
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.001)))
		_save_option("volume", value))
	_add_option(_options_panel, "마우스 감도", 0.001, 0.005, player.sensitivity, func(value: float) -> void:
		player.sensitivity = value
		_save_option("sensitivity", value))
	_add_option(_options_panel, "화면 흔들림", 0.0, 1.0, player.shake_scale, func(value: float) -> void:
		player.shake_scale = value
		_save_option("shake", value))
	_controls_panel = GridContainer.new()
	_full(_controls_panel)
	_controls_panel.columns = 2
	_controls_panel.add_theme_constant_override("h_separation", 28)
	_controls_panel.add_theme_constant_override("v_separation", 5)
	_menu_pages.add_child(_controls_panel)
	var controls: Array[Array] = [
		["W A S D", "이동"],
		["마우스 이동", "둘러보기"],
		["Shift", "달리기"],
		["마우스 왼쪽", "주먹질 · 들고 있는 물건 던지기"],
		["E", "물건 집기 · 내려놓기"],
		["Q", "발차기"],
		["F", "양손으로 책상 내려치기"],
		["R", "새 판 시작"],
		["Esc", "일시정지 · 계속하기"]
	]
	for binding: Array in controls:
		var key_label: Label = _label(str(binding[0]), 16, INK)
		key_label.custom_minimum_size.x = 150
		_controls_panel.add_child(key_label)
		var action_label: Label = _label(str(binding[1]), 16, Color("4b7472"))
		action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_controls_panel.add_child(action_label)
	_show_menu_page("settings")
	_result_panel = VBoxContainer.new()
	_result_panel.add_theme_constant_override("separation", 7)
	col.add_child(_result_panel)
	_result_chaos = _label("", 25, INK)
	_result_panel.add_child(_result_chaos)
	_result_route = _label("", 16, INK)
	_result_route.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_panel.add_child(_result_route)
	_result_total = _label("", 36, INK)
	_result_panel.add_child(_result_total)
	var result_grid: GridContainer = GridContainer.new()
	result_grid.columns = 2
	result_grid.add_theme_constant_override("h_separation", 18)
	result_grid.add_theme_constant_override("v_separation", 4)
	_result_panel.add_child(result_grid)
	var category_labels: Dictionary = {"property": "기물 피해", "care": "치료·수습 비용", "work": "노동 손실", "response": "대응 비용"}
	for category: String in SocialDamageScript.CATEGORIES:
		var name_label: Label = _label(str(category_labels[category]), 16, INK)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		result_grid.add_child(name_label)
		var amount_label: Label = _label("", 17, INK)
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		result_grid.add_child(amount_label)
		_result_values[category] = amount_label
	_result_record = _label("", 14, Color("4b7472"))
	_result_panel.add_child(_result_record)
	_result_panel.visible = false
	var divider: HSeparator = HSeparator.new()
	col.add_child(divider)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	col.add_child(actions)
	_start_button = _button("출근하기  →", ORANGE)
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_button.pressed.connect(_resume)
	actions.add_child(_start_button)
	_restart_button = _button("새 판 시작", Color("b8cec1"))
	_restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_restart_button.pressed.connect(_restart)
	actions.add_child(_restart_button)
	var quit: Button = _button("게임 종료", Color("d5d9ca"))
	quit.custom_minimum_size.y = 37
	quit.pressed.connect(func() -> void: get_tree().quit())
	col.add_child(quit)

func _tab_button(text: String, group: ButtonGroup) -> Button:
	var button: Button = _button(text, Color("d5d9ca"))
	button.custom_minimum_size.y = 38
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.button_group = group
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var background: Color = INK if state == "pressed" or state == "hover_pressed" else Color("d5d9ca")
		var tab_style: StyleBoxFlat = _style(background.lightened(0.08) if state == "hover" or state == "hover_pressed" else background, 8)
		tab_style.content_margin_top = 7
		tab_style.content_margin_bottom = 7
		button.add_theme_stylebox_override(state, tab_style)
	button.add_theme_color_override("font_pressed_color", CREAM)
	button.add_theme_color_override("font_hover_pressed_color", CREAM)
	return button

func _show_menu_page(page: String) -> void:
	var show_controls: bool = page == "controls"
	_options_panel.visible = not show_controls
	_controls_panel.visible = show_controls
	_settings_button.set_pressed_no_signal(not show_controls)
	_controls_button.set_pressed_no_signal(show_controls)

func _button(text: String, color: Color) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 49
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_stylebox_override("normal", _style(color, 9))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.12), 9))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.08), 9))
	return button

func _add_option(parent: VBoxContainer, caption: String, low: float, high: float, current: float, callback: Callable) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size.y = 32
	parent.add_child(row)
	var label: Label = _label(caption, 16, INK)
	label.custom_minimum_size.x = 150
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = (high - low) / 100.0
	slider.value = current
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	row.add_child(slider)

func _save_option(key: String, value: float) -> void:
	_settings.set_value("options", key, value)
	if not _automated_run:
		_settings.save("user://settings.cfg")

func _open_menu(first: bool) -> void:
	if is_instance_valid(police_arrival):
		police_arrival.cancel()
	_menu.visible = true
	_hud.visible = false
	player.set_active(false)
	get_tree().paused = not first
	_restart_button.visible = not first
	_start_button.visible = not ended
	_result_panel.visible = ended
	_menu_tabs.visible = not ended
	_menu_pages.visible = not ended
	if not ended:
		_show_menu_page("settings")
	var menu_height: float = 580.0 if ended else 620.0
	_centered(_menu_card, -menu_height * 0.5, 652.0, menu_height)
	if not first and not ended:
		_menu_title.text = "잠깐 쉬어갑니다"
		_menu_subtitle.text = "다시 들어가면 하던 상황이 이어집니다."
		_start_button.text = "계속하기  →"

func _resume() -> void:
	playing = true
	_menu.visible = false
	_hud.visible = true
	get_tree().paused = false
	player.set_active(true)

func _restart() -> void:
	if _restarting:
		return
	_restarting = true
	police_arrival.cancel()
	world.events.frozen = true
	world.office_route.finish()
	chaos.freeze()
	get_tree().paused = false
	player.set_active(false)
	get_tree().reload_current_scene.call_deferred()

func _set_focus(text: String) -> void:
	if is_instance_valid(_focus_label):
		_focus_label.text = text
		_focus_label.visible = not text.is_empty()

func _on_action(kind: String, _at: Vector3) -> void:
	sound.play(kind)

func _slam(origin: Vector3) -> void:
	if world.slam_desk(origin):
		player.confirm_desk_slam()
		sound.play("slam")
		player.add_shake(1.0)
	else:
		sound.play("swing")

func _on_impact(_kind: String, _points: int, _at: Vector3) -> void:
	# Legacy impact events still serve existing physics regressions. They carry neither
	# money nor escalation; those arrive through explicit assessment/incident signals.
	pass

func _on_damage_assessed(target_id: String, category: String, cumulative_amount: int, _label_text: String) -> void:
	if not playing or ended or get_tree().paused:
		return
	var increase: int = damage_ledger.assess(target_id, category, cumulative_amount)
	if increase <= 0:
		return
	_refresh_damage_ui()
	sound.play("score", 0.45)

func _refresh_damage_ui() -> void:
	score = damage_ledger.total()
	if is_instance_valid(_score_label):
		_score_label.text = SocialDamageScript.format_currency(score)

func _on_incident(_kind: String, weight: float, _at: Vector3) -> void:
	if not playing or ended or get_tree().paused or not is_finite(weight) or weight <= 0.0:
		return
	_first_disturbance()
	response_heat += weight
	_update_response()

func _first_disturbance() -> void:
	if disturbed or not playing or ended:
		return
	disturbed = true
	_set_phase(1)

func _update_response() -> void:
	if ended or not playing or get_tree().paused or phase >= 4:
		return
	var next_phase: int = maxi(2, phase + 1)
	if response_heat >= RESPONSE_THRESHOLDS[next_phase] and elapsed - _response_changed_at >= RESPONSE_DELAYS[next_phase]:
		# Only one step can dispatch in a frame. A deployment's monetary cost cannot
		# recursively call this path, even when its assessment is larger than the total.
		_set_phase(next_phase)

func _set_phase(value: int) -> void:
	if value <= phase or ended:
		return
	phase = clampi(value, 0, 4)
	_response_changed_at = elapsed
	world.escalate(phase)
	if phase > 1:
		world.cancel_opening_scene()
		_clear_caption()
		sound.play("alert")
		# Responder warnings use their actual speaker and proximity via ambient_dialogue.
		# No system subtitle displaces that short line or the arrival gesture.

func _speaker_available(source: Node3D, scene_only: bool = false) -> bool:
	if not is_instance_valid(source) or not source.is_inside_tree():
		return false
	if scene_only:
		return source.has_method("can_opening_react") and bool(source.call("can_opening_react"))
	# Other employees and responders have no authored opening_role, and frightened
	# people may speak while retreating. Only their live gameplay state matters here.
	return str(source.get("state")) != "down" and float(source.get("health")) > 0.0

func _ambient_caption(speaker: String, text: String, duration: float, source: Node3D) -> void:
	if not playing or ended or get_tree().paused or not _speaker_available(source):
		return
	if bool(world.get("opening_active")) or bool(world.get("boss_lecture_active")):
		return
	# A responder's one warning must remain visible even if a bystander spoke just
	# before arrival. Authored scene dialogue keeps priority over every ambient line.
	var responder: bool = str(source.get("affiliation")) == "security"
	if _caption_timer > 0.0 and (_caption_is_scene or not responder):
		return
	_caption_is_scene = false
	_caption_priority = 90 if responder else 15
	_caption_source = source
	_caption_speaker.text = speaker
	_caption_speaker.visible = true
	_caption_speaker.add_theme_color_override("font_color", Color("b6dcd0"))
	_caption_label.text = text
	_caption_label.add_theme_font_size_override("font_size", 26)
	_caption_timer = clampf(duration, 1.5, 4.0)
	_caption_panel.visible = true

func _scene_caption(speaker: String, text: String, duration: float, source: Node3D) -> void:
	if ended or not playing or get_tree().paused or not _speaker_available(source, true):
		return
	_caption_source = source
	_caption_is_scene = true
	_caption_priority = 70
	_caption_speaker.text = speaker
	_caption_speaker.visible = true
	_caption_speaker.add_theme_color_override("font_color", Color("e9c17d") if str(source.get("role")) == "boss" else Color("b6dcd0"))
	_caption_label.text = text
	_caption_label.add_theme_font_size_override("font_size", 28)
	_caption_timer = duration
	_caption_panel.visible = true

func _clear_caption() -> void:
	_caption_timer = 0.0
	_caption_is_scene = false
	_caption_priority = 0
	_caption_source = null
	if is_instance_valid(_caption_panel):
		_caption_panel.visible = false

func _invalidate_speaker(source: Node3D) -> void:
	if source == _caption_source:
		_clear_caption()

func _on_player_hit(damage: float) -> void:
	if not playing or ended or get_tree().paused:
		return
	composure = maxf(0, composure - damage)
	player.add_shake(0.7)
	sound.play("impact", 0.8)
	if composure <= 0:
		_end_run()

func _end_run() -> void:
	if ended:
		return
	ended = true
	police_arrival.cancel()
	world.office_route.finish()
	world.events.frozen = true
	chaos.freeze()
	damage_ledger.freeze()
	world.cancel_opening_scene()
	_clear_caption()
	_refresh_damage_ui()
	high_score = maxi(high_score, score)
	chaos_high_score = maxi(chaos_high_score, chaos.total())
	_settings.set_value(ChaosScript.RECORD_SECTION, ChaosScript.RECORD_KEY, chaos_high_score)
	if world.office_route.status == "resolved":
		var records: Dictionary = _settings.get_value(ChaosScript.RECORD_SECTION, ChaosScript.ROUTE_RECORD_KEY, {})
		records[world.office_route.outcome] = true
		_settings.set_value(ChaosScript.RECORD_SECTION, ChaosScript.ROUTE_RECORD_KEY, records)
	_settings.set_value(SocialDamageScript.RECORD_SECTION, SocialDamageScript.RECORD_KEY, high_score)
	if not _automated_run:
		_settings.save("user://settings.cfg")
	player.release_held()
	var categories: Dictionary = damage_ledger.breakdown()
	_result_total.text = SocialDamageScript.format_currency(score)
	for category: String in SocialDamageScript.CATEGORIES:
		var value_label: Label = _result_values[category] as Label
		value_label.text = SocialDamageScript.format_currency(int(categories[category]))
	_result_record.text = "최고 기록 %s  ·  게임 내 추산액" % SocialDamageScript.format_currency(high_score)
	var detail: Dictionary = chaos.breakdown()
	_result_chaos.text = "Chaos Score %d / 1,000 · 최고 %d" % [chaos.total(), chaos_high_score]
	var route_text: String = {"available": "미선택", "failed": "사장 행동 불능", "interrupted": "중단"}.get(world.office_route.status, "미결")
	if world.office_route.status == "resolved":
		route_text = "A · 대표자 현장 배치" if world.office_route.outcome == "A" else "B · 사장실 영업 종료"
	_result_route.text = "일반 %d · 특별 %d\n오늘의 사건: %s" % [detail.general, detail.special, route_text]
	_open_menu(false)
	_menu_title.text = "오늘 발생한 피해"
	_menu_subtitle.text = "제압되었습니다."
	_restart_button.text = "새로운 하루  →"

func _reset_run_state() -> void:
	# Scene reload also reconstructs this state. Keeping the reset explicit permits
	# checking world resets without importing an old point record into the currency.
	damage_ledger.reset()
	chaos.reset(world.events.round_id)
	police_arrival.reset_round()
	score = 0
	response_heat = 0.0
	_response_changed_at = 0.0
	phase = 0
	elapsed = 0.0
	disturbed_time = 0.0
	disturbed = false
	ended = false
	composure = 100.0
	_clear_caption()
	_result_panel.visible = false
	_refresh_damage_ui()

func _on_scenario_event(event: Dictionary) -> void:
	if playing and not ended and not get_tree().paused:
		chaos.consume(event)

func _on_responder_arrived(actor: Node3D) -> void:
	if playing and not ended:
		_clear_caption()
		var online: bool = multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer
		police_arrival.begin(player, actor.global_position, online)

func _scenario_caption(speaker: String, text: String, duration: float, source: Node3D, priority: int) -> void:
	if not playing or ended or get_tree().paused or not _speaker_available(source) or world.opening_active or world.boss_lecture_active:
		return
	if _caption_timer > 0.0 and _caption_priority >= priority:
		return
	_caption_is_scene = false
	_caption_priority = priority
	_caption_source = source
	_caption_speaker.text = speaker
	_caption_speaker.visible = true
	_caption_speaker.add_theme_color_override("font_color", Color("e9c17d"))
	_caption_label.text = text
	_caption_label.add_theme_font_size_override("font_size", 26)
	_caption_timer = duration
	_caption_panel.visible = true

func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
		push_error("SMOKE: " + message)

func _staff_count(affiliation: String) -> int:
	var count: int = 0
	for actor: Node3D in world.npcs:
		if is_instance_valid(actor) and str(actor.get("affiliation")) == affiliation:
			count += 1
	return count

func _smoke_test() -> void:
	var failures: Array[String] = []
	await get_tree().process_frame
	_resume()
	await get_tree().physics_frame
	_check(world.props.size() >= 10, "world props were not created", failures)
	_check(_staff_count("department") == 5 and _staff_count("other") == 2, "office did not create five department employees plus two other employees", failures)
	_check(not world.slam_desk(Vector3(30, 0, 30)), "out-of-reach desk accepted a slam", failures)
	_check(world.slam_desk(Vector3(0, 0.1, 1.15)), "near desk rejected a slam", failures)
	await get_tree().create_timer(2.1, false).timeout
	_check(disturbed and phase == 1 and response_heat > 0.0, "first disturbance did not update its independent response state", failures)
	_check(score > 0 and int(damage_ledger.breakdown()["work"]) > 0, "real first-slam work interruption did not reach the monetary ledger", failures)
	var saved_score: int = score
	world.slam_desk(Vector3(0, 0.1, 1.15))
	await get_tree().create_timer(0.5, false).timeout
	_check(score == saved_score, "repeat desk slam awarded a duplicate assessment", failures)
	var prop: RigidBody3D = null
	for candidate: RigidBody3D in world.props:
		if str(candidate.get("kind")) == "monitor":
			prop = candidate
			break
	_check(is_instance_valid(prop), "office monitor missing", failures)
	if is_instance_valid(prop):
		prop.call("receive_hit", Vector3.ZERO, prop.global_position, 100.0)
		_check(int(prop.get("damage_stage")) == 2 and int(damage_ledger.breakdown()["property"]) >= 300000, "real prop damage did not reach the property assessment", failures)
		prop.set_held(true)
		_check(prop.freeze and prop.collision_layer == 0, "held prop did not leave collision simulation", failures)
		prop.set_held(false)
		_check(not prop.freeze and prop.collision_layer == 2, "released prop did not return to simulation", failures)
	var phase_before_money: int = phase
	var heat_before_money: float = response_heat
	world.emit_signal("damage_assessed", "smoke-cost-only", "property", 10000000, "평가액 연결 검사")
	_check(phase == phase_before_money and response_heat == heat_before_money, "money assessment escalated the response", failures)
	world.emit_signal("incident_event", "ASSAULT", 8.0, player.global_position)
	_check(phase == 2 and _staff_count("security") == 1, "qualified incident did not dispatch the actual guard", failures)
	_check(int(damage_ledger.breakdown()["response"]) == 100000, "actual guard dispatch was not booked once", failures)
	_set_phase(3)
	_check(_staff_count("security") == 2 and int(damage_ledger.breakdown()["response"]) == 600000, "actual police dispatch did not extend the response ledger", failures)
	_on_player_hit(100)
	_check(ended and _menu.visible and get_tree().paused and damage_ledger.is_frozen(), "subdual did not freeze money and open results/pause", failures)
	var frozen_total: int = score
	world.emit_signal("damage_assessed", "after-end", "care", 300000, "종료 후 신호")
	_check(score == frozen_total, "money changed after results", failures)
	get_tree().paused = false
	world.reset_world()
	_reset_run_state()
	await get_tree().process_frame
	_check(_staff_count("department") == 5 and _staff_count("other") == 2 and _staff_count("security") == 0, "reset did not restore the intended seven employees", failures)
	_check(score == 0 and response_heat == 0.0 and phase == 0 and not damage_ledger.is_frozen(), "new-round ledger and response state were not reset", failures)
	if failures.is_empty():
		print("DESK_BREAKER_SMOKE_OK: seven employees, reach, actual work/prop/dispatch ledger, money-response separation, grab, results freeze, reset")
	else:
		print("DESK_BREAKER_SMOKE_FAILED: ", failures)
	sound.stop_all()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0 if failures.is_empty() else 1)

func _capture_demo() -> void:
	var directory: String = "user://captures"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size() - 1):
		if args[i] == "--capture-dir":
			directory = args[i + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	await get_tree().create_timer(0.5).timeout
	await _save_frame(directory.path_join("01-menu.png"))
	_resume()
	player._pitch = player.START_PITCH
	await get_tree().create_timer(0.5).timeout
	await _save_frame(directory.path_join("02-office.png"))
	player.perform_action("slam")
	await get_tree().create_timer(0.38).timeout
	await _save_frame(directory.path_join("03-slam.png"))
	await get_tree().create_timer(1.0).timeout
	await _save_frame(directory.path_join("04-reaction.png"))
	_open_menu(false)
	await _save_frame(directory.path_join("05-pause.png"))
	_resume()
	_on_player_hit(100.0)
	await _save_frame(directory.path_join("06-results.png"))
	sound.stop_all()
	await get_tree().create_timer(0.1).timeout
	print("DESK_BREAKER_CAPTURE_FAILED" if _capture_failed else "DESK_BREAKER_CAPTURE_OK: " + directory)
	get_tree().quit(1 if _capture_failed else 0)

func _save_frame(path: String) -> void:
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	var result: Error = picture.save_png(path)
	if result != OK:
		_capture_failed = true
		push_error("Capture could not be saved: " + path)

func _capture_opening(include_lecture: bool = false) -> void:
	# Automated input replay in the actual game. No substitute characters or video-only poses.
	var directory: String = "user://opening-capture"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size() - 1):
		if args[i] == "--capture-dir":
			directory = args[i + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_resume()
	player.set("_pitch", player.START_PITCH)
	player.shake_scale = 0.35
	await get_tree().create_timer(0.8, false).timeout
	await _save_frame(directory.path_join("01-working.png"))
	player.perform_action("slam")
	await get_tree().create_timer(0.9, false).timeout
	await _save_frame(directory.path_join("02-coworker.png"))
	await get_tree().create_timer(1.55, false).timeout
	await _save_frame(directory.path_join("03-boss-peek.png"))
	await get_tree().create_timer(2.0, false).timeout
	await _save_frame(directory.path_join("04-boss-approach.png"))
	# Only this automated replay turns the view to follow the approaching speaker.
	# Interactive play never takes over the player's camera.
	var saved_gestures: Dictionary = {}
	for frame: int in range(450 if include_lecture else 150):
		var boss: Node3D = world.get("opening_boss") as Node3D
		if is_instance_valid(boss):
			var direction: Vector3 = boss.global_position + Vector3(0, 1.15, 0) - player.camera.global_position
			var yaw: float = atan2(-direction.x, -direction.z)
			player.rotation.y = lerp_angle(player.rotation.y, yaw, 0.08)
			var pitch: float = atan2(direction.y, Vector2(direction.x, direction.z).length())
			player.set("_pitch", lerpf(float(player.get("_pitch")), pitch, 0.06))
		await get_tree().process_frame
		if frame == 135:
			await _save_frame(directory.path_join("05-boss-near.png"))
		if include_lecture and bool(world.get("boss_lecture_active")):
			var line_index: int = int(world.get("boss_lecture_index"))
			var beat: Dictionary = world.BOSS_LECTURE_LINES[line_index - 1]
			var line_age: float = float(beat["duration"]) - float(world.get("_boss_lecture_remaining"))
			if line_age >= 0.9 and not saved_gestures.has(line_index):
				saved_gestures[line_index] = true
				await _save_frame(directory.path_join("%02d-boss-%s.png" % [5 + line_index, str(beat["gesture"])]))
	if include_lecture:
		await _save_frame(directory.path_join("09-boss-finished.png"))
		if saved_gestures.size() != BOSS_CAPTURE_EXPECTED_GESTURES:
			_capture_failed = true
			push_error("Lecture capture did not observe all three in-game gestures.")
	sound.stop_all()
	print("DESK_BREAKER_OPENING_CAPTURE_FAILED" if _capture_failed else "DESK_BREAKER_OPENING_CAPTURE_OK: " + directory)
	get_tree().quit(1 if _capture_failed else 0)

const BOSS_CAPTURE_EXPECTED_GESTURES: int = 3

func _capture_office() -> void:
	# An opt-in real-input review replay; no camera control is used in ordinary play.
	var replay: RefCounted = load("res://scripts/office_capture.gd").new()
	await replay.run(self)
