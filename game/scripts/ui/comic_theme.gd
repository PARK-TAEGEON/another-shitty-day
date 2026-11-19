extends RefCounted
## Shared comic-cut colors, OFL fonts, and flat offset styles from the 2026-11-19 boards.

const INK := Color("1c1a18")
const CREAM := Color("fff4dc")
const ORANGE := Color("f08a3e")
const TEAL := Color("2f7f7c")
const TEAL_TEXT := Color("2f6f6c")
const WHITE := Color("ffffff")
const PAPER := Color("eeeae0")
const PAPER_INK := Color("1a1a1a")
const RULE := Color("8a867d")

var jua: Font
var gothic: Font
var gothic_medium: Font
var gothic_bold: Font
var myeongjo: Font
var myeongjo_bold: Font
var fraktur: Font
var noto700: Font
var noto900: Font
var grabber: Texture2D

func _init() -> void:
	jua = load("res://assets/fonts/Jua-Regular.ttf")
	gothic = load("res://assets/fonts/GothicA1-Regular.ttf")
	gothic_medium = load("res://assets/fonts/GothicA1-Medium.ttf")
	gothic_bold = load("res://assets/fonts/GothicA1-Bold.ttf")
	myeongjo = load("res://assets/fonts/NanumMyeongjo-Regular.ttf")
	myeongjo_bold = load("res://assets/fonts/NanumMyeongjo-Bold.ttf")
	fraktur = load("res://assets/fonts/UnifrakturMaguntia-Book.ttf")
	var noto: Font = load("res://assets/fonts/NotoSerifKR-Variable.ttf")
	noto700 = _weight(noto, 700)
	noto900 = _weight(noto, 900)
	grabber = _circle_tex(18, ORANGE, INK)

func _weight(base: Font, weight: int) -> Font:
	var varied := FontVariation.new()
	varied.base_font = base
	varied.variation_opentype = {"wght": float(weight)}
	return varied

func label(text: String, font: Font, size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func flat(fill: Color, radius: int, border: int, margin: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	if border > 0:
		box.border_color = INK
		box.set_border_width_all(border)
	box.shadow_color = INK
	box.shadow_size = 1
	box.shadow_offset = Vector2(5 if border >= 4 else 4, 5 if border >= 4 else 4)
	return box

func flat_shadow(fill: Color, radius: int, border: int, shadow: int, margin: int = 0) -> StyleBoxFlat:
	var box := flat(fill, radius, border, margin)
	box.shadow_size = 1
	box.shadow_offset = Vector2(shadow, shadow)
	return box

func button(text: String, filled: bool, font_size: int, height: int) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.custom_minimum_size.y = height
	node.add_theme_font_override("font", jua)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_hover_color", INK)
	node.add_theme_color_override("font_pressed_color", INK)
	var fill := ORANGE if filled else WHITE
	var border := 4 if filled else 3
	var shadow := 5 if filled else 4
	node.add_theme_stylebox_override("normal", flat_shadow(fill, 10, border, shadow, 4))
	node.add_theme_stylebox_override("hover", flat_shadow(fill.lightened(0.08), 10, border, shadow, 4))
	node.add_theme_stylebox_override("pressed", flat_shadow(fill.darkened(0.06), 10, border, maxi(shadow - 1, 2), 4))
	node.add_theme_stylebox_override("focus", flat_shadow(fill, 10, border, shadow, 4))
	return node

func style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(INK, 0.18)
	track.set_corner_radius_all(4)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := StyleBoxFlat.new()
	fill.bg_color = ORANGE
	fill.set_corner_radius_all(4)
	fill.border_color = INK
	fill.set_border_width_all(2)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.add_theme_icon_override("grabber", grabber)
	slider.add_theme_icon_override("grabber_highlight", grabber)
	slider.add_theme_constant_override("grabber_offset", 0)

func _circle_tex(diameter: int, fill: Color, outline: Color) -> Texture2D:
	var image := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(float(diameter) * 0.5 - 0.5, float(diameter) * 0.5 - 0.5)
	var radius: float = float(diameter) * 0.5 - 0.5
	for y: int in range(diameter):
		for x: int in range(diameter):
			var distance: float = Vector2(x, y).distance_to(center)
			if distance <= radius - 1.6:
				image.set_pixel(x, y, fill)
			elif distance <= radius:
				image.set_pixel(x, y, outline)
	return ImageTexture.create_from_image(image)
