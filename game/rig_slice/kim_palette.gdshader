shader_type spatial;

// glTF COLOR_0 is linear. The project's Compatibility renderer shades in sRGB.
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 linear = max(COLOR.rgb, vec3(0.0));
	vec3 srgb = mix(12.92 * linear, 1.055 * pow(linear, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), linear));
	ALBEDO = OUTPUT_IS_SRGB ? srgb : linear;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
