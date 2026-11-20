extends RefCounted
## Builds the 2026-11-19 comic HUD, title, pause board, and newspaper result.

const StarRowScript = preload("res://scripts/ui/star_row.gd")
const DashScript = preload("res://scripts/ui/dash_line.gd")
const PaperScript = preload("res://scripts/ui/result_paper.gd")

func build(game) -> void:
	var theme = game.theme
	var layer := CanvasLayer.new()
	layer.layer = 10
	game.add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_hud(game, root, theme)
	_menu(game, root, theme)

func _hud(game, root: Control, theme) -> void:
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	root.add_child(hud)
	game._hud = hud
	var block := Control.new()
	block.position = Vector2(24, 22)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(block)
	var card := PanelContainer.new()
	card.position = Vector2(0, 22)
	card.custom_minimum_size = Vector2(260, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", theme.flat_shadow(theme.CREAM, 14, 4, 5, 0))
	var inset: StyleBoxFlat = theme.flat_shadow(theme.CREAM, 14, 4, 5, 0)
	inset.content_margin_left = 22
	inset.content_margin_right = 22
	inset.content_margin_top = 18
	inset.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", inset)
	block.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(stack)
	var points: Label = theme.label("0", theme.jua, 52, theme.INK)
	stack.add_child(points)
	game._play_score_label = points
	stack.add_child(DashScript.new())
	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 14)
	stack.add_child(money_row)
	var caption: Label = theme.label("누적 피해액", theme.gothic_bold, 13, theme.TEAL_TEXT)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money_row.add_child(caption)
	var money: Label = theme.label("$0", theme.jua, 20, theme.INK)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_row.add_child(money)
	game._score_label = money
	var badge: PanelContainer = _chip(theme, "점수", theme.ORANGE, theme.INK, 16, 14)
	badge.position = Vector2(16, 0)
	badge.z_index = 2
	block.add_child(badge)
	# Final-HUD: 40px stars, 4px gaps, padding 12px x 8px, 24px from the right edge.
	var star_px := 40.0
	var star_gap := 4
	var pad_x := 12
	var pad_y := 8
	var row_w := 5.0 * star_px + 4.0 * float(star_gap)
	var pill_w := row_w + float(pad_x) * 2.0
	var pill_h := star_px + float(pad_y) * 2.0
	var pill := PanelContainer.new()
	pill.anchor_left = 1.0
	pill.anchor_right = 1.0
	pill.anchor_top = 0.0
	pill.offset_left = -24.0 - pill_w
	pill.offset_right = -24.0
	pill.offset_top = 26.0
	pill.offset_bottom = 26.0 + pill_h
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill_box := StyleBoxFlat.new()
	pill_box.bg_color = Color(theme.INK, 0.55)
	pill_box.set_corner_radius_all(28)
	pill_box.content_margin_left = pad_x
	pill_box.content_margin_right = pad_x
	pill_box.content_margin_top = pad_y
	pill_box.content_margin_bottom = pad_y
	pill.add_theme_stylebox_override("panel", pill_box)
	hud.add_child(pill)
	# The panel fills its one child. Keep the stars in a plain control so the
	# row can sit in the middle, and so the stamp shake does not move the pill.
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(holder)
	var stars = StarRowScript.new()
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(stars)
	stars.shake_host = stars
	var center_stars := func() -> void:
		var row := stars as Control
		var at := (holder.size - row.size) * 0.5
		row.position = at
		row.call("set_rest_position", at)
	holder.resized.connect(center_stars)
	center_stars.call()
	game._star_row = stars
	var dot := Panel.new()
	dot.anchor_left = 0.5
	dot.anchor_right = 0.5
	dot.anchor_top = 0.5
	dot.anchor_bottom = 0.5
	dot.offset_left = -6
	dot.offset_right = 6
	dot.offset_top = -6
	dot.offset_bottom = 6
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot_box := StyleBoxFlat.new()
	dot_box.bg_color = theme.WHITE
	dot_box.set_corner_radius_all(6)
	dot_box.border_color = theme.INK
	dot_box.set_border_width_all(2)
	dot.add_theme_stylebox_override("panel", dot_box)
	hud.add_child(dot)
	var focus_host := Control.new()
	focus_host.anchor_left = 0.5
	focus_host.anchor_right = 0.5
	focus_host.offset_left = -280
	focus_host.offset_right = 280
	focus_host.offset_top = 392
	focus_host.offset_bottom = 434
	focus_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_host.visible = false
	hud.add_child(focus_host)
	var focus_center := CenterContainer.new()
	focus_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_host.add_child(focus_center)
	var focus := PanelContainer.new()
	focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus.add_theme_stylebox_override("panel", theme.flat_shadow(theme.WHITE, 18, 3, 0, 0))
	var focus_style: StyleBoxFlat = theme.flat_shadow(theme.WHITE, 18, 3, 0, 0)
	focus_style.shadow_size = 0
	focus_style.content_margin_left = 14
	focus_style.content_margin_right = 14
	focus_style.content_margin_top = 4
	focus_style.content_margin_bottom = 4
	focus.add_theme_stylebox_override("panel", focus_style)
	focus_center.add_child(focus)
	var focus_row := HBoxContainer.new()
	focus_row.add_theme_constant_override("separation", 8)
	focus_row.alignment = BoxContainer.ALIGNMENT_CENTER
	focus.add_child(focus_row)
	var focus_name: Label = theme.label("", theme.jua, 17, theme.INK)
	focus_row.add_child(focus_name)
	var key := PanelContainer.new()
	key.custom_minimum_size = Vector2(24, 24)
	var key_box := StyleBoxFlat.new()
	key_box.bg_color = theme.ORANGE
	key_box.set_corner_radius_all(6)
	key_box.border_color = theme.INK
	key_box.set_border_width_all(2)
	key.add_theme_stylebox_override("panel", key_box)
	var key_label: Label = theme.label("E", theme.jua, 15, theme.INK)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.add_child(key_label)
	focus_row.add_child(key)
	var verb: Label = theme.label("", theme.jua, 17, theme.INK)
	focus_row.add_child(verb)
	game._focus_row = focus_host
	game._focus_label = focus_name
	game._focus_key = key
	game._focus_verb = verb
	_caption(game, hud, theme)

