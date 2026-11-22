extends Node
## Timed evidence scene. The Office child is the normal playable main scene.
var game
var p
var t := 0
var stage := ""
var caption: Label
var out := ""
var errors: Array[String] = []
var contacts: Array[Dictionary] = []
var events: Array[String] = []
var measured := {}
var mug
var active := false

func _enter_tree() -> void:
	get_tree().root.set_meta("rig_slice", true)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	game = $Office
	p = game.player
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			out = arg.trim_prefix("--capture=")
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out)
	game._automated_run = true
	game._resume()
	# Keep NPC dialogue clear of the hand contact during review playback.
	game._caption_panel.position.y = 67
	game.police_arrival.mode = "off"
	p.desk_requested.connect(_contact)
	p.action_performed.connect(func(kind, _point): events.append(kind))
	for item in game.world.props:
		if item.kind == "mug":
			mug = item
			break
	var overlay := CanvasLayer.new()
	overlay.layer = 110
	add_child(overlay)
	caption = Label.new()
	overlay.add_child(caption)
	caption.position = Vector2(466, 20)
	caption.add_theme_font_size_override("font_size", 21)
	caption.add_theme_constant_override("outline_size", 6)
	active = true

func _check(ok: bool, why: String) -> void:
	if not ok:
		errors.append(why)
		push_error(why)

func _contact(_origin) -> void:
	var minima := []
	var impact_points := []
	for arm in [p._left,p._right]:
		var low := INF
		var surface := Vector3.ZERO
		for v in arm.sample_skin(true):
			var world_point: Vector3=arm.to_global(v)
			if world_point.y<low:
				surface=v
				low=world_point.y
		minima.append(low)
		var impact: Vector3=arm.to_global(surface)
		impact_points.append([impact.x,impact.y,impact.z])
		_check(surface.x * (-1.0 if arm==p._left else 1.0)>0.015,"ulnar side leads")
		_check(absf(impact.x)<1.3 and absf(impact.z+0.5)<0.65,"contact within desk top")
		_check(absf(low - 1.062)<.004,"desk clearance on " + str(p._slam_variant) + " " + str(low))
	contacts.append({"variant":p._slam_variant,"seconds":p._anim_duration-p._anim,"skin_y":minima,"points":impact_points})

func _stage(s: String) -> void:
	stage=s
	caption.text=s

func _set_mug() -> void:
	mug.freeze=true
	mug.global_basis=Basis.IDENTITY
	mug.linear_velocity=Vector3.ZERO
	mug.angular_velocity=Vector3.ZERO
	mug.global_position=p.camera.to_global(Vector3(0,0,-.65))
	mug.reset_physics_interpolation()

func _process(_delta: float) -> void:
	if not active:return
	t+=1
	match t:
		1: _stage("01    GUARD")
		27: _stage("02    RIGHT PUNCH")
		33: p.perform_action("punch")
		54: _stage("03    DESK SLAM   /   B")
		61: p.perform_action("slam")
		95: _stage("04    REPEAT   /   A")
		101: p.perform_action("slam")
		135: _stage("05    OPEN   /   LOOSE   /   CLOSED")
		202: _stage("06    MUG   /   PICK UP")
		204,249: _set_mug()
		209,254:
			p._pickup_or_drop()
			_check(p.held_prop==mug,"mug pickup")
		231:
			_stage("07    RELEASE")
			p._pickup_or_drop()
			_check(p.held_prop==null,"mug release")
		275:
			_stage("08    THROW")
			p.perform_action("throw")
			_check(p.held_prop==null,"mug throw")
	if t>=135 and t<202:
		var grip := 0.38 * smoothstep(148.0, 159.0, t)
		grip += 0.62 * smoothstep(174.0, 188.0, t)
		p._left.set_grip(grip)
		p._right.set_grip(grip)
	if t in [20,147,169,193]:
		var label_name: String = {20:"guard",147:"open",169:"loose",193:"fist"}[t]
		var tips: Array = []
		for arm in [p._left,p._right]:
			var sk: Skeleton3D=arm.skeleton
			var id := -1
			for i in sk.get_bone_count():
				if sk.get_bone_name(i).begins_with("Index3"):
					id=i
			var tip:=sk.get_bone_global_pose(id).origin
			tips.append([tip.x,tip.y,tip.z])
		measured[label_name]=tips
		if t==20:
			var wrists: Array=[]
			for arm in [p._left,p._right]:
				var pixel: Vector2=p.camera.unproject_position(arm.global_position)
				wrists.append([pixel.x,pixel.y])
			measured["wrist_pixels"]=wrists
		if t==193:
			for side in 2:
				_check(absf(measured["open"][side][1]-tips[side][1])>.05,"index flexion on side "+str(side))
			_check(absf(tips[0][1]-tips[1][1])<.001,"mirrored fist symmetry")
	if t==225:
		var closest:=INF
		var deepest:=0.0
		var closest_handle_surface:=INF
		for point in p._right.sample_skin(true):
			var local: Vector3=mug.to_local(p._right.to_global(point))
			var d:=Vector3(local.x-.154,local.y-clampf(local.y,-.060,.060),local.z).length()
			closest=minf(closest,d)
			for part in [[Vector3(.154,0,0),Vector3(.0175,.06,.0175)], [Vector3(.112,.06,0),Vector3(.045,.016,.0175)], [Vector3(.112,-.06,0),Vector3(.045,.016,.0175)]]:
				var extent: Vector3=(local-part[0]).abs()-part[1]
				var box_distance:=extent.max(Vector3.ZERO).length()+minf(0.0,maxf(extent.x,maxf(extent.y,extent.z)))
				deepest=minf(deepest,box_distance)
				closest_handle_surface=minf(closest_handle_surface,absf(box_distance))
			var cup_sdf:=maxf(Vector2(local.x,local.z).length()-.095,absf(local.y)-.105)
			deepest=minf(deepest,cup_sdf)
		measured["mug_min_handle_surface_distance_m"]=closest_handle_surface
		_check(closest_handle_surface<.003,"mug handle contact within 3 mm")
		measured["mug_max_sampled_penetration_m"]=-deepest
		_check(deepest>-.002,"mug grip surface penetration")
		measured["mug_min_axis_distance_m"]=closest
		_check(closest<.036,"fingers near mug handle")
	if t==301:
		active=false
		_check(contacts.size()==2 and contacts[0].variant=="B" and contacts[1].variant=="A","confirmed B then A")
		_check("swing" in events or "impact" in events,"punch event")
		var report={"measurements":measured,"contacts":contacts,"events":events,"errors":errors,"fov":p.camera.fov,"near":p.camera.near,"viewport":str(get_viewport().get_visible_rect().size)}
		print("RIG_SLICE ",JSON.stringify(report))
		if not out.is_empty():
			var file=FileAccess.open(out.path_join("events.json"),FileAccess.WRITE)
			file.store_string(JSON.stringify(report,"  "))
		get_tree().quit(0 if errors.is_empty() else 1)
		return
	if not out.is_empty():
		var frame:=t
		await RenderingServer.frame_post_draw
		var im:=get_viewport().get_texture().get_image()
		im.save_jpg(out.path_join("%04d.jpg"%frame),.91)
