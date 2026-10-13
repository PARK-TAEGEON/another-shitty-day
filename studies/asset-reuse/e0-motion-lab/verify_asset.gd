extends SceneTree
## Isolated E0 benchmark: inspect imported GLB/GLTF humanoid animations.
## Intentionally does NOT integrate or edit the production game.
##
## Run AFTER editor import:
## godot --headless --path studies/asset-reuse/e0-motion-lab --script res://verify_asset.gd

const ASSET_FOLDER := "res://third_party/ual"
const REPORT_PATH := "res://e0-import-report.json"

func _initialize() -> void:
    call_deferred("_run")


func _collect_assets(folder: String, files: Array[String]) -> void:
    var dir := DirAccess.open(folder)
    if dir == null:
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        var path := folder.path_join(name)
        if dir.current_is_dir():
            if not name.begins_with("."):
                _collect_assets(path, files)
        elif name.get_extension().to_lower() in ["glb", "gltf"]:
            files.append(path)
        name = dir.get_next()
    dir.list_dir_end()


func _collect_scene_nodes(node: Node, skeletons: Array[Skeleton3D], players: Array[AnimationPlayer], meshes: Array[MeshInstance3D]) -> void:
    if node is Skeleton3D:
        skeletons.append(node as Skeleton3D)
    if node is AnimationPlayer:
        players.append(node as AnimationPlayer)
    if node is MeshInstance3D:
        meshes.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_scene_nodes(child, skeletons, players, meshes)


func _finish(report: Dictionary, code: int) -> void:
    var text := JSON.stringify(report, "\t") + "\n"
    var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(text)
        file.close()
    print("E0_REPORT: ", JSON.stringify(report))
    if code != 0:
        push_error("E0 failed: imported rig and two playable animation clips required")
    quit(code)


func _run() -> void:
    var assets: Array[String] = []
    _collect_assets(ASSET_FOLDER, assets)
    assets.sort()

    var report := {
        "schema": 1,
        "benchmark": "ASD-E0-Quaternius-UAL-Standard",
        "engine": Engine.get_version_info().get("string", "unknown"),
        "renderer": "Compatibility",
        "source": "https://store.godotengine.org/asset/quaternius/universal-animation-library/",
        "downloaded_assets_committed": false,
        "file_count": assets.size(),
        "imported_scenes": 0,
        "skeletons": 0,
        "skinned_meshes": 0,
        "clips_found": 0,
        "clips_played": 0,
        "import_failures": [],
        "sample_clips": [],
        "sample_files": []
    }

    if assets.is_empty():
        report["import_failures"].append("No GLB/GLTF files under third_party/ual")
        _finish(report, 2)
        return

    for path in assets:
        var packed := ResourceLoader.load(path)
        if not (packed is PackedScene):
            report["import_failures"].append(path)
            continue

        var instance := (packed as PackedScene).instantiate()
        if instance == null:
            report["import_failures"].append(path)
            continue

        get_root().add_child(instance)
        report["imported_scenes"] += 1
        if (report["sample_files"] as Array).size() < 12:
            report["sample_files"].append(path)

        var skeletons: Array[Skeleton3D] = []
        var players: Array[AnimationPlayer] = []
        var meshes: Array[MeshInstance3D] = []
        _collect_scene_nodes(instance, skeletons, players, meshes)
        report["skeletons"] += skeletons.size()

        for mesh in meshes:
            if mesh.skin != null or mesh.skeleton != NodePath(""):
                report["skinned_meshes"] += 1

        for player in players:
            for animation_name in player.get_animation_list():
                var animation := player.get_animation(animation_name)
                if animation == null or animation.length <= 0.0:
                    continue
                report["clips_found"] += 1
                player.play(animation_name)
                player.advance(minf(0.20, maxf(animation.length * 0.20, 0.01)))
                report["clips_played"] += 1
                if (report["sample_clips"] as Array).size() < 25:
                    report["sample_clips"].append(str(animation_name))
                player.stop()
        instance.free()

    # This verifies import, existence of skeletons and playable tracks.
    # Retargeting onto the project's approved character is a separate E2 gate.
    var passed: bool = report["imported_scenes"] > 0 and report["skeletons"] > 0 and report["clips_played"] >= 2 and (report["import_failures"] as Array).is_empty()
    report["passed"] = passed
    _finish(report, 0 if passed else 2)
