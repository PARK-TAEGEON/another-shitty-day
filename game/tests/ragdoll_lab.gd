extends Node3D
## Playable production-model lab. 1/2/3 hits; arrows direction; R new actor.
const NPC = preload("res://scripts/office_npc.gd")
const PROP = preload("res://scripts/prop.gd")
var actor: CharacterBody3D
var camera: Camera3D
var hit_direction := Vector3(0, .12, -1)
var label: Label

func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("46505a")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("f0e2d1")
	environment.environment.ambient_light_energy = .65
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38,-28,0)
	light.shadow_enabled = true
	add_child(light)
	block(Vector3(12,.3,12), Vector3(0,-.15,0), Color("828b8d"))
	block(Vector3(1.6,.12,.75), Vector3(1.3,.9,-.5), Color("bcaa87"))
	for x: float in [.65,1.95]:
		block(Vector3(.10,.9,.65),Vector3(x,.45,-.5),Color("646a6a"))
	var chair = PROP.new()
	chair.kind = "chair"
	chair.position = Vector3(-.25,.1,-1.05)
	add_child(chair)
	camera = Camera3D.new()
	camera.position=Vector3(3.5,2.4,5)
	add_child(camera)
	camera.look_at(Vector3(0,1,0))
	camera.make_current()
	label=Label.new()
	label.position=Vector2(24,20)
	label.add_theme_font_size_override("font_size",22)
	add_child(label)
	reset_actor()

func block(size_value: Vector3, at: Vector3, tint: Color) -> void:
	var body := StaticBody3D.new()
	body.position=at
	body.collision_layer=1
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=size_value
	collision.shape=shape
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size=size_value
	mesh.mesh=box
	var material := StandardMaterial3D.new()
	material.albedo_color=tint
	mesh.material_override=material
	body.add_child(mesh)

func reset_actor() -> void:
	if is_instance_valid(actor):
		actor.queue_free()
	actor=NPC.new()
	actor.role="boss"
	actor.use_kim_rig=true
	actor.position=Vector3(0,.02,0)
	add_child(actor)
	label.text="KIM / production GLB + Jolt\n1 Light   2 Medium   3 Heavy   R Reset\nArrows: front / side / back hit"

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.keycode == KEY_R:
		reset_actor()
	elif event.keycode in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
		hit_direction = {KEY_UP:Vector3(0,.12,-1),KEY_DOWN:Vector3(0,.12,1),KEY_LEFT:Vector3(-1,.12,0),KEY_RIGHT:Vector3(1,.12,0)}[event.keycode]
	elif event.keycode in [KEY_1,KEY_2,KEY_3]:
		var power: float = {KEY_1:7.0,KEY_2:9.0,KEY_3:13.0}[event.keycode]
		var point: Vector3 = actor._rig_adapter.pelvis_position() if actor.state == "down" else actor.global_position+Vector3(0,1.4,0)
		actor.receive_hit(hit_direction.normalized()*power,point,20 if power<11 else 28)
