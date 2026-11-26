extends "kim-landing.gd"

func _capture() -> void:
	if OS.get_cmdline_user_args().has("--legacy-ensemble"):
		ProjectSettings.set_setting("asd/assets/player_arms_v2_enabled", false)
		ProjectSettings.set_setting("asd/assets/office_props_v2_enabled", false)
		ProjectSettings.set_setting("asd/characters/park_visual_v2_enabled", false)
	change_scene_to_packed(MAIN)
	await scene_changed
	var game = current_scene
	kim = game.world.opening_boss
	player = game.player
	rig = kim._rig_adapter
	_watch_shoes()
	game._automated_run = true
	game._resume()
	kim._cancel_opening()
	kim.global_position = Vector3(0, 0.02, 4)
	kim.set_physics_process(false)
	player.place_at(Vector3(0, 0.02, 5.15), 0.0, -0.25)
	for i in 20:
		await process_frame
	_look_towards(kim.global_position + Vector3.UP * 1.25, 1.0)
	await process_frame
	player.perform_action("kick")
	for i in 200:
		await process_frame
	if measurements.is_empty():
		quit(1)
		return
	print("LANDING_CONTROL ", JSON.stringify({"count": measurements.size(),
		"peak_m": maxf(0.0, FLOOR_TOP_M - measurements.min()),
		"last_m": maxf(0.0, FLOOR_TOP_M - measurements[-1]),
		"pelvis_y": rig.pelvis_position().y}))
	game.sound.stop_all()
	quit(0)
