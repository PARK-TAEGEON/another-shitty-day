extends Node3D
## A small office, a growing disturbance, and one finite social-loss account per round.
const WorldScript = preload("res://scripts/world.gd")
const PlayerScript = preload("res://scripts/player.gd")
const SoundScript = preload("res://scripts/audio.gd")
const SocialDamageScript = preload("res://scripts/social_damage.gd")
const PlayScoreScript = preload("res://scripts/ui/play_score.gd")
const WantedScript = preload("res://scripts/ui/wanted_level.gd")
const RoundCopyScript = preload("res://scripts/ui/round_copy.gd")
const ThemeScript = preload("res://scripts/ui/comic_theme.gd")
const HudBuilderScript = preload("res://scripts/ui/hud_builder.gd")
const CeoHoldScript = preload("res://scripts/scenario/ceo_hold.gd")
const PoliceArrivalScript = preload("res://scripts/scenario/police_arrival.gd")
var ceo_hold: Node
var police_arrival: Node
var _caption_priority: int = 0
const RESPONSE_THRESHOLDS: Array[float] = [0.0, 0.0, 8.0, 18.0, 32.0]
const RESPONSE_DELAYS: Array[float] = [0.0, 0.0, 0.0, 8.0, 10.0]
const FONT = preload("res://assets/fonts/KoreanUI.ttf")
const CREAM: Color = Color("f1e8d6")
const INK: Color = Color("173b3f")
const ORANGE: Color = Color("ed805b")

