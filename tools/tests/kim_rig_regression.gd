extends SceneTree
## New model, not E1's mannequin. Checks real Jolt motion and gameplay boundaries.
const NPC = preload("res://scripts/office_npc.gd")
const PROP = preload("res://scripts/prop.gd")
var failures: Array[String] = []
var reports: Array[Dictionary] = []
var stage: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("KIM_CHECK: "+message)

func floor_at(at: Vector3, size_value: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position=at
	body.collision_layer=1
	stage.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=size_value
	collision.shape=shape
	body.add_child(collision)
	return body

func new_actor(at: Vector3) -> CharacterBody3D:
	var actor = NPC.new()
	actor.role="boss"
	actor.use_kim_rig=true
	actor.position=at
	stage.add_child(actor)
	return actor

func step(frames: int) -> void:
	for i in range(frames):
		await physics_frame

func run() -> void:
	stage=Node3D.new()
	root.add_child(stage)
	floor_at(Vector3(0,-.15,0),Vector3(200,.3,200))
	var actor = new_actor(Vector3(0,.02,0))
	await step(5)
	check(actor._rig_adapter.skeleton.get_bone_count()==31,"31-bone rig missing")
	check(actor._rig_adapter.bodies.size()==15,"15 physical bodies missing")
	var rest_positions: Dictionary={}
	var skeleton: Skeleton3D=actor._rig_adapter.skeleton
	for i in range(skeleton.get_bone_count()):
		rest_positions[i]=skeleton.get_bone_global_pose(i).origin
	for name_value: String in ["Idle","Walk","Idle_Talking","Hit_Head","Hit_Chest","QA_Arms_Raised","QA_Knees_90","QA_Head_Turn","QA_Torso_Bend"]:
		var player: AnimationPlayer=actor._rig_adapter.animation
		player.play(name_value)
		player.advance(.2)
		for i in range(skeleton.get_bone_count()):
			var pose: Transform3D=skeleton.get_bone_global_pose(i)
			check(pose.is_finite(),name_value+" non-finite bone")
			check(absf(pose.basis.determinant()-1.0)<.01,name_value+" scale corruption")
	actor.health=100
	actor.receive_hit(Vector3(0,1,7),actor.position+Vector3(0,1.8,0),18)
	check(actor._rig_adapter.reaction=="Light" and actor.state!="down","Light unexpectedly knocked down")
	await step(60)
	check(actor._rig_adapter.reaction_time==0.0,"Light did not finish")
	actor.receive_hit(Vector3(9,1,0),actor.position+Vector3(0,1.3,0),18)
	check(actor._rig_adapter.reaction=="Medium" and actor.state!="down","Medium unexpectedly knocked down")
	await step(90)
	check(actor._rig_adapter.reaction_time==0.0,"Medium recovery did not finish")
	actor.queue_free()
	await step(2)
	var actors: Array[CharacterBody3D]=[]
	var directions: Array[Vector3]=[]
	var starts: Array[Vector3]=[]
	var max_speeds: Array[float]=[]
	var counts: Array[Dictionary]=[]
	for i in range(30):
		var a = new_actor(Vector3((i%10)*5-22, .02, (i/10)*7-10))
		var count={"care":0,"knockdown":0,"assault":0}
		a.damage_assessed.connect(func(category,total,label):
			if category=="care": count.care+=1)
		a.scored.connect(func(kind,points,at):
			if kind=="KNOCKDOWN": count.knockdown+=1)
		a.incident.connect(func(kind,weight,at):
			if kind=="ASSAULT": count.assault+=1)
		counts.append(count)
		actors.append(a)
		directions.append([Vector3(0,.15,1),Vector3(1,.15,0),Vector3(0,.15,-1)][i/10])
		starts.append(a.position)
		max_speeds.append(0)
	await step(5)
	for i in range(actors.size()):
		actors[i].receive_hit(directions[i].normalized()*13,actors[i].global_position+Vector3(0,1.4,0),28)
	await step(2)
	for i in range(actors.size()):
		var a=actors[i]
		check(a.collision_layer==0 and a._collision.disabled,"root capsule still active")
		check(a._rig_adapter.takeover_error<.001,"takeover teleport")
		check(a._down_rotation==0,"legacy down animation ran")
		check(a._rig_adapter.physics_impulses==1,"initial impulse duplicate")
	for f in range(300):
		await physics_frame
		for i in range(actors.size()):
			var rig=actors[i]._rig_adapter
			for body: PhysicalBone3D in rig.bodies:
				max_speeds[i]=maxf(max_speeds[i],body.linear_velocity.length())
				check(body.global_position.is_finite() and body.linear_velocity.is_finite(),"physics nonfinite")
				check(body.global_position.y>-.35,"floor penetration "+body.bone_name)
	for i in range(actors.size()):
		var a=actors[i]
		var rig=a._rig_adapter
		var pelvis: Vector3=rig.pelvis_position()
		var travel: Vector3=pelvis-starts[i]
		var spread: float=0
		for b: PhysicalBone3D in rig.bodies:spread=maxf(spread,b.global_position.distance_to(pelvis))
		check(pelvis.y<.65,"pelvis failed to fall")
		check(travel.dot(Vector3(directions[i].x,0,directions[i].z))>.05,"wrong directional travel")
		check(max_speeds[i]<30 and spread<2.5,"ragdoll explosion")
		check(counts[i].care==1 and counts[i].knockdown==1 and counts[i].assault==1,"duplicate initial events")
		var pose_updates: int=rig.pose_updates
		for repeat in range(3):rig.bodies[0].receive_hit(directions[i]*7,pelvis,20)
		check(counts[i].care==1 and counts[i].knockdown==1 and counts[i].assault==1,"repeat hit rebilled")
		check(rig.pose_updates==pose_updates and rig.physics_impulses==4,"repeat physical hit ownership")
		reports.append({"trial":i,"direction":str(directions[i]),"pelvis_height":pelvis.y,"travel":travel.length(),"max_speed":max_speeds[i],"spread":spread,"events":counts[i]})
	# Production chair contact, with a table/wall blocking the heavy fall.
	var furniture_actor=new_actor(Vector3(-5,.02,25))
	var chair=PROP.new()
	chair.kind="chair"
	chair.position=Vector3(-5,.1,25.65)
	stage.add_child(chair)
	var contact={"physical_bone":false}
	chair.body_entered.connect(func(body):
		if body is PhysicalBone3D:contact.physical_bone=true)
	floor_at(Vector3(-5,.65,26.5),Vector3(2,.15,.8))
	await step(15)
	var chair_start: Vector3=chair.position
	furniture_actor.receive_hit(Vector3(0,2,13),Vector3(-5,1.35,25),28)
	await step(240)
	check(contact.physical_bone,"chair had no real PhysicalBone contact")
	check(chair.position.distance_to(chair_start)>.02,"chair failed to move")
	reports.append({"furniture_contact":contact.physical_bone,"chair_travel":chair.position.distance_to(chair_start)})
	var args=OS.get_cmdline_user_args()
	if "--report" in args:
		var path=args[args.find("--report")+1]
		var file=FileAccess.open(path,FileAccess.WRITE)
		file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"trials":reports,"failures":failures},"\t"))
	if failures.is_empty():print("KIM_RIG_REGRESSION_OK: 30 directional falls, 3 hit tiers, chair contact, accounting")
	quit(0 if failures.is_empty() else 1)
