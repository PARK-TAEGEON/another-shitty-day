extends Node3D
## Original procedural adult fist for the desk-slam timing study.
## Local coordinates: wrist at origin; +Y toward knuckles; +Z hand back.
## A right hand has its thumb on +X; the left hand mirrors X.
## Forearm and shirt extend along -Y. Units are metres.
## This is a fixed clenched-pose study mesh, not a production skeletal rig.

var side_sign: float = 1.0
var skin_color := Color(0.61, 0.43, 0.34)
var sleeve_color := Color(0.66, 0.735, 0.755)
var _points := PackedVector3Array()
var _skin: StandardMaterial3D
var _knuckle: StandardMaterial3D
var _cloth: StandardMaterial3D
var _cuff: StandardMaterial3D
var _seam: StandardMaterial3D
var _nail: StandardMaterial3D

func build(side: String = "right") -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_points.clear()
	side_sign = -1.0 if side.to_lower() == "left" else 1.0
	_skin = _material(skin_color, 0.60)
	_knuckle = _material(skin_color.lerp(Color(0.72, 0.36, 0.29), 0.055), 0.63)
	_cloth = _material(sleeve_color, 0.94)
	_cuff = _material(sleeve_color.lightened(0.09), 0.86)
	_seam = _material(sleeve_color.darkened(0.08), 0.92)
	_nail = _material(skin_color.lerp(Color(0.78, 0.65, 0.59), 0.40), 0.52)

	# Broad dorsal mass, narrowed carpus, and softly rounded heel of the hand.
	_loft("Hand", [
		Vector4(-0.022, 0.022, 0.018, 0.0),
		Vector4(-0.003, 0.023, 0.0185, 0.0),
		Vector4(0.018, 0.028, 0.020, 0.0),
		Vector4(0.044, 0.036, 0.023, 0.0),
		Vector4(0.074, 0.043, 0.027, 0.001),
		Vector4(0.093, 0.046, 0.032, 0.001),
		Vector4(0.109, 0.046, 0.037, 0.002),
		Vector4(0.122, 0.041, 0.034, 0.003),
		Vector4(0.132, 0.032, 0.023, 0.000),
		Vector4(0.140, 0.016, 0.010, -0.007)
	], _skin, 36)
	_ellipsoid("Thenar", Vector3(0.028, 0.050, -0.015), Vector3(0.015, 0.027, 0.014), _skin)
	_ellipsoid("UlnarHeel", Vector3(-0.025, 0.061, -0.004), Vector3(0.015, 0.029, 0.023), _skin)

	# Four real curled fingers: metacarpal knuckles slope down toward the pinky.
	_finger("Index", 0.0320, 0.119, 0.0103)
	_finger("Middle", 0.0107, 0.129, 0.0109)
	_finger("Ring", -0.0120, 0.123, 0.0102)
	_finger("Pinky", -0.0320, 0.110, 0.0087)

	# Thumb wraps around the outside of the closed fingers, never inside the fist.
	_tube("Thumb", [
		Vector3(0.030, 0.034, -0.015),
		Vector3(0.043, 0.053, -0.018),
		Vector3(0.051, 0.074, -0.021),
		Vector3(0.049, 0.092, -0.034),
		Vector3(0.032, 0.101, -0.048),
		Vector3(0.014, 0.099, -0.049),
		Vector3(0.005, 0.095, -0.046)
	], [0.014, 0.014, 0.0128, 0.0122, 0.0115, 0.0104, 0.005], _skin, 24, 5, 0.93)
	# Small thumbnail plate is placed on the visible outer surface of the last phalanx.
	var thumb_nail := _ellipsoid("Thumbnail", Vector3(0.017, 0.103, -0.058), Vector3(0.0080, 0.0058, 0.0011), _nail)
	thumb_nail.rotation.z = -0.17 * side_sign

	# Exposed wrist has a natural taper into a soft, layered office-shirt cuff.
	_loft("Wrist", [
		Vector4(-0.077, 0.029, 0.024, 0.0),
		Vector4(-0.049, 0.027, 0.022, 0.0),
		Vector4(-0.023, 0.024, 0.019, 0.0),
		Vector4(0.002, 0.023, 0.0185, 0.0)
	], _skin, 32)
	_loft("Sleeve", [
		Vector4(-0.755, 0.082, 0.066, 0.004),
		Vector4(-0.640, 0.077, 0.061, 0.003),
		Vector4(-0.520, 0.069, 0.055, 0.002),
		Vector4(-0.420, 0.063, 0.050, 0.002),
		Vector4(-0.335, 0.059, 0.047, 0.002),
		Vector4(-0.293, 0.055, 0.044, 0.001),
		Vector4(-0.242, 0.051, 0.041, 0.000),
		Vector4(-0.193, 0.046, 0.038, 0.001),
		Vector4(-0.162, 0.047, 0.038, 0.001),
		Vector4(-0.137, 0.041, 0.034, -0.001),
		Vector4(-0.117, 0.043, 0.035, 0.001),
		Vector4(-0.099, 0.037, 0.031, 0.000),
		Vector4(-0.079, 0.035, 0.029, 0.000)
	], _cloth, 36, 0.035)
	_loft("Cuff", [
		Vector4(-0.091, 0.0358, 0.0300, 0.0),
		Vector4(-0.087, 0.0368, 0.0310, 0.0),
		Vector4(-0.047, 0.0308, 0.0255, 0.0),
		Vector4(-0.041, 0.0310, 0.0260, 0.0)
	], _cuff, 36)
	_loft("CuffStitch", [
		Vector4(-0.0475, 0.0311, 0.0258, 0.0),
		Vector4(-0.0464, 0.0311, 0.0258, 0.0)
	], _seam, 36)
	_ellipsoid("CuffButton", Vector3(0.026, -0.065, -0.019), Vector3(0.0045, 0.0045, 0.0018), _material(Color(0.90, 0.90, 0.83), 0.45))