func _caption(game, hud: Control, theme) -> void:
	var panel := Control.new()
	panel.position = Vector2(150, 574)
	panel.custom_minimum_size = Vector2(980, 110)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	hud.add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 980
	column.add_theme_constant_override("separation", -16)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	var badge: PanelContainer = _chip(theme, "", theme.TEAL, theme.WHITE, 21, 18)
	badge.z_index = 2
	var badge_row := MarginContainer.new()
	badge_row.add_theme_constant_override("margin_left", 22)
	badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_row.add_child(badge)
	column.add_child(badge_row)
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate_box: StyleBoxFlat = theme.flat_shadow(theme.WHITE, 18, 4, 6, 0)
	plate_box.content_margin_left = 28
	plate_box.content_margin_right = 28
	plate_box.content_margin_top = 22
	plate_box.content_margin_bottom = 0
	plate.add_theme_stylebox_override("panel", plate_box)
	column.add_child(plate)
	var plate_col := VBoxContainer.new()
	plate_col.add_theme_constant_override("separation", 8)
	plate.add_child(plate_col)
	var line: Label = theme.label("", theme.jua, 34, theme.INK)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plate_col.add_child(line)
	var stripe := ColorRect.new()
	stripe.color = theme.ORANGE
	stripe.custom_minimum_size.y = 10
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate_col.add_child(stripe)
	game._caption_panel = panel
	game._caption_speaker = badge.get_child(0) as Label
	game._caption_label = line

func _menu(game, root: Control, theme) -> void:
	var menu := Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	game._menu = menu
	var shade := ColorRect.new()
	shade.color = Color(theme.INK, 0.28)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	menu.add_child(shade)
	game._shade = shade
	_title(game, menu, theme)
	_pause(game, menu, theme)
	var paper = PaperScript.new()
	paper.tokens = theme
	paper.visible = false
	menu.add_child(paper)
	game._result_root = paper
	game._result_panel = paper
	game._result_total = paper.total_label
	game._result_record = paper.record_label
	game._result_values = paper.category_labels
	game._result_points = paper.play_score_label
	paper.restart_button.pressed.connect(game._restart)
	paper.quit_button.pressed.connect(func() -> void: game.get_tree().quit())
	game._restart_button = paper.restart_button
	game._menu_card = game._title_card

