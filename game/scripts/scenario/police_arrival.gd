extends Node
## A presentation of an already-spawned police officer, never a dispatch authority.
## Integration must cancel before menu/end/restart changes player input ownership.
## World physics remains live; accepted contacts are not deleted by set_active(false).
signal finished

const DURATION: float = 1.85
const FONT: Font = preload("res://assets/fonts/KoreanUI.ttf")

var presented: bool = false
var active: bool = false
var _remaining: float = 0.0
var _player: Node3D
var _previous_camera: Camera3D
var _cut_camera: Camera3D
var _player_callbacks: Dictionary = {}
var _overlay: CanvasLayer
var _title: Label
var _skip: Label
var _panel: PanelContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_overlay()
	set_process(false)
	set_process_input(false)

func begin(player: Node3D, arrival_position: Vector3, nonblocking: bool = false) -> void:
	if presented or not is_inside_tree():
		return
	presented = true
	active = true
	_remaining = DURATION
	_player = player
	_panel.visible = true
	_skip.visible = false
	set_process(true)
	# Invalid references, inactive/menu state and future multiplayer all degrade
	# to the same one-shot subtitle. They never schedule a late camera takeover.
	if nonblocking or get_tree().paused or not is_instance_valid(player) or not player.is_inside_tree():
		return
	if not _has_property(player, "enabled") or not bool(player.get("enabled")):
		return
	_previous_camera = get_viewport().get_camera_3d()
	if not is_instance_valid(_previous_camera) or not arrival_position.is_finite():
		_previous_camera = null
		return
	_player_callbacks = {
		"process": player.is_processing(),
		"physics": player.is_physics_processing(),
		"input": player.is_processing_input(),
		"unhandled": player.is_processing_unhandled_input(),
		"key": player.is_processing_unhandled_key_input(),
		"shortcut": player.is_processing_shortcut_input()
	}
	# Keep enabled and action serial intact: an already accepted asynchronous
	# attack still resolves. New input and player locomotion are suspended only.
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_input(false)
	player.set_process_unhandled_input(false)
	player.set_process_unhandled_key_input(false)
	player.set_process_shortcut_input(false)
	_cut_camera = Camera3D.new()
	_cut_camera.name = "PoliceArrivalCamera"
	_cut_camera.fov = 64.0
	_cut_camera.near = 0.08
	add_child(_cut_camera)
	# A static view inside the office entrance; no vehicle or invisible new actor.
	_cut_camera.global_position = arrival_position + Vector3(-0.85, 1.48, -2.65)
	_cut_camera.look_at(arrival_position + Vector3.UP * 1.10, Vector3.UP)
	_cut_camera.make_current()
	_skip.visible = true
	set_process_input(true)

func cancel() -> void:
	if not active:
		return
	_finish()

func reset_round() -> void:
	cancel()
	presented = false

func _process(delta: float) -> void:
	if not active:
		return
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		_finish()
		return
	_remaining = maxf(0.0, _remaining - delta)
	if _remaining <= 0.0:
		_finish()

func _input(event: InputEvent) -> void:
	if active and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		cancel()

func _finish() -> void:
	# Finalize before notifying listeners; cancel and timeout cannot restore twice.
	active = false
	_remaining = 0.0
	set_process(false)
	set_process_input(false)
	if is_instance_valid(_panel):
		_panel.visible = false
	if is_instance_valid(_cut_camera):
		# A new camera owner (results/restart/another presentation) has priority.
		if _cut_camera.is_inside_tree() and _cut_camera.get_viewport().get_camera_3d() == _cut_camera:
			if is_instance_valid(_previous_camera) and _previous_camera.is_inside_tree():
				_previous_camera.make_current()
		_cut_camera.queue_free()
	_cut_camera = null
	if is_instance_valid(_player) and _player.is_inside_tree() and not _player_callbacks.is_empty():
		_player.set_process(bool(_player_callbacks["process"]))
		_player.set_physics_process(bool(_player_callbacks["physics"]))
		_player.set_process_input(bool(_player_callbacks["input"]))
		_player.set_process_unhandled_input(bool(_player_callbacks["unhandled"]))
		_player.set_process_unhandled_key_input(bool(_player_callbacks["key"]))
		_player.set_process_shortcut_input(bool(_player_callbacks["shortcut"]))
	# Do not write enabled or mouse mode here: another owner may have ended the
	# run during the cut. A timeout must never resurrect a subdued player.
	_player_callbacks.clear()
	_player = null
	_previous_camera = null
	finished.emit()

func _exit_tree() -> void:
	cancel()

func _has_property(object: Object, property: String) -> bool:
	for item: Dictionary in object.get_property_list():
		if str(item["name"]) == property:
			return true
	return false

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "PoliceArrivalOverlay"
	_overlay.layer = 20
	add_child(_overlay)
	var layout: Control = Control.new()
	_overlay.add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	layout.add_child(_panel)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.15
	_panel.anchor_bottom = 0.15
	_panel.offset_left = -300.0
	_panel.offset_right = 300.0
	_panel.offset_bottom = 148.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("173b3fe8")
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	style.set_corner_radius_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(lines)
	_title = _label("POLICE ARRIVED!", 40, Color("f1e8d6"))
	lines.add_child(_title)
	lines.add_child(_label("경찰 도착!", 22, Color("ed805b")))
	_skip = _label("SPACE · 건너뛰기", 16, Color("f1e8d6"))
	lines.add_child(_skip)
	_panel.visible = false

func _label(value: String, size: int, tint: Color) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tint)
	return label
