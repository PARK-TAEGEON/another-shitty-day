shader_type canvas_item;

uniform vec4 ink : source_color = vec4(0.102, 0.102, 0.102, 1.0);
uniform vec4 paper : source_color = vec4(0.933, 0.918, 0.878, 1.0);
uniform float cell = 4.0;

void fragment() {
	vec3 sample = texture(TEXTURE, UV).rgb;
	float luma = dot(sample, vec3(0.299, 0.587, 0.114));
	luma = clamp((luma - 0.08) * 1.35, 0.0, 1.0);
	vec2 grid = fract(FRAGCOORD.xy / cell) - vec2(0.5);
	float radius = (1.0 - luma) * 0.46;
	float dot_mask = step(length(grid), radius);
	COLOR = vec4(mix(paper.rgb, ink.rgb, dot_mask), 1.0);
}