func _title(game, menu: Control, theme) -> void:
	var card := PanelContainer.new()
	card.position = Vector2(64, 62)
	card.custom_minimum_size = Vector2(540, 0)
	card.rotation = deg_to_rad(-1.5)
	card.add_theme_stylebox_override("panel", theme.flat_shadow(theme.CREAM, 6, 4, 10, 0))
	var box: StyleBoxFlat = theme.flat_shadow(theme.CREAM, 6, 4, 10, 0)
	box.content_margin_left = 38
	box.content_margin_right = 38
	box.content_margin_top = 34
	box.content_margin_bottom = 34
	card.add_theme_stylebox_override("panel", box)
	card.resized.connect(func() -> void: card.pivot_offset = card.size * 0.5)
	menu.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	card.add_child(column)
	column.add_child(_chip(theme, "오늘의 사회면 블랙코미디", theme.TEAL, theme.WHITE, 18, 14))
	var title: Label = theme.label("Another\nShitty Day", theme.jua, 74, theme.ORANGE)
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", theme.INK)
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_color_override("font_shadow_color", theme.INK)
	title.add_theme_constant_override("line_spacing", -6)
	column.add_child(title)
	var subtitle: Label = theme.label("평범한 회사 운영지원팀.\n오늘도 급한 일은 전부 내 책상으로 온다.", theme.gothic_medium, 18, theme.INK)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(subtitle)
	var start: Button = theme.button("출근하기 →", true, 28, 62)
	start.pressed.connect(game._resume)
	column.add_child(start)
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 12)
	column.add_child(pair)
	var settings: Button = theme.button("설정 · 조작법", false, 19, 48)
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.pressed.connect(game._open_settings_from_title)
	pair.add_child(settings)
	var quit: Button = theme.button("게임 종료", false, 19, 48)
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit.pressed.connect(func() -> void: game.get_tree().quit())
	pair.add_child(quit)
	game._title_card = card
	game._menu_title = title
	game._menu_subtitle = subtitle
	game._start_button = start
	game._settings_button = settings
	game._controls_button = settings
	var bubble := PanelContainer.new()
	bubble.position = Vector2(804, 55)
	bubble.custom_minimum_size = Vector2(300, 0)
	var bubble_box: StyleBoxFlat = theme.flat_shadow(theme.WHITE, 28, 4, 6, 0)
	bubble_box.content_margin_left = 22
	bubble_box.content_margin_right = 22
	bubble_box.content_margin_top = 16
	bubble_box.content_margin_bottom = 16
	bubble_box.shadow_color = Color(theme.INK, 0.85)
	bubble.add_theme_stylebox_override("panel", bubble_box)
	menu.add_child(bubble)
	var said: Label = theme.label("오, 오늘은\n제시간에 끝내게?", theme.jua, 25, theme.INK)
	bubble.add_child(said)
	var tail := Panel.new()
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.size = Vector2(26, 26)
	tail.pivot_offset = Vector2(13, 13)
	tail.rotation = deg_to_rad(45)
	var tail_box := StyleBoxFlat.new()
	tail_box.bg_color = theme.WHITE
	tail_box.border_color = theme.INK
	tail_box.border_width_right = 4
	tail_box.border_width_bottom = 4
	tail.add_theme_stylebox_override("panel", tail_box)
	menu.add_child(tail)
	bubble.resized.connect(func() -> void:
		tail.position = bubble.position + Vector2(bubble.size.x - 118, bubble.size.y - 14)
	)
	var credit: Label = theme.label("— 옆자리 박 대리", theme.jua, 16, theme.CREAM)
	credit.position = Vector2(964, 168)
	credit.add_theme_constant_override("shadow_offset_x", 2)
	credit.add_theme_constant_override("shadow_offset_y", 2)
	credit.add_theme_color_override("font_shadow_color", theme.INK)
	menu.add_child(credit)
	var version: Label = theme.label("v%s · 개발 빌드" % str(ProjectSettings.get_setting("application/config/version", "0.2.2")), theme.jua, 15, theme.CREAM)
	version.anchor_left = 1.0
	version.anchor_right = 1.0
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.offset_left = -220
	version.offset_right = -26
	version.offset_top = -40
	version.offset_bottom = -20
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.add_theme_constant_override("shadow_offset_x", 2)
	version.add_theme_constant_override("shadow_offset_y", 2)
	version.add_theme_color_override("font_shadow_color", theme.INK)
	menu.add_child(version)
	game._title_bubble = bubble
	game._title_credit = credit
	game._title_version = version

