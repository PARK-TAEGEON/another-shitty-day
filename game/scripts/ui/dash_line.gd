extends Control

func _ready() -> void:
	custom_minimum_size.y = 2
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var x: float = 0.0
	while x < size.x:
		draw_rect(Rect2(x, 0, minf(7.0, size.x - x), 2), Color("1c1a18"))
		x += 12.0