var world: Node3D
var player: CharacterBody3D
var sound: Node
var damage_ledger: RefCounted = SocialDamageScript.new()
## `score` stays the dollar ledger total so existing checks keep their meaning.
## `play_score` is the separate action score and is never added to the ledger.
var score: int = 0
var play_score = PlayScoreScript.new()
var round_copy = RoundCopyScript.new()
var theme = ThemeScript.new()
var response_heat: float = 0.0
var _response_changed_at: float = 0.0
var high_score: int = 0
var composure: float = 100.0
var phase: int = 0
var elapsed: float = 0.0
var disturbed_time: float = 0.0
var disturbed: bool = false
var playing: bool = false
var ended: bool = false
var _restarting: bool = false
var _automated_run: bool = false
var _capture_failed: bool = false
var _settings: ConfigFile = ConfigFile.new()
var _volume: float = 0.7
var _caption_timer: float = 0.0
var _hud: Control
var _score_label: Label
var _focus_label: Label
var _caption_label: Label
var _caption_panel: Control
var _caption_speaker: Label
var _caption_source: Node3D
var _caption_is_scene: bool = false
var _menu: Control
var _menu_card: Control
var _menu_title: Label
var _menu_subtitle: Label
var _menu_tabs: HBoxContainer
var _menu_pages: Control
var _settings_button: Button
var _controls_button: Button
var _options_panel: VBoxContainer
var _controls_panel: VBoxContainer
var _result_panel: Control
var _result_total: Label
var _result_record: Label
var _result_values: Dictionary = {}
var _start_button: Button
var _restart_button: Button
var _star_row: Control
var _pause_stars: Control
var _pause_points: Label
var _pause_money: Label
var _pause_heading: Label
var _pause_badge: Label
var _continue_button: Button
var _play_score_label: Label
var _result_points: Label
var _title_card: Control
var _pause_card: Control
var _result_root: Control
var _shade: ColorRect
var _focus_row: Control
var _focus_key: Control
var _focus_verb: Label
var _title_bubble: Control
var _title_credit: Control
var _title_version: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_automated_run = args.has("--smoke-test") or args.has("--capture-demo") or args.has("--capture-opening") or args.has("--capture-lecture") or args.has("--capture-office") or args.has("--capture-ui") or args.has("--capture-ui-boards")
	DisplayServer.window_set_title("Another Shitty Day")
	_settings.load("user://settings.cfg")
	high_score = maxi(0, int(_settings.get_value(SocialDamageScript.RECORD_SECTION, SocialDamageScript.RECORD_KEY, 0)))
	if _automated_run:
		high_score = 0
	_volume = float(_settings.get_value("options", "volume", 0.7))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(_volume, 0.001)))
	world = WorldScript.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	player = PlayerScript.new()
	player.position = WorldScript.PLAYER_SPAWN
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.sensitivity = float(_settings.get_value("options", "sensitivity", 0.0024))
	player.shake_scale = float(_settings.get_value("options", "shake", 0.55))
	world.player_target = player
	player.office_world = world
	world.floor_changed.connect(_clear_caption)
	world.scenario_line_can_start = func(priority: int) -> bool: return _caption_timer <= 0.0 or _caption_priority < priority
	ceo_hold = CeoHoldScript.new()
	ceo_hold.holder = player
	ceo_hold.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.add_child(ceo_hold)
	player.actor_hold = ceo_hold
	world.ceo_hold = ceo_hold
	ceo_hold.grab_started.connect(func(actor: CharacterBody3D) -> void: world.begin_player_contact("actor_grab", actor))
	ceo_hold.holding_changed.connect(_on_hold_changed)
	ceo_hold.hold_motion.connect(func(actor: CharacterBody3D) -> void: world.queue_scenario_line("ceo-held-walk", actor, "회사는 가족이라도 이렇게 붙어 다니는 건 아니지.", 60))
	ceo_hold.hold_expiring.connect(func(actor: CharacterBody3D) -> void: world.queue_scenario_line("ceo-held-expiring", actor, "팔 좀 놔. 출근 체크는 했지?", 60))
	world.world_resetting.connect(ceo_hold.reset_round)
	police_arrival = PoliceArrivalScript.new()
	add_child(police_arrival)
	world.world_resetting.connect(police_arrival.reset_round)
	world.world_resetting.connect(_clear_caption)
	world.scenario_dialogue.connect(_scenario_caption)
	world.responder_arrived.connect(_on_responder_arrived)
	sound = SoundScript.new()
	add_child(sound)
	world.impact_event.connect(_on_impact)
	world.damage_assessed.connect(_on_damage_assessed)
	world.incident_event.connect(_on_incident)
	world.ambient_dialogue.connect(_ambient_caption)
	world.opening_began.connect(_clear_caption)
	world.scene_dialogue.connect(_scene_caption)
	world.scene_speaker_invalidated.connect(_invalidate_speaker)
	world.first_disturbance.connect(_first_disturbance)
	world.player_hit.connect(_on_player_hit)
	player.action_performed.connect(_on_action)
	player.activity_started.connect(world.notify_player_activity)
	player.focus_changed.connect(_set_focus)
	player.desk_requested.connect(_slam)
	player.contact_started.connect(world.begin_player_contact)
	player.contact_finished.connect(world.end_player_contact)
	_build_ui()
	_open_menu(true)
	if args.has("--smoke-test"):
		call_deferred("_smoke_test")
	elif args.has("--capture-demo"):
		call_deferred("_capture_demo")
	elif args.has("--capture-opening"):
		call_deferred("_capture_opening")
	elif args.has("--capture-lecture"):
		call_deferred("_capture_opening", true)
	elif args.has("--capture-office"):
		call_deferred("_capture_office")
	elif args.has("--capture-ui-boards"):
		call_deferred("_capture_ui_boards")

func _process(delta: float) -> void:
	if playing and not ended and not get_tree().paused:
		elapsed += delta
		if disturbed:
			disturbed_time += delta
			_update_response()
		_caption_timer = maxf(0.0, _caption_timer - delta)
		if (_caption_is_scene or _caption_source != null) and not _speaker_available(_caption_source, _caption_is_scene):
			_clear_caption()
		_caption_panel.visible = _caption_timer > 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if playing and not ended:
			if _menu.visible:
				_resume()
			else:
				_open_menu(false)
	elif event.is_action_pressed("restart") and playing:
		_restart()