func _pause(game, menu: Control, theme) -> void:
	var card := PanelContainer.new()
	card.position = Vector2(190, 46)
	card.custom_minimum_size = Vector2(900, 628)
	card.visible = false
	var box: StyleBoxFlat = theme.flat_shadow(theme.CREAM, 14, 4, 10, 0)
	box.content_margin_left = 36
	box.content_margin_right = 36
	box.content_margin_top = 22
	box.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", box)
	menu.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var heading: Label = theme.label("잠깐 숨 좀 돌리고…", theme.jua, 44, theme.ORANGE)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("outline_size", 1)
	heading.add_theme_color_override("font_outline_color", theme.INK)
	heading.add_theme_constant_override("shadow_offset_x", 3)
	heading.add_theme_constant_override("shadow_offset_y", 3)
	heading.add_theme_color_override("font_shadow_color", theme.INK)
	head.add_child(heading)
	var mark: PanelContainer = _chip(theme, "일시정지", theme.TEAL, theme.WHITE, 18, 14)
	head.add_child(mark)
	var status := PanelContainer.new()
	var status_box := StyleBoxFlat.new()
	status_box.bg_color = theme.WHITE
	status_box.set_corner_radius_all(24)
	status_box.border_color = theme.INK
	status_box.set_border_width_all(3)
	status_box.content_margin_left = 16
	status_box.content_margin_right = 16
	status_box.content_margin_top = 6
	status_box.content_margin_bottom = 6
	status.add_theme_stylebox_override("panel", status_box)
	column.add_child(status)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 12)
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status.add_child(status_row)
	var pause_points: Label = theme.label("0", theme.jua, 22, theme.INK)
	var pause_money: Label = theme.label("$0", theme.jua, 22, theme.INK)
	status_row.add_child(_pair(theme, "점수", pause_points))
	status_row.add_child(_divider(theme))
	status_row.add_child(_pair(theme, "누적 피해액", pause_money))
	status_row.add_child(_divider(theme))
	var star_wrap := HBoxContainer.new()
	star_wrap.add_theme_constant_override("separation", 8)
	star_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	star_wrap.add_child(theme.label("수배", theme.gothic_bold, 13, theme.TEAL_TEXT))
	var mini = StarRowScript.new()
	mini.star_px = 22.0
	mini.gap = 2
	star_wrap.add_child(mini)
	status_row.add_child(star_wrap)
	var pages := HBoxContainer.new()
	pages.add_theme_constant_override("separation", 18)
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(pages)
	var options := _section(theme, "설정")
	var controls := _section(theme, "조작법")
	pages.add_child(options)
	pages.add_child(controls)
	_options(game, options, theme)
	_controls(controls, theme)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	var cont: Button = theme.button("계속하기", true, 26, 58)
	cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cont.size_flags_stretch_ratio = 2.0
	cont.pressed.connect(game._resume)
	var again: Button = theme.button("새 판 시작", false, 19, 58)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(game._restart)
	var quit: Button = theme.button("게임 종료", false, 19, 58)
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit.pressed.connect(func() -> void: game.get_tree().quit())
	actions.add_child(cont)
	actions.add_child(again)
	actions.add_child(quit)
	var tabs := HBoxContainer.new()
	tabs.visible = false
	column.add_child(tabs)
	game._pause_card = card
	game._pause_heading = heading
	game._pause_badge = mark.get_child(0) as Label
	game._pause_points = pause_points
	game._pause_money = pause_money
	game._pause_stars = mini
	game._continue_button = cont
	game._menu_pages = pages
	game._options_panel = options
	game._controls_panel = controls
	game._menu_tabs = tabs

