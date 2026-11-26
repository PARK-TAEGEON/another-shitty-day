extends SceneTree

func _initialize() -> void:
	verify.call_deferred()

func verify() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	var game = current_scene
	game._resume()
	var seen := {}
	var failures: Array[String] = []
	for prop in game.world.props:
		if seen.has(prop.kind) or prop.kind not in ["keyboard", "paper", "binder"]:
			continue
		seen[prop.kind] = true
		var parts: Dictionary = prop._parts
		var costs: Array = prop.DAMAGE_COSTS[prop.kind]
		var thresholds: Array = prop.DAMAGE_THRESHOLDS[prop.kind]
		for stage in [1, 2]:
			prop.receive_hit(Vector3.ZERO, prop.global_position, thresholds[stage - 1])
			var ok: bool = prop.damage_stage == stage and prop.damage_total == costs[stage - 1]
			match prop.kind:
				"keyboard":
					ok = ok and parts.has("keys") and parts["keys"][4].position.y > 0.04 and parts.body.visible == (stage == 1)
				"paper":
					ok = ok and not parts.label.visible and parts.sheets[0].visible == (stage == 1)
				"binder":
					ok = ok and is_equal_approx(parts.hinge.rotation.z, 0.44 if stage == 1 else 1.16)
			print("STATIONERY ", prop.kind, " stage=", stage, " cost=", prop.damage_total, " passed=", ok)
			if not ok:
				failures.append(prop.kind)
	game.sound.stop_all()
	await create_timer(0.12).timeout
	quit(0 if seen.size() == 3 and failures.is_empty() else 1)
