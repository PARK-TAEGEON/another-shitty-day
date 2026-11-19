extends Control
## Black-and-white front page. Only the choice buttons keep the comic colors.
## The spin plays once. Tests can snap to the settled pose.

const LedgerScript = preload("res://scripts/social_damage.gd")
const HALFTONE = preload("res://shaders/halftone.gdshader")

var tokens
var paper: PanelContainer
var flash: ColorRect
var stamp: PanelContainer
var amount: Label
var buttons: Control
var total_label: Label
var category_labels: Dictionary = {}
var record_label: Label
var play_score_label: Label
var restart_button: Button
var quit_button: Button
var headline: RichTextLabel
var subhead: RichTextLabel
var column_a: RichTextLabel
var column_b: RichTextLabel
var photo: TextureRect
var _motions: Array[Tween] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

func present(copy: RefCounted, categories: Dictionary, total: int, record_text: String, points_text: String, shot: Image) -> void:
	headline.text = str(copy.headline())
	subhead.text = str(copy.subhead())
	var columns: PackedStringArray = _columns(str(copy.article(LedgerScript.format_currency(total))))
	column_a.text = columns[0]
	column_b.text = columns[1]
	var money: String = LedgerScript.format_currency(total)
	amount.text = money
	total_label.text = money
	for category: String in LedgerScript.CATEGORIES:
		(category_labels[category] as Label).text = LedgerScript.format_currency(int(categories.get(category, 0)))
	record_label.text = record_text
	play_score_label.text = "점수 %s" % points_text
	if shot != null and not shot.is_empty():
		photo.texture = ImageTexture.create_from_image(shot)
	play()

