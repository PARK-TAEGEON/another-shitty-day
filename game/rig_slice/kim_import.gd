@tool
extends EditorScenePostImport

const PALETTE = preload("res://rig_slice/kim_palette.gdshader")

func _post_import(scene: Node) -> Object:
	for child in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: ArrayMesh = child.mesh
		for i in mesh.get_surface_count():
			var source := mesh.surface_get_material(i) as StandardMaterial3D
			if source and mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR:
				var palette := ShaderMaterial.new()
				palette.resource_name = source.resource_name
				palette.shader = PALETTE
				palette.set_shader_parameter("roughness", source.roughness)
				palette.set_shader_parameter("metallic", source.metallic)
				mesh.surface_set_material(i, palette)
	return scene