func _chip(theme, text: String, fill: Color, ink: Color, size: int, pad: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(20)
	box.border_color = theme.INK
	box.set_border_width_all(3)
	box.content_margin_left = pad
	box.content_margin_right = pad
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(theme.label(text, theme.jua, size, ink))
	return panel

func _pair(theme, caption: String, value: Label) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(theme.label(caption, theme.gothic_bold, 13, theme.TEAL_TEXT))
	row.add_child(value)
	return row

func _divider(theme) -> ColorRect:
	var rule := ColorRect.new()
	rule.color = theme.INK
	rule.custom_minimum_size = Vector2(2, 22)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule

func _section(theme, title: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 8)
	var plate := StyleBoxFlat.new()
	plate.bg_color = theme.WHITE
	plate.set_corner_radius_all(12)
	plate.border_color = theme.INK
	plate.set_border_width_all(3)
	plate.content_margin_left = 16
	plate.content_margin_right = 16
	plate.content_margin_top = 12
	plate.content_margin_bottom = 12
	var wrap := PanelContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_stylebox_override("panel", plate)
	section.add_child(theme.label(title, theme.jua, 24, theme.INK))
	section.add_child(wrap)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_child(inner)
	section.set_meta("body", inner)
	return section

func _options(game, section: VBoxContainer, theme) -> void:
	var body: VBoxContainer = section.get_meta("body")
	_slider(game, body, theme, "음량", 0.0, 1.0, game._volume, true, func(value: float) -> void:
		game._volume = value
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.001)))
		game._save_option("volume", value))
	_slider(game, body, theme, "마우스 감도", 0.001, 0.005, game.player.sensitivity, false, func(value: float) -> void:
		game.player.sensitivity = value
		game._save_option("sensitivity", value))
	_slider(game, body, theme, "화면 흔들림", 0.0, 1.0, game.player.shake_scale, true, func(value: float) -> void:
		game.player.shake_scale = value
		game._save_option("shake", value))
	var row := HBoxContainer.new()
	row.add_child(theme.label("경찰 등장", theme.jua, 16, theme.INK))
	var modes := OptionButton.new()
	modes.add_theme_font_override("font", theme.jua)
	modes.add_theme_font_size_override("font_size", 16)
	modes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item: String in ["전체", "짧게", "끄기"]:
		modes.add_item(item)
	var selected: int = clampi(int(game._settings.get_value("options", "police_intro", 0)), 0, 2)
	modes.select(selected)
	game.police_arrival.mode = ["full", "short", "off"][selected]
	modes.item_selected.connect(func(index: int) -> void:
		game.police_arrival.mode = ["full", "short", "off"][index]
		game._save_option("police_intro", index))
	row.add_child(modes)
	body.add_child(row)

func _slider(game, parent: VBoxContainer, theme, caption: String, low: float, high: float, current: float, percent: bool, callback: Callable) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	parent.add_child(block)
	var row := HBoxContainer.new()
	block.add_child(row)
	row.add_child(theme.label(caption, theme.jua, 18, theme.INK))
	var value: Label = theme.label("", theme.jua, 18, theme.INK)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = (high - low) / 100.0
	slider.value = current
	slider.custom_minimum_size.y = 22
	theme.style_slider(slider)
	var paint := func(next: float) -> void:
		value.text = "%d%%" % int(round(next * 100.0)) if percent else "%.1f" % (next * 1000.0)
	paint.call(current)
	slider.value_changed.connect(func(next: float) -> void:
		paint.call(next)
		callback.call(next))
	block.add_child(slider)

func _controls(section: VBoxContainer, theme) -> void:
	var body: VBoxContainer = section.get_meta("body")
	var rows: Array[Array] = [
		["W A S D", "이동"],
		["마우스", "둘러보기"],
		["Shift", "달리기"],
		["마우스 왼쪽", "주먹질 · 든 물건 던지기"],
		["E", "물건 집기 · 내려놓기 · 사장 붙잡기"],
		["Q", "발차기"],
		["F", "양손으로 책상 내려치기"],
		["R", "새 판 시작"],
		["Esc", "일시정지 · 계속하기"],
	]
	for index: int in range(rows.size()):
		var band := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = theme.CREAM if index % 2 == 1 else theme.WHITE
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 1
		style.content_margin_bottom = 1
		if index == 0:
			style.bg_color = theme.INK
		band.add_theme_stylebox_override("panel", style)
		var row := HBoxContainer.new()
		band.add_child(row)
		var key_color: Color = theme.CREAM if index == 0 else theme.INK
		var key: Label = theme.label(str(rows[index][0]), theme.jua, 15, key_color)
		key.custom_minimum_size.x = 118
		var action: Label = theme.label(str(rows[index][1]), theme.gothic, 14, key_color)
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(key)
		row.add_child(action)
		body.add_child(band)
