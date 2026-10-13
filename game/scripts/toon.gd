extends RefCounted
## Shared cartoon look: banded toon lighting on StandardMaterial3D and an
## inverted-hull outline whose width stays constant in screen pixels.
## Pure presentation. No collision, timing or gameplay value depends on it.

const OUTLINE_CODE: String = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform vec4 outline_color : source_color = vec4(0.13, 0.11, 0.10, 1.0);
uniform float width_px = 2.2;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 direction = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	float len = length(direction);
	if (len > 0.0001) {
		clip.xy += direction / len * width_px * 2.0 / VIEWPORT_SIZE * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
"""

static var _outline: ShaderMaterial
static var _outline_thin: ShaderMaterial

## Turn an ordinary material into the shared toon look, in place.
static func apply(material: StandardMaterial3D, rim: float = 0.22) -> StandardMaterial3D:
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	# In toon mode roughness softens the band edge: a little blur, no gradient.
	material.roughness = 0.42
	material.metallic_specular = 0.0
	if rim > 0.0:
		material.rim_enabled = true
		material.rim = rim
		material.rim_tint = 0.65
	return material

static func outline_material(thin: bool = false) -> ShaderMaterial:
	if thin:
		if _outline_thin == null:
			_outline_thin = _make_outline(2.2)
		return _outline_thin
	if _outline == null:
		_outline = _make_outline(3.2)
	return _outline

static func _make_outline(width: float) -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = OUTLINE_CODE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("width_px", width)
	return material

## Outline a smooth-normal mesh. Flat-shaded boxes split at corners, so callers
## only outline their rounded forms.
static func outline(node: GeometryInstance3D, thin: bool = false) -> void:
	node.material_overlay = outline_material(thin)
