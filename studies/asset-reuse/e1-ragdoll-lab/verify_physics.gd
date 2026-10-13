extends SceneTree
## E1 isolated repeatable Jolt Physics ragdoll diagnostic based on the
## Godot Foundation's ragdoll demo (MIT code, with CC BY 4.0 mannequin asset).
## CI uses a temporary checkout of the upstream demo; no third-party assets
## are committed or used in the shipping game.
##
## Run from the imported upstream demo root:
## godot --headless --path DEMO_ROOT --script res://e1_verify.gd

const RAGDOLL_SCENE := "res://characters/mannequiny_ragdoll.tscn"
const REPORT_FILE := "res://e1-physics-report.json"
const REPEATS_PER_DIRECTION := 5
const PHYSICS_FRAMES := 170
const IMPULSE_MAGNITUDE := 2.4
const PELVIS_PATH := "root/root_001/Skeleton3D/PhysicalBoneSimulator3D/Physical Bone pelvis"
const SIMULATOR_PATH := "root/root_001/Skeleton3D/PhysicalBoneSimulator3D"

func _initialize() -> void:
    call_deferred("_run")


func _finish(report: Dictionary, code: int) -> void:
    var file := FileAccess.open(REPORT_FILE, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(report, "\t") + "\n")
        file.close()
    print("E1_REPORT: ", JSON.stringify(report))
    if code != 0:
        push_error("E1 physical smoke failed. Inspect E1_REPORT and CI log.")
    quit(code)


func _run() -> void:
    var started: int = Time.get_ticks_msec()
    var report := {
        "schema": 1,
        "benchmark": "ASD-E1-official-ragdoll-demo",
        "upstream_source": "https://github.com/godotengine/godot-demo-projects/tree/master/3d/ragdoll_physics",
        "engine": Engine.get_version_info().get("string", "unknown"),
        "physics_engine": str(ProjectSettings.get_setting("physics/3d/physics_engine", "unknown")),
        "headless": true,
        "repeat_count_per_direction": REPEATS_PER_DIRECTION,
        "simulation_frames": PHYSICS_FRAMES,
        "ragdoll_count": 0,
        "valid_bone_count": 0,
        "finite_body_count": 0,
        "fallen_count": 0,
        "moved_count": 0,
        "failure_count": 0,
        "scenarios": [],
        "asset_is_shipping_dependency": false
    }

    var packed := load(RAGDOLL_SCENE) as PackedScene
    if packed == null:
        report["error"] = "Could not load official ragdoll scene"
        _finish(report, 2)
        return

    var world := Node3D.new()
    world.name = "E1TemporaryCollisionWorld"
    get_root().add_child(world)

    var ground := StaticBody3D.new()
    ground.name = "TestFloor"
    ground.position = Vector3(0.0, -0.1, 0.0)
    var ground_shape := CollisionShape3D.new()
    var ground_box := BoxShape3D.new()
    ground_box.size = Vector3(90.0, 0.2, 90.0)
    ground_shape.shape = ground_box
    ground.add_child(ground_shape)
    world.add_child(ground)

    var directions: Array[Vector3] = [Vector3.FORWARD, Vector3.LEFT, Vector3.BACK]
    var labels: Array[String] = ["front", "side", "back"]
    var samples: Array[Dictionary] = []

    for d in range(directions.size()):
        for attempt in range(REPEATS_PER_DIRECTION):
            var body := packed.instantiate() as Node3D
            if body == null:
                report["error"] = "Could not instantiate ragdoll"
                _finish(report, 2)
                return
            body.name = "E1_%s_%02d" % [labels[d], attempt]
            body.position = Vector3(float(attempt - 2) * 6.0, 3.1, float(d - 1) * 11.0)
            body.set("initial_velocity", directions[d] * IMPULSE_MAGNITUDE)
            world.add_child(body)
            var pelvis := body.get_node_or_null(PELVIS_PATH) as PhysicalBone3D
            var simulator := body.get_node_or_null(SIMULATOR_PATH) as PhysicalBoneSimulator3D
            var sample := {
                "direction": labels[d],
                "attempt": attempt,
                "body": body,
                "pelvis": pelvis,
                "simulator": simulator,
                "bone_count": simulator.get_child_count() if simulator != null else 0,
                "start": Vector3.ZERO,
                "min_y": INF,
                "max_speed": 0.0,
                "finite": true
            }
            samples.append(sample)

    report["ragdoll_count"] = samples.size()
    # Wait for the physics server to receive all ready/collision/joint state.
    for i in range(3):
        await physics_frame

    for sample in samples:
        var pelvis: PhysicalBone3D = sample["pelvis"]
        if pelvis == null:
            report["failure_count"] += 1
            continue
        sample["start"] = pelvis.global_position

    for frame in range(PHYSICS_FRAMES):
        await physics_frame
        for sample in samples:
            var pelvis: PhysicalBone3D = sample["pelvis"]
            if pelvis == null:
                continue
            var pos: Vector3 = pelvis.global_position
            if not pos.is_finite() or not pelvis.linear_velocity.is_finite():
                sample["finite"] = false
                continue
            sample["min_y"] = minf(sample["min_y"], pos.y)
            sample["max_speed"] = maxf(sample["max_speed"], pelvis.linear_velocity.length())

    for sample in samples:
        var pelvis: PhysicalBone3D = sample["pelvis"]
        var start_pos: Vector3 = sample["start"]
        var final_pos: Vector3 = pelvis.global_position if pelvis != null else Vector3.INF
        var horizontal: float = Vector2(final_pos.x - start_pos.x, final_pos.z - start_pos.z).length() if final_pos.is_finite() else -1.0
        var drop: float = start_pos.y - sample["min_y"] if sample["min_y"] != INF else -1.0
        var valid: bool = pelvis != null and sample["finite"] and final_pos.is_finite() and sample["bone_count"] >= 12 and sample["min_y"] > -0.55 and sample["max_speed"] < 100.0
        var fallen: bool = drop > 0.25
        var moved: bool = horizontal > 0.04
        if valid:
            report["finite_body_count"] += 1
        else:
            report["failure_count"] += 1
        if sample["bone_count"] >= 12:
            report["valid_bone_count"] += 1
        if fallen:
            report["fallen_count"] += 1
        if moved:
            report["moved_count"] += 1
        report["scenarios"].append({
            "direction": sample["direction"],
            "attempt": sample["attempt"],
            "bone_count": sample["bone_count"],
            "start_y": snappedf(start_pos.y, 0.001),
            "min_y": snappedf(sample["min_y"], 0.001) if sample["min_y"] != INF else null,
            "final_y": snappedf(final_pos.y, 0.001) if final_pos.is_finite() else null,
            "horizontal_travel": snappedf(horizontal, 0.001),
            "drop": snappedf(drop, 0.001),
            "max_speed": snappedf(sample["max_speed"], 0.001),
            "finite": sample["finite"],
            "passed": valid and fallen and moved
        })

    var full_pass: bool = report["ragdoll_count"] == 3 * REPEATS_PER_DIRECTION and report["finite_body_count"] == report["ragdoll_count"] and report["fallen_count"] == report["ragdoll_count"] and report["moved_count"] == report["ragdoll_count"] and report["physics_engine"] == "Jolt Physics"
    report["passed"] = full_pass
    report["duration_ms"] = Time.get_ticks_msec() - started
    _finish(report, 0 if full_pass else 2)
