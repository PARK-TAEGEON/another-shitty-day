extends HBoxContainer
## Five wanted stars. Halves 0–6 fill the first three; the last two stay empty.

const INK := Color("1c1a18")
const CREAM := Color("fff4dc")
const ORANGE := Color("f08a3e")
var star_px: float = 40.0
var gap: int = 4
var shake_host: Control
var _clips: Array[Control] = []
var _bases: Array[Vector2] = []
var _shown: int = 0
var _shake_origin: Vector2 = Vector2.ZERO
var _shake_ready: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", gap)
	for index: int in range(5):
		add_child(_make_star())
	# Keep the row at the stars' own size. A parent panel must not be what
	# centers them by stretching this box and leaving the stars on the left.
	var row_size := Vector2(5.0 * star_px + 4.0 * float(gap), star_px)
	custom_minimum_size = row_size
	size = row_size
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

func set_rest_position(at: Vector2) -> void:
	_shake_origin = at
	_shake_ready = true

func set_halves(next: int, animate: bool) -> void:
	next = clampi(next, 0, 6)
	if next == _shown:
		return
	var previous: int = _shown
	_shown = next
	for index: int in range(_clips.size()):
		var clip: Control = _clips[index]
		var was_on: bool = index < previous
		var now_on: bool = index < next
		if now_on and not was_on:
			if animate:
				_stamp(clip, index)
			else:
				_settle(clip, index)
		elif was_on and not now_on:
			if animate:
				_fly_off(clip, index)
			else:
				_hide(clip, index)
		elif now_on:
			_settle(clip, index)
		else:
			_hide(clip, index)
	if animate and next > previous and is_instance_valid(shake_host):
		_shake()

func _make_star() -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(star_px, star_px)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var empty := StarGlyph.new()
	empty.filled = false
	empty.draw_scale = star_px / 40.0
	empty.position = Vector2.ZERO
	empty.size = Vector2(star_px, star_px)
	empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(empty)
	for side: int in range(2):
		var clip := Control.new()
		clip.position = Vector2(star_px * 0.5 * float(side), 0)
		clip.size = Vector2(star_px * 0.5, star_px)
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.pivot_offset = Vector2(0.0 if side == 1 else star_px * 0.5, star_px * 0.55)
		root.add_child(clip)
		var fill := StarGlyph.new()
		fill.filled = true
		fill.draw_scale = star_px / 40.0
		fill.position = Vector2(-star_px * 0.5 * float(side), 0)
		fill.size = Vector2(star_px, star_px)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.add_child(fill)
		clip.modulate.a = 0.0
		clip.visible = false
		_bases.append(clip.position)
		_clips.append(clip)
	return root

func _kill(clip: Control) -> void:
	if clip.has_meta("motion"):
		var existing: Variant = clip.get_meta("motion")
		if existing is Tween and (existing as Tween).is_valid():
			(existing as Tween).kill()

func _stamp(clip: Control, index: int) -> void:
	_kill(clip)
	clip.visible = true
	clip.position = _bases[index]
	clip.scale = Vector2(2.6, 2.6)
	clip.rotation = deg_to_rad(-30.0)
	clip.modulate.a = 0.0
	var motion := create_tween()
	motion.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	clip.set_meta("motion", motion)
	motion.tween_property(clip, "scale", Vector2(0.82, 0.82), 0.11)
	motion.parallel().tween_property(clip, "rotation", 0.0, 0.11)
	motion.parallel().tween_property(clip, "modulate:a", 1.0, 0.11)
	motion.tween_property(clip, "scale", Vector2(1.1, 1.1), 0.08)
	motion.tween_property(clip, "scale", Vector2.ONE, 0.08)

func _fly_off(clip: Control, index: int) -> void:
	_kill(clip)
	clip.visible = true
	clip.position = _bases[index]
	clip.scale = Vector2.ONE
	clip.rotation = 0.0
	clip.modulate.a = 1.0
	var motion := create_tween()
	motion.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	clip.set_meta("motion", motion)
	motion.tween_property(clip, "scale", Vector2(1.25, 1.25), 0.09)
	motion.parallel().tween_property(clip, "rotation", deg_to_rad(-6.0), 0.09)
	motion.tween_property(clip, "scale", Vector2(0.3, 0.3), 0.15)
	motion.parallel().tween_property(clip, "rotation", deg_to_rad(35.0), 0.15)
	motion.parallel().tween_property(clip, "modulate:a", 0.0, 0.15)
	motion.parallel().tween_property(clip, "position", _bases[index] + Vector2(10, -14), 0.15)
	motion.tween_callback(_hide.bind(clip, index))

func _settle(clip: Control, index: int) -> void:
	_kill(clip)
	clip.visible = true
	clip.position = _bases[index]
	clip.scale = Vector2.ONE
	clip.rotation = 0.0
	clip.modulate.a = 1.0

func _hide(clip: Control, index: int) -> void:
	_kill(clip)
	clip.visible = false
	clip.position = _bases[index]
	clip.scale = Vector2.ONE
	clip.rotation = 0.0
	clip.modulate.a = 0.0

func _shake() -> void:
	if not _shake_ready:
		_shake_origin = shake_host.position
		_shake_ready = true
	var host: Control = shake_host
	var origin: Vector2 = _shake_origin
	var motion := host.create_tween()
	motion.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	motion.tween_property(host, "position", origin + Vector2(-5, 3), 0.036)
	motion.tween_property(host, "position", origin + Vector2(4, -2), 0.036)
	motion.tween_property(host, "position", origin, 0.038)

class StarGlyph extends Control:
	var filled: bool = false
	var draw_scale: float = 1.0

	func _points() -> PackedVector2Array:
		return PackedVector2Array([
			Vector2(20, 3), Vector2(25, 14.5), Vector2(37.5, 15.5), Vector2(28, 24),
			Vector2(31, 36.5), Vector2(20, 30), Vector2(9, 36.5), Vector2(12, 24),
			Vector2(2.5, 15.5), Vector2(15, 14.5),
		])

	func _draw() -> void:
		var ink := Color("1c1a18")
		var cream := Color("fff4dc")
		var orange := Color("f08a3e")
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(draw_scale, draw_scale))
		var pts: PackedVector2Array = _points()
		var closed: PackedVector2Array = pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, cream, 7.0, true)
		draw_colored_polygon(pts, orange if filled else Color(cream.r, cream.g, cream.b, 0.3))
		draw_polyline(closed, ink, 3.0, true)
