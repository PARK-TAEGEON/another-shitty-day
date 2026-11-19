extends Resource
## Tunable hit feel. Gameplay damage amounts and the dollar ledger stay elsewhere.
## Defaults keep the existing Light / Heavy impulse thresholds (punch < 8.5, kick > 11.5).
## No class_name: headless --script runs before the global class cache refreshes.

const SETTINGS_PATH := "res://resources/hit_feel.tres"
static var _cached: Resource

@export_group("Player impulse")
@export var punch_power: float = 7.0
@export var kick_power: float = 13.0
@export var punch_lift: float = 2.0
@export var kick_lift: float = 2.0

@export_group("Launch")
## Whole-torso boost, applied shortly after the ragdoll takeover so the
## existing two-frame pose check still sees the original handover.
@export var boost_delay: float = 0.08
@export var launch_speed: float = 6.2
@export var launch_up: float = 3.0
@export var max_body_speed: float = 16.0
@export var fly_joint_scale: float = 1.28
@export var procedural_launch_speed: float = 5.6
@export var procedural_launch_up: float = 2.3
@export var procedural_bounce: float = 1.7
@export var procedural_slide: float = 0.42

@export_group("Timing and camera")
@export var second_hit_window: float = 0.75
@export var hitstop_seconds: float = 0.045
@export var slowmo_scale: float = 0.36
@export var slowmo_seconds: float = 0.16
@export var shake_punch: float = 0.62
@export var shake_launch: float = 1.05
@export var shake_impact: float = 0.85

@export_group("Impact")
@export var impact_speed: float = 1.2
@export var impact_bounce: float = 0.16
@export var stagger_line: String = "꾸엑! 뭐, 뭐야!"

static func load_settings() -> Resource:
	if _cached != null:
		return _cached
	if ResourceLoader.exists(SETTINGS_PATH):
		var loaded: Resource = load(SETTINGS_PATH)
		if loaded != null and loaded.get_script() == load("res://scripts/hit_feel.gd"):
			_cached = loaded
			return _cached
	_cached = load("res://scripts/hit_feel.gd").new()
	return _cached
