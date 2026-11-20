extends CanvasLayer
## Hidden until the player presses F8. Not part of the comic HUD.

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var feel: Resource = preload("res://scripts/hit_feel.gd").load_settings()
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(360, 0)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "타격감 튜닝  F8"
	box.add_child(title)
	var rows: Array[Array] = [
		["펀치 힘", "punch_power", 1.0, 16.0],
		["발차기 힘", "kick_power", 4.0, 20.0],
		["펀치 띄우기", "punch_lift", 0.0, 6.0],
		["발차기 띄우기", "kick_lift", 0.0, 8.0],
		["비행 거리", "flight_distance", 2.0, 6.0],
		["비행 높이", "flight_peak", 0.4, 2.4],
		["비행 시간", "flight_time", 0.35, 1.1],
		["몸 최고 속력", "max_body_speed", 6.0, 24.0],
		["관절 이완", "fly_joint_scale", 1.0, 2.0],
		["두 대째 시간(초)", "second_hit_window", 0.2, 1.4],
		["히트스톱(초)", "hitstop_seconds", 0.0, 0.12],
		["슬로모 배율", "slowmo_scale", 0.1, 1.0],
		["슬로모(초)", "slowmo_seconds", 0.0, 0.45],
		["펀치 흔들림", "shake_punch", 0.0, 2.0],
		["날아감 흔들림", "shake_launch", 0.0, 2.0],
		["충돌 흔들림", "shake_impact", 0.0, 2.0],
		["충돌 튕김", "impact_bounce", 0.0, 0.5],
	]
	for row: Array in rows:
		box.add_child(_row(feel, str(row[0]), str(row[1]), float(row[2]), float(row[3])))

func _row(feel: Resource, caption: String, property_name: String, low: float, high: float) -> HBoxContainer:
	var line := HBoxContainer.new()
	var label := Label.new()
	label.custom_minimum_size = Vector2(132, 0)
	label.text = caption
	line.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.01
	slider.value = float(feel.get(property_name))
	slider.custom_minimum_size = Vector2(150, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(slider)
	var value := Label.new()
	value.custom_minimum_size = Vector2(48, 0)
	value.text = "%.2f" % slider.value
	line.add_child(value)
	slider.value_changed.connect(func(next: float) -> void:
		feel.set(property_name, next)
		value.text = "%.2f" % next
	)
	return line