func play() -> void:
	_stop()
	paper.pivot_offset = paper.size * 0.5
	paper.scale = Vector2(0.04, 0.04)
	paper.rotation = deg_to_rad(-2520.0)
	paper.modulate.a = 0.0
	stamp.pivot_offset = stamp.size * 0.5
	stamp.scale = Vector2(2.6, 2.6)
	stamp.rotation = deg_to_rad(-10.0)
	stamp.modulate.a = 0.0
	amount.pivot_offset = Vector2(amount.size.x * 0.5, amount.size.y * 0.6)
	amount.scale = Vector2.ZERO
	buttons.position = Vector2(0, 18)
	buttons.modulate.a = 0.0
	restart_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quit_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.modulate.a = 0.0
	var spin := create_tween()
	spin.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_motions.append(spin)
	spin.tween_method(_spin_frame, 0.0, 1.0, 0.68)
	spin.tween_property(paper, "scale", Vector2.ONE, 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash()
	_stamp()
	_pop_amount()
	_raise_buttons()

func settle() -> void:
	_stop()
	paper.pivot_offset = paper.size * 0.5
	paper.scale = Vector2.ONE
	paper.rotation = deg_to_rad(-1.5)
	paper.modulate.a = 1.0
	stamp.pivot_offset = stamp.size * 0.5
	stamp.scale = Vector2.ONE
	stamp.rotation = deg_to_rad(-3.0)
	stamp.modulate.a = 1.0
	amount.scale = Vector2.ONE
	amount.modulate.a = 1.0
	buttons.position = Vector2.ZERO
	buttons.modulate.a = 1.0
	flash.modulate.a = 0.0
	restart_button.mouse_filter = Control.MOUSE_FILTER_STOP
	quit_button.mouse_filter = Control.MOUSE_FILTER_STOP

func _stop() -> void:
	for motion: Tween in _motions:
		if motion != null and motion.is_valid():
			motion.kill()
	_motions.clear()

func _spin_frame(t: float) -> void:
	var eased: float = _bezier(t, 0.2, 0.55, 0.3, 1.0)
	paper.scale = Vector2.ONE * lerpf(0.04, 1.08, eased)
	paper.rotation = deg_to_rad(lerpf(-2520.0, -1.5, eased))
	paper.modulate.a = clampf(t / 0.147, 0.0, 1.0)

func _flash() -> void:
	var motion := create_tween()
	motion.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_motions.append(motion)
	motion.tween_interval(0.65)
	motion.tween_property(flash, "modulate:a", 0.5, 0.065)
	motion.tween_property(flash, "modulate:a", 0.0, 0.265)

func _stamp() -> void:
	var motion := create_tween()
	motion.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_motions.append(motion)
	motion.tween_interval(0.91)
	motion.tween_property(stamp, "scale", Vector2(0.92, 0.92), 0.195)
	motion.parallel().tween_property(stamp, "rotation", deg_to_rad(-3.0), 0.195)
	motion.parallel().tween_property(stamp, "modulate:a", 1.0, 0.08)
	motion.tween_property(stamp, "scale", Vector2.ONE, 0.13)

func _pop_amount() -> void:
	var motion := create_tween()
	motion.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_motions.append(motion)
	motion.tween_interval(1.24)
	motion.tween_property(amount, "scale", Vector2(1.18, 1.18), 0.22)
	motion.tween_property(amount, "scale", Vector2.ONE, 0.17)

func _raise_buttons() -> void:
	var motion := create_tween()
	motion.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_motions.append(motion)
	motion.tween_interval(2.6)
	motion.tween_property(buttons, "position", Vector2.ZERO, 0.39)
	motion.parallel().tween_property(buttons, "modulate:a", 1.0, 0.39)
	motion.tween_callback(func() -> void:
		restart_button.mouse_filter = Control.MOUSE_FILTER_STOP
		quit_button.mouse_filter = Control.MOUSE_FILTER_STOP
	)

func _bezier(x: float, x1: float, y1: float, x2: float, y2: float) -> float:
	var u: float = x
	for _step: int in range(8):
		var at: float = _bez(u, x1, x2)
		var slope: float = _bez_slope(u, x1, x2)
		if absf(slope) < 0.0001:
			break
		u = clampf(u - (at - x) / slope, 0.0, 1.0)
	return _bez(u, y1, y2)

func _bez(t: float, p1: float, p2: float) -> float:
	var inv: float = 1.0 - t
	return 3.0 * inv * inv * t * p1 + 3.0 * inv * t * t * p2 + t * t * t

func _bez_slope(t: float, p1: float, p2: float) -> float:
	var inv: float = 1.0 - t
	return 3.0 * inv * inv * p1 + 6.0 * inv * t * (p2 - p1) + 3.0 * t * t * (1.0 - p2)

func _columns(text: String) -> PackedStringArray:
	var pieces: PackedStringArray = text.split(". ")
	var sentences: PackedStringArray = PackedStringArray()
	for index: int in range(pieces.size()):
		var piece: String = pieces[index]
		if index < pieces.size() - 1:
			piece += "."
		if not piece.is_empty():
			sentences.append(piece)
	if sentences.size() <= 1:
		return PackedStringArray([text, ""])
	var mid: int = int(ceil(float(sentences.size()) / 2.0))
	var left := ""
	var right := ""
	for index: int in range(sentences.size()):
		if index < mid:
			left += sentences[index] + " "
		else:
			right += sentences[index] + " "
	return PackedStringArray([left.strip_edges(), right.strip_edges()])

func _build() -> void:
	paper = PanelContainer.new()
	paper.position = Vector2(100, 30)
	paper.custom_minimum_size = Vector2(1080, 660)
	paper.size = Vector2(1080, 660)
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	var sheet := StyleBoxFlat.new()
	sheet.bg_color = tokens.PAPER
	sheet.content_margin_left = 30
	sheet.content_margin_right = 30
	sheet.content_margin_top = 14
	sheet.content_margin_bottom = 18
	sheet.shadow_color = Color(0, 0, 0, 0.45)
	sheet.shadow_size = 18
	sheet.shadow_offset = Vector2(0, 12)
	paper.add_theme_stylebox_override("panel", sheet)
	add_child(paper)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(column)
	var date := HBoxContainer.new()
	date.add_theme_constant_override("separation", 12)
	column.add_child(date)
	for bit: String in ["제1014호 · 사회", "호외 · 무료 배포", "2026년 10월 14일 (수)"]:
		var item: Label = tokens.label(bit, tokens.noto700, 12, tokens.PAPER_INK)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if bit == "호외 · 무료 배포" else (HORIZONTAL_ALIGNMENT_RIGHT if bit.begins_with("2026") else HORIZONTAL_ALIGNMENT_LEFT)
		date.add_child(item)
	var mast: Label = tokens.label("Another Shitty Day", tokens.fraktur, 60, tokens.PAPER_INK)
	mast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(mast)
	column.add_child(_rules())
	var kicker := HBoxContainer.new()
	kicker.add_theme_constant_override("separation", 14)
	kicker.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(kicker)
	stamp = PanelContainer.new()
	stamp.custom_minimum_size = Vector2(92, 42)
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stamp_box := StyleBoxFlat.new()
	stamp_box.bg_color = tokens.PAPER_INK
	stamp_box.content_margin_left = 14
	stamp_box.content_margin_right = 14
	stamp_box.content_margin_top = 4
	stamp_box.content_margin_bottom = 2
	stamp.add_theme_stylebox_override("panel", stamp_box)
	var stamp_label: Label = tokens.label("속보", tokens.noto900, 26, tokens.PAPER)
	stamp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.add_child(stamp_label)
	kicker.add_child(stamp)
	subhead = _rich(tokens.noto700, 18, tokens.PAPER_INK, 28)
	subhead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kicker.add_child(subhead)
	headline = _rich(tokens.noto900, 36, tokens.PAPER_INK, 88)
	column.add_child(headline)
	var money_line := HBoxContainer.new()
	money_line.add_theme_constant_override("separation", 10)
	column.add_child(money_line)
	var money_lead: Label = tokens.label("하루 피해", tokens.noto900, 40, tokens.PAPER_INK)
	money_line.add_child(money_lead)
	amount = tokens.label("$0", tokens.noto900, 40, tokens.PAPER_INK)
	money_line.add_child(amount)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	column.add_child(body)
	body.add_child(_photo_column())
	body.add_child(_article_column())
	body.add_child(_ledger_column())
	flash = ColorRect.new()
	flash.color = Color.WHITE
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.modulate.a = 0.0
	add_child(flash)

func _rules() -> Control:
	var rules := VBoxContainer.new()
	rules.add_theme_constant_override("separation", 2)
	rules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var thick := ColorRect.new()
	thick.color = tokens.PAPER_INK
	thick.custom_minimum_size.y = 3
	thick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var thin := ColorRect.new()
	thin.color = tokens.PAPER_INK
	thin.custom_minimum_size.y = 1
	thin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rules.add_child(thick)
	rules.add_child(thin)
	return rules

func _photo_column() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 364
	box.add_theme_constant_override("separation", 6)
	box.add_theme_constant_override("margin_right", 0)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(348, 200)
	var border := StyleBoxFlat.new()
	border.bg_color = tokens.PAPER
	border.border_color = tokens.PAPER_INK
	border.set_border_width_all(1)
	border.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", border)
	box.add_child(frame)
	photo = TextureRect.new()
	photo.custom_minimum_size = Vector2(348, 200)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var material := ShaderMaterial.new()
	material.shader = HALFTONE
	photo.material = material
	frame.add_child(photo)
	var caption: Label = tokens.label("사건 직후의 운영지원팀 사무실. /당시 화면", tokens.myeongjo, 12, tokens.PAPER_INK)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(caption)
	return _ruled(box, false, true)

func _article_column() -> Control:
	var box := HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	column_a = _rich(tokens.myeongjo, 13, tokens.PAPER_INK, 120)
	column_b = _rich(tokens.myeongjo, 13, tokens.PAPER_INK, 120)
	for side: RichTextLabel in [column_a, column_b]:
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		side.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(side)
	return _ruled(box, true, true)

func _rich(font: Font, size: int, color: Color, min_height: int) -> RichTextLabel:
	var node := RichTextLabel.new()
	node.bbcode_enabled = false
	node.scroll_active = false
	node.fit_content = false
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size = Vector2(80, min_height)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_font_override("normal_font", font)
	node.add_theme_font_size_override("normal_font_size", size)
	node.add_theme_color_override("default_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _ledger_column() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 280
	box.add_theme_constant_override("separation", 6)
	var title: Label = tokens.label("오늘 발생한 피해", tokens.noto900, 17, tokens.PAPER_INK)
	box.add_child(title)
	var underline := ColorRect.new()
	underline.color = tokens.PAPER_INK
	underline.custom_minimum_size.y = 2
	box.add_child(underline)
	var names: Dictionary = {"property": "기물 피해", "care": "치료·수습 비용", "work": "노동 손실", "response": "대응 비용"}
	for category: String in LedgerScript.CATEGORIES:
		var row := HBoxContainer.new()
		var name: Label = tokens.label(str(names[category]), tokens.myeongjo, 14, tokens.PAPER_INK)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value: Label = tokens.label("$0", tokens.myeongjo_bold, 14, tokens.PAPER_INK)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(name)
		row.add_child(value)
		box.add_child(row)
		category_labels[category] = value
		var rule := ColorRect.new()
		rule.color = tokens.PAPER_INK if category == "response" else tokens.RULE
		rule.custom_minimum_size.y = 2 if category == "response" else 1
		box.add_child(rule)
	var sum := HBoxContainer.new()
	var sum_name: Label = tokens.label("합계", tokens.noto900, 18, tokens.PAPER_INK)
	sum_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_label = tokens.label("$0", tokens.noto900, 20, tokens.PAPER_INK)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sum.add_child(sum_name)
	sum.add_child(total_label)
	box.add_child(sum)
	record_label = tokens.label("", tokens.myeongjo, 12, tokens.PAPER_INK)
	record_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(record_label)
	play_score_label = tokens.label("점수 0", tokens.myeongjo_bold, 14, tokens.PAPER_INK)
	box.add_child(play_score_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	var slot := Control.new()
	slot.custom_minimum_size.y = 112
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(slot)
	buttons = VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.position = Vector2(0, 18)
	buttons.modulate.a = 0.0
	slot.add_child(buttons)
	restart_button = tokens.button("새로운 하루 →", true, 24, 54)
	quit_button = tokens.button("게임 종료", false, 18, 44)
	restart_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quit_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.add_child(restart_button)
	buttons.add_child(quit_button)
	return _ruled(box, true, false)

func _ruled(inner: Control, left: bool, right: bool) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = tokens.PAPER_INK
	style.border_width_left = 1 if left else 0
	style.border_width_right = 1 if right else 0
	style.border_width_top = 1
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 8
	style.content_margin_bottom = 0
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(inner)
	return panel