func get_contact_point() -> Vector3:
	## Nominal ulnar side contact; use transformed geometry for exact desk clearance.
	return Vector3(-0.046 * side_sign, 0.105, 0.002)

func get_geometry_bounds() -> AABB:
	if _points.is_empty():
		return AABB()
	var bounds := AABB(_points[0], Vector3.ZERO)
	for point in _points:
		bounds = bounds.expand(point)
	return bounds

func get_geometry_points() -> PackedVector3Array:
	## Fist, wrist, and sleeve vertices in this node's local space.
	return _points

func get_fist_points() -> PackedVector3Array:
	## Excludes shirt/forearm for checking only the hand's rotated support height.
	var result := PackedVector3Array()
	for point in _points:
		if point.y >= -0.025:
			result.append(point)
	return result

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.0
	return material

func _finger(label: String, x: float, knuckle_y: float, radius: float) -> void:
	_tube(label, [
		Vector3(x * 0.72, 0.072, 0.018),
		Vector3(x * 0.91, 0.095, 0.021),
		Vector3(x, knuckle_y, 0.028),
		Vector3(x, knuckle_y + 0.013, 0.013),
		Vector3(x, knuckle_y + 0.012, -0.010),
		Vector3(x, knuckle_y - 0.002, -0.030),
		Vector3(x * 0.96, knuckle_y - 0.025, -0.033),
		Vector3(x * 0.94, knuckle_y - 0.034, -0.026)
	], [radius * 0.65, radius * 0.81, radius * 1.05, radius, radius * 0.96, radius * 0.93, radius * 0.83, radius * 0.32], _knuckle, 24, 5, 0.94)

func _loft(label: String, rows: Array, material: Material, ring_count: int = 32, wrinkle: float = 0.0) -> void:
	# Each row is (Y, horizontal radius, depth radius, Z offset).
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for row_index in range(rows.size()):
		var row: Vector4 = rows[row_index]
		var lower: Vector4 = rows[maxi(row_index - 1, 0)]
		var upper: Vector4 = rows[mini(row_index + 1, rows.size() - 1)]
		var dy := maxf(upper.x - lower.x, 0.00001)
		for ring_index in range(ring_count):
			var angle := TAU * float(ring_index) / float(ring_count)
			var ripple := 1.0 + wrinkle * sin(angle * 6.0 + row.x * 41.0)
			var px := cos(angle) * row.y * ripple
			var pz := sin(angle) * row.z * ripple + row.w
			vertices.append(Vector3(px * side_sign, row.x, pz))
			var slope := (upper.y - lower.y) / dy * cos(angle) * cos(angle) + (upper.z - lower.z) / dy * sin(angle) * sin(angle)
			normals.append(Vector3(cos(angle) / row.y * side_sign, -slope / ((row.y + row.z) * 0.5), sin(angle) / row.z).normalized())
			uv.append(Vector2(float(ring_index) / float(ring_count), float(row_index) / maxf(float(rows.size() - 1), 1.0)))
	for row_index in range(rows.size() - 1):
		for ring_index in range(ring_count):
			var a := row_index * ring_count + ring_index
			var b := row_index * ring_count + (ring_index + 1) % ring_count
			var c := a + ring_count
			var d := b + ring_count
			_quad_indices(indices, a, b, c, d)
	_cap(vertices, normals, uv, indices, 0, ring_count, false)
	_cap(vertices, normals, uv, indices, (rows.size() - 1) * ring_count, ring_count, true)
	_mesh(label, vertices, normals, uv, indices, material)

