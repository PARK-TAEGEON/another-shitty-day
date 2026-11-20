extends Node
## Real-time hitstop then a sub-second slow stretch. Headless runs skip this so
## physics-frame regressions keep a time_scale of 1.

var _phase: String = ""
var _until_msec: int = 0

func play(_kind: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var feel: Resource = preload("res://scripts/hit_feel.gd").load_settings()
	Engine.time_scale = 0.04
	_phase = "stop"
	_until_msec = Time.get_ticks_msec() + int(round(maxf(feel.hitstop_seconds, 0.0) * 1000.0))
	set_process(true)

func _process(_delta: float) -> void:
	if _phase == "" or Time.get_ticks_msec() < _until_msec:
		return
	var feel: Resource = preload("res://scripts/hit_feel.gd").load_settings()
	if _phase == "stop":
		_phase = "slow"
		Engine.time_scale = clampf(feel.slowmo_scale, 0.05, 1.0)
		_until_msec = Time.get_ticks_msec() + int(round(maxf(feel.slowmo_seconds, 0.0) * 1000.0))
		return
	_phase = ""
	Engine.time_scale = 1.0
	set_process(false)

func _exit_tree() -> void:
	if is_equal_approx(Engine.time_scale, 1.0):
		return
	Engine.time_scale = 1.0