func _style(background: Color, radius: int = 12, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = background
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	if border.a > 0:
		box.border_color = border
		box.set_border_width_all(1)
	return box

func _label(text: String, size: int, color: Color = CREAM) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _full(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _centered(control: Control, y: float, width: float, height: float) -> void:
	control.anchor_left = 0.5
	control.anchor_right = 0.5
	control.anchor_top = 0.5
	control.anchor_bottom = 0.5
	control.offset_left = -width * 0.5
	control.offset_right = width * 0.5
	control.offset_top = y
	control.offset_bottom = y + height

func _build_ui() -> void:
	HudBuilderScript.new().build(self)

func _save_option(key: String, value: float) -> void:
	_settings.set_value("options", key, value)
	if not _automated_run:
		_settings.save("user://settings.cfg")

func _open_menu(first: bool) -> void:
	if is_instance_valid(police_arrival):
		police_arrival.cancel()
	_menu.visible = true
	_hud.visible = false
	player.set_active(false)
	get_tree().paused = not first
	if ended:
		_show_result()
	elif first:
		_show_title()
	else:
		_show_pause_board()

func _show_title() -> void:
	_shade.color = Color(theme.INK, 0.28)
	_title_card.visible = true
	_title_bubble.visible = true
	_title_credit.visible = true
	_title_version.visible = true
	_pause_card.visible = false
	_result_root.visible = false
	_menu_card = _title_card
	_menu_pages.visible = false
	_options_panel.visible = false
	_controls_panel.visible = false
	_menu_tabs.visible = false

func _open_settings_from_title() -> void:
	_show_board("출근하기 →", "설정 · 조작법", "시작 전")

func _show_pause_board() -> void:
	_show_board("계속하기", "잠깐 숨 좀 돌리고…", "일시정지")

func _show_board(action: String, heading: String, badge: String) -> void:
	_shade.color = Color(theme.INK, 0.62)
	_title_card.visible = false
	_title_bubble.visible = false
	_title_credit.visible = false
	_title_version.visible = false
	_result_root.visible = false
	_pause_card.visible = true
	_menu_card = _pause_card
	_menu_pages.visible = true
	_options_panel.visible = true
	_controls_panel.visible = true
	_menu_tabs.visible = false
	_pause_heading.text = heading
	_pause_badge.text = badge
	_continue_button.text = action
	_refresh_damage_ui()
	_refresh_play_score_ui()
	_refresh_stars(false)

func _show_result() -> void:
	_shade.color = Color(theme.INK, 0.62)
	_title_card.visible = false
	_title_bubble.visible = false
	_title_credit.visible = false
	_title_version.visible = false
	_pause_card.visible = false
	_result_root.visible = true
	_menu_card = _result_root
	_menu_pages.visible = false
	_options_panel.visible = false
	_controls_panel.visible = false
	_menu_tabs.visible = false

func _settle_result_presentation() -> void:
	if is_instance_valid(_result_root):
		_result_root.call("settle")

func _resume() -> void:
	playing = true
	_menu.visible = false
	_hud.visible = true
	get_tree().paused = false
	player.set_active(true)

func _notification(what: int) -> void:
	# Losing window focus is the same user pause as Esc; keep the held pair.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and playing and not ended and not _automated_run and is_instance_valid(_menu) and not _menu.visible:
		_open_menu(false)

func _restart() -> void:
	if _restarting:
		return
	_restarting = true
	police_arrival.cancel()
	ceo_hold.release("restart")
	world.events.frozen = true
	get_tree().paused = false
	player.set_active(false)
	get_tree().reload_current_scene.call_deferred()

func _set_focus(text: String) -> void:
	if not is_instance_valid(_focus_label):
		return
	var mark := "  ·  E "
	var name := text
	var verb := ""
	var show_key := false
	if mark in text:
		var parts: PackedStringArray = text.split(mark, true, 1)
		name = parts[0]
		verb = parts[1] if parts.size() > 1 else ""
		show_key = true
	_focus_label.text = name
	_focus_verb.text = verb
	_focus_key.visible = show_key
	_focus_verb.visible = show_key
	_focus_row.visible = not name.is_empty()

func _on_action(kind: String, _at: Vector3) -> void:
	sound.play(kind)

func _slam(origin: Vector3) -> void:
	if world.slam_desk(origin):
		player.confirm_desk_slam()
		sound.play("slam")
		player.add_shake(1.0)
	else:
		sound.play("swing")

func _on_impact(kind: String, _points: int, _at: Vector3) -> void:
	# Legacy impact events still carry neither money nor escalation.
	# A knockdown only adds the separate action-score bonus.
	if kind != "KNOCKDOWN":
		return
	if not playing or ended or (get_tree().paused and not police_arrival.owns_world_pause()):
		return
	play_score.award_knockdown()
	_refresh_play_score_ui()

func _on_damage_assessed(target_id: String, category: String, cumulative_amount: int, _label_text: String) -> void:
	# The triggering hit can emit its incident before its care/work assessment.
	# Finish that synchronous ledger transaction when Full freezes the world.
	# A user/menu pause still rejects assessments; no new physics runs in Full.
	if not playing or ended or (get_tree().paused and not police_arrival.owns_world_pause()):
		return
	var increase: int = damage_ledger.assess(target_id, category, cumulative_amount)
	round_copy.note_label(_label_text)
	if increase <= 0:
		return
	_refresh_damage_ui()
	sound.play("score", 0.45)

func _refresh_damage_ui() -> void:
	score = damage_ledger.total()
	var money := SocialDamageScript.format_currency(score)
	if is_instance_valid(_score_label):
		_score_label.text = money
	if is_instance_valid(_pause_money):
		_pause_money.text = money

func _refresh_play_score_ui() -> void:
	var points := PlayScoreScript.format_points(play_score.total)
	if is_instance_valid(_play_score_label):
		_play_score_label.text = points
	if is_instance_valid(_pause_points):
		_pause_points.text = points

func _refresh_stars(animate: bool) -> void:
	var halves: int = WantedScript.halves_for_heat(response_heat)
	if is_instance_valid(_star_row):
		_star_row.call("set_halves", halves, animate)
	if is_instance_valid(_pause_stars):
		_pause_stars.call("set_halves", halves, false)

func _on_incident(_kind: String, weight: float, _at: Vector3) -> void:
	# A thrown object's contact may start Full before its receiver emits ASSAULT.
	# Preserve that same contact's incident; response escalation waits for resume.
	if not playing or ended or (get_tree().paused and not police_arrival.owns_world_pause()) or not is_finite(weight) or weight <= 0.0:
		return
	_first_disturbance()
	response_heat += weight
	_update_response()
	if _kind == "ASSAULT" or _kind == "THROW":
		play_score.award_hit(_kind, elapsed)
		_refresh_play_score_ui()
	_refresh_stars(true)

func _first_disturbance() -> void:
	if disturbed or not playing or ended:
		return
	disturbed = true
	_set_phase(1)

func _update_response() -> void:
	if ended or not playing or get_tree().paused or phase >= 4:
		return
	var next_phase: int = maxi(2, phase + 1)
	if response_heat >= RESPONSE_THRESHOLDS[next_phase] and elapsed - _response_changed_at >= RESPONSE_DELAYS[next_phase]:
		# Only one step can dispatch in a frame. A deployment's monetary cost cannot
		# recursively call this path, even when its assessment is larger than the total.
		_set_phase(next_phase)

func _set_phase(value: int) -> void:
	if value <= phase or ended:
		return
	phase = clampi(value, 0, 4)
	_response_changed_at = elapsed
	world.escalate(phase)
	round_copy.note_phase(phase)
	if play_score.award_stage(phase) > 0:
		_refresh_play_score_ui()
	if phase > 1:
		world.cancel_opening_scene()
		_clear_caption()
		sound.play("alert")
		# Responder warnings use their actual speaker and proximity via ambient_dialogue.
		# No system subtitle displaces that short line or the arrival gesture.

func _speaker_available(source: Node3D, scene_only: bool = false) -> bool:
	if not is_instance_valid(source) or not source.is_inside_tree():
		return false
	if world.floor_index(source.global_position) != world.floor_index(player.global_position):
		return false
	if scene_only:
		return source.has_method("can_opening_react") and bool(source.call("can_opening_react"))
	# Other employees and responders have no authored opening_role, and frightened
	# people may speak while retreating. Only their live gameplay state matters here.
	return str(source.get("state")) != "down" and float(source.get("health")) > 0.0

func _ambient_caption(speaker: String, text: String, duration: float, source: Node3D) -> void:
	if not playing or ended or get_tree().paused or not _speaker_available(source):
		return
	if bool(world.get("opening_active")) or bool(world.get("boss_lecture_active")):
		return
	# A responder's one warning must remain visible even if a bystander spoke just
	# before arrival. Authored scene dialogue keeps priority over every ambient line.
	var responder: bool = str(source.get("affiliation")) == "security"
	if _caption_timer > 0.0 and (_caption_is_scene or not responder):
		return
	_caption_is_scene = false
	_caption_priority = 90 if responder else 15
	_caption_source = source
	_caption_speaker.text = speaker
	_caption_speaker.visible = true
	_caption_label.text = text
	_caption_timer = clampf(duration, 1.5, 4.0)
	_caption_panel.visible = true

func _scene_caption(speaker: String, text: String, duration: float, source: Node3D) -> void:
	if ended or not playing or get_tree().paused or not _speaker_available(source, true):
		return
	_caption_source = source
	_caption_is_scene = true
	_caption_priority = 70
	_caption_speaker.text = speaker
	_caption_speaker.visible = true
	_caption_label.text = text
	_caption_timer = duration
	_caption_panel.visible = true

func _clear_caption() -> void:
	_caption_timer = 0.0
	_caption_is_scene = false
	_caption_priority = 0
	_caption_source = null
	if is_instance_valid(_caption_panel):
		_caption_panel.visible = false

func _invalidate_speaker(source: Node3D) -> void:
	if source == _caption_source:
		_clear_caption()

func _on_player_hit(damage: float) -> void:
	if not playing or ended or get_tree().paused:
		return
	ceo_hold.release("player_hit")
	composure = maxf(0, composure - damage)
	player.add_shake(0.7)
	sound.play("impact", 0.8)
	if composure <= 0:
		_end_run()

func _end_run() -> void:
	if ended:
		return
	ended = true
	police_arrival.cancel()
	ceo_hold.release("result")
	world.events.frozen = true
	damage_ledger.freeze()
	world.cancel_opening_scene()
	_clear_caption()
	_refresh_damage_ui()
	var previous_record: int = high_score
	high_score = maxi(high_score, score)
	_settings.set_value(SocialDamageScript.RECORD_SECTION, SocialDamageScript.RECORD_KEY, high_score)
	if not _automated_run:
		_settings.save("user://settings.cfg")
	player.release_held()
	var categories: Dictionary = damage_ledger.breakdown()
	var record_text := "최고 기록 %s%s  ·  게임 내 추산액" % [SocialDamageScript.format_currency(high_score), " (신기록)" if score > previous_record else ""]
	if is_instance_valid(_result_root):
		_result_root.call("present", round_copy, categories, score, record_text, PlayScoreScript.format_points(play_score.total), _capture_viewport())
	_open_menu(false)
	_restart_button.text = "새로운 하루 →"

func _reset_run_state() -> void:
	# Scene reload also reconstructs this state. Keeping the reset explicit permits
	# checking world resets without importing an old point record into the currency.
	damage_ledger.reset()
	ceo_hold.reset_round()
	police_arrival.reset_round()
	play_score.reset()
	round_copy.reset()
	score = 0
	response_heat = 0.0
	_response_changed_at = 0.0
	phase = 0
	elapsed = 0.0
	disturbed_time = 0.0
	disturbed = false
	ended = false
	composure = 100.0
	_clear_caption()
	_result_panel.visible = false
	_refresh_damage_ui()
	_refresh_play_score_ui()
	_refresh_stars(false)

func _on_hold_changed(actor: CharacterBody3D, held: bool, reason: String) -> void:
	if not is_instance_valid(actor) or not actor.is_inside_tree():
		return
	if held:
		world.end_player_contact("actor_grab", actor)
		world.cancel_scenario_speaker(actor)
		world.queue_scenario_line("ceo-grab-start", actor, "나 누군지 알고 이래?", 60)
	else:
		world.cancel_scenario_speaker(actor)
		if reason in ["input", "timeout"] and not ended:
			world.queue_scenario_line("ceo-grab-release", actor, "오늘 일은 인사평가에… 아니, 대화로 하자.", 60)

func _on_responder_arrived(actor: Node3D) -> void:
	if playing and not ended:
		_clear_caption()
		var online: bool = multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer
		var camera_offset: Vector3 = PoliceArrivalScript.OFFICE_CAMERA_OFFSET
		if world.floor_index(actor.global_position) == 1:
			camera_offset = Vector3(-0.30, 1.48, 2.65)
		police_arrival.begin(player, actor.global_position, online, camera_offset)

func _scenario_caption(speaker: String, text: String, duration: float, source: Node3D, priority: int) -> void:
	if not playing or ended or get_tree().paused or not _speaker_available(source) or world.opening_active or world.boss_lecture_active:
		return
	if _caption_timer > 0.0 and _caption_priority >= priority:
		return
	_caption_is_scene = false
	_caption_priority = priority
	_caption_source = source
	_caption_speaker.text = speaker
	_caption_speaker.visible = true
	_caption_label.text = text
	_caption_timer = duration
	_caption_panel.visible = true

func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
		push_error("SMOKE: " + message)

func _staff_count(affiliation: String) -> int:
	var count: int = 0
	for actor: Node3D in world.npcs:
		if is_instance_valid(actor) and str(actor.get("affiliation")) == affiliation:
			count += 1
	return count

func _smoke_test() -> void:
	var failures: Array[String] = []
	await get_tree().process_frame
	_resume()
	await get_tree().physics_frame
	_check(world.props.size() >= 10, "world props were not created", failures)
	_check(_staff_count("department") == 5 and _staff_count("other") == 2, "office did not create five department employees plus two other employees", failures)
	_check(not world.slam_desk(Vector3(30, 0, 30)), "out-of-reach desk accepted a slam", failures)
	_check(world.slam_desk(Vector3(0, 0.1, 1.15)), "near desk rejected a slam", failures)
	await get_tree().create_timer(2.1, false).timeout
	_check(disturbed and phase == 1 and response_heat > 0.0, "first disturbance did not update its independent response state", failures)
	_check(score > 0 and int(damage_ledger.breakdown()["work"]) > 0, "real first-slam work interruption did not reach the monetary ledger", failures)
	var saved_score: int = score
	world.slam_desk(Vector3(0, 0.1, 1.15))
	await get_tree().create_timer(0.5, false).timeout
	_check(score == saved_score, "repeat desk slam awarded a duplicate assessment", failures)
	var prop: RigidBody3D = null
	for candidate: RigidBody3D in world.props:
		if str(candidate.get("kind")) == "monitor":
			prop = candidate
			break
	_check(is_instance_valid(prop), "office monitor missing", failures)
	if is_instance_valid(prop):
		prop.call("receive_hit", Vector3.ZERO, prop.global_position, 100.0)
		_check(int(prop.get("damage_stage")) == 2 and int(damage_ledger.breakdown()["property"]) >= 300000, "real prop damage did not reach the property assessment", failures)
		prop.set_held(true)
		_check(prop.freeze and prop.collision_layer == 0, "held prop did not leave collision simulation", failures)
		prop.set_held(false)
		_check(not prop.freeze and prop.collision_layer == 2, "released prop did not return to simulation", failures)
	var phase_before_money: int = phase
	var heat_before_money: float = response_heat
	world.emit_signal("damage_assessed", "smoke-cost-only", "property", 10000000, "평가액 연결 검사")
	_check(phase == phase_before_money and response_heat == heat_before_money, "money assessment escalated the response", failures)
	world.emit_signal("incident_event", "ASSAULT", 8.0, player.global_position)
	_check(phase == 2 and _staff_count("security") == 1, "qualified incident did not dispatch the actual guard", failures)
	_check(int(damage_ledger.breakdown()["response"]) == 100000, "actual guard dispatch was not booked once", failures)
	_set_phase(3)
	_check(_staff_count("security") == 2 and int(damage_ledger.breakdown()["response"]) == 600000, "actual police dispatch did not extend the response ledger", failures)
	police_arrival.cancel() # The smoke's synthetic hit is a post-intro fixture.
	_on_player_hit(100)
	_check(ended and _menu.visible and get_tree().paused and damage_ledger.is_frozen(), "subdual did not freeze money and open results/pause", failures)
	var frozen_total: int = score
	world.emit_signal("damage_assessed", "after-end", "care", 300000, "종료 후 신호")
	_check(score == frozen_total, "money changed after results", failures)
	get_tree().paused = false
	world.reset_world()
	_reset_run_state()
	await get_tree().process_frame
	_check(_staff_count("department") == 5 and _staff_count("other") == 2 and _staff_count("security") == 0, "reset did not restore the intended seven employees", failures)
	_check(score == 0 and response_heat == 0.0 and phase == 0 and not damage_ledger.is_frozen(), "new-round ledger and response state were not reset", failures)
	if failures.is_empty():
		print("DESK_BREAKER_SMOKE_OK: seven employees, reach, actual work/prop/dispatch ledger, money-response separation, grab, results freeze, reset")
	else:
		print("DESK_BREAKER_SMOKE_FAILED: ", failures)
	sound.stop_all()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0 if failures.is_empty() else 1)

func _capture_demo() -> void:
	var directory: String = "user://captures"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size() - 1):
		if args[i] == "--capture-dir":
			directory = args[i + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	await get_tree().create_timer(0.5).timeout
	await _save_frame(directory.path_join("01-menu.png"))
	_resume()
	player._pitch = player.START_PITCH
	await get_tree().create_timer(0.5).timeout
	await _save_frame(directory.path_join("02-office.png"))
	player.perform_action("slam")
	await get_tree().create_timer(0.38).timeout
	await _save_frame(directory.path_join("03-slam.png"))
	await get_tree().create_timer(1.0).timeout
	await _save_frame(directory.path_join("04-reaction.png"))
	_open_menu(false)
	await _save_frame(directory.path_join("05-pause.png"))
	_resume()
	_on_player_hit(100.0)
	await _save_frame(directory.path_join("06-results.png"))
	sound.stop_all()
	await get_tree().create_timer(0.1).timeout
	print("DESK_BREAKER_CAPTURE_FAILED" if _capture_failed else "DESK_BREAKER_CAPTURE_OK: " + directory)
	get_tree().quit(1 if _capture_failed else 0)

func _save_frame(path: String) -> void:
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	var result: Error = picture.save_png(path)
	if result != OK:
		_capture_failed = true
		push_error("Capture could not be saved: " + path)

func _capture_opening(include_lecture: bool = false) -> void:
	# Automated input replay in the actual game. No substitute characters or video-only poses.
	var directory: String = "user://opening-capture"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size() - 1):
		if args[i] == "--capture-dir":
			directory = args[i + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_resume()
	player.set("_pitch", player.START_PITCH)
	player.shake_scale = 0.35
	await get_tree().create_timer(0.8, false).timeout
	await _save_frame(directory.path_join("01-working.png"))
	player.perform_action("slam")
	await get_tree().create_timer(0.9, false).timeout
	await _save_frame(directory.path_join("02-coworker.png"))
	await get_tree().create_timer(1.55, false).timeout
	await _save_frame(directory.path_join("03-boss-peek.png"))
	await get_tree().create_timer(2.0, false).timeout
	await _save_frame(directory.path_join("04-boss-approach.png"))
	# Only this automated replay turns the view to follow the approaching speaker.
	# Interactive play never takes over the player's camera.
	var saved_gestures: Dictionary = {}
	for frame: int in range(450 if include_lecture else 150):
		var boss: Node3D = world.get("opening_boss") as Node3D
		if is_instance_valid(boss):
			var direction: Vector3 = boss.global_position + Vector3(0, 1.15, 0) - player.camera.global_position
			var yaw: float = atan2(-direction.x, -direction.z)
			player.rotation.y = lerp_angle(player.rotation.y, yaw, 0.08)
			var pitch: float = atan2(direction.y, Vector2(direction.x, direction.z).length())
			player.set("_pitch", lerpf(float(player.get("_pitch")), pitch, 0.06))
		await get_tree().process_frame
		if frame == 135:
			await _save_frame(directory.path_join("05-boss-near.png"))
		if include_lecture and bool(world.get("boss_lecture_active")):
			var line_index: int = int(world.get("boss_lecture_index"))
			var beat: Dictionary = world.BOSS_LECTURE_LINES[line_index - 1]
			var line_age: float = float(beat["duration"]) - float(world.get("_boss_lecture_remaining"))
			if line_age >= 0.9 and not saved_gestures.has(line_index):
				saved_gestures[line_index] = true
				await _save_frame(directory.path_join("%02d-boss-%s.png" % [5 + line_index, str(beat["gesture"])]))
	if include_lecture:
		await _save_frame(directory.path_join("09-boss-finished.png"))
		if saved_gestures.size() != BOSS_CAPTURE_EXPECTED_GESTURES:
			_capture_failed = true
			push_error("Lecture capture did not observe all three in-game gestures.")
	sound.stop_all()
	print("DESK_BREAKER_OPENING_CAPTURE_FAILED" if _capture_failed else "DESK_BREAKER_OPENING_CAPTURE_OK: " + directory)
	get_tree().quit(1 if _capture_failed else 0)

const BOSS_CAPTURE_EXPECTED_GESTURES: int = 3

func _capture_office() -> void:
	# An opt-in real-input review replay; no camera control is used in ordinary play.
	var replay: RefCounted = load("res://scripts/office_capture.gd").new()
	await replay.run(self)

func _capture_viewport() -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return null
	return image.duplicate()

func _capture_ui_boards() -> void:
	var directory: String = "user://ui-boards"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size() - 1):
		if args[i] == "--capture-dir":
			directory = args[i + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_menu.visible = false
	_hud.visible = false
	await get_tree().create_timer(0.4, false).timeout
	await _save_frame(directory.path_join("office-bg.png"))
	_show_title()
	_menu.visible = true
	await get_tree().process_frame
	await _save_frame(directory.path_join("title.png"))
	_resume()
	await get_tree().create_timer(0.3, false).timeout
	world.emit_signal("damage_assessed", "ui-board-monitor", "property", 585000, "모니터 사용 불능")
	play_score.total = 12450
	_refresh_play_score_ui()
	response_heat = 13.0
	_refresh_stars(false)
	var boss: Node3D = world.get("opening_boss") as Node3D
	if is_instance_valid(boss):
		_scene_caption("김 팀장", "지금 뭐 하는 거야? 여기가 집이야?", 8.0, boss)
	await get_tree().process_frame
	await _save_frame(directory.path_join("hud.png"))
	_open_menu(false)
	await get_tree().process_frame
	await _save_frame(directory.path_join("pause.png"))
	_resume()
	_on_player_hit(100.0)
	# The result opens while the tree is paused, so a process timer would never elapse.
	_settle_result_presentation()
	await get_tree().process_frame
	await _save_frame(directory.path_join("result.png"))
	sound.stop_all()
	print("DESK_BREAKER_UI_BOARDS_FAILED" if _capture_failed else "DESK_BREAKER_UI_BOARDS_OK: " + directory)
	get_tree().quit(1 if _capture_failed else 0)