func _tube(label: String, controls: Array, radii: Array, material: Material, ring_count: int = 24, steps: int = 5, flatten: float = 1.0) -> void:
	var centers: Array[Vector3] = []
	var sizes: Array[float] = []
	for segment in range(controls.size() - 1):
		for step in range(steps):
			var t := float(step) / float(steps)
			var p0: Vector3 = controls[maxi(0, segment - 1)]
			var p1: Vector3 = controls[segment]
			var p2: Vector3 = controls[segment + 1]
			var p3: Vector3 = controls[mini(controls.size() - 1, segment + 2)]
			centers.append(p1.cubic_interpolate(p2, p0, p3, t))
			sizes.append(lerpf(float(radii[segment]), float(radii[segment + 1]), t))
	centers.append(controls[-1])
	sizes.append(float(radii[-1]))
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for row_index in range(centers.size()):
		var tangent := (centers[mini(centers.size() - 1, row_index + 1)] - centers[maxi(0, row_index - 1)]).normalized()
		var cross_axis := Vector3.RIGHT
		if absf(tangent.dot(cross_axis)) > 0.91:
			cross_axis = Vector3.UP
		var axis_a := (cross_axis - tangent * tangent.dot(cross_axis)).normalized()
		var axis_b := axis_a.cross(tangent).normalized()
		for ring_index in range(ring_count):
			var angle := TAU * float(ring_index) / float(ring_count)
			var outward := axis_a * cos(angle) + axis_b * sin(angle) * flatten
			var vertex := centers[row_index] + outward * sizes[row_index]
			vertex.x *= side_sign
			outward.x *= side_sign
			vertices.append(vertex)
			normals.append(outward.normalized())
			uv.append(Vector2(float(ring_index) / float(ring_count), float(row_index) / float(centers.size() - 1)))
	for row_index in range(centers.size() - 1):
		for ring_index in range(ring_count):
			var a := row_index * ring_count + ring_index
			var b := row_index * ring_count + (ring_index + 1) % ring_count
			_quad_indices(indices, a, b, a + ring_count, b + ring_count)
	_cap(vertices, normals, uv, indices, 0, ring_count, false)
	_cap(vertices, normals, uv, indices, (centers.size() - 1) * ring_count, ring_count, true)
	_mesh(label, vertices, normals, uv, indices, material)

func _quad_indices(indices: PackedInt32Array, a: int, b: int, c: int, d: int) -> void:
	if side_sign > 0.0:
		indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
	else:
		indices.append_array(PackedInt32Array([a, c, b, b, c, d]))

func _cap(vertices: PackedVector3Array, normals: PackedVector3Array, uv: PackedVector2Array, indices: PackedInt32Array, start: int, count: int, end_cap: bool) -> void:
	var center := Vector3.ZERO
	for i in range(count):
		center += vertices[start + i]
	center /= float(count)
	var center_index := vertices.size()
	vertices.append(center)
	normals.append(Vector3.UP if end_cap else Vector3.DOWN)
	uv.append(Vector2(0.5, 0.5))
	for i in range(count):
		var first := start + i
		var second := start + (i + 1) % count
		if end_cap == (side_sign > 0.0):
			indices.append_array(PackedInt32Array([center_index, second, first]))
		else:
			indices.append_array(PackedInt32Array([center_index, first, second]))

func _mesh(label: String, vertices: PackedVector3Array, normals: PackedVector3Array, uv: PackedVector2Array, indices: PackedInt32Array, material: Material) -> MeshInstance3D:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	add_child(node)
	_points.append_array(vertices)
	return node

func _ellipsoid(label: String, center: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = sphere
	node.material_override = material
	node.position = Vector3(center.x * side_sign, center.y, center.z)
	node.scale = dimensions
	add_child(node)
	# Sphere mesh vertices make the support function exact at authored resolution.
	var vertices: PackedVector3Array = sphere.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for vertex in vertices:
		_points.append(node.position + vertex * dimensions)
	return node
