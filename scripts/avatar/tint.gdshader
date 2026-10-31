// Recolors a Cute Characters part. The pack paints every part from one palette
// texture, so this swaps only the texels close to the part's main color (see
// PartColors) for the chosen tint, keeping their light and shade. Other colors
// on the part, like stripes or buttons, stay as they are.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D palette : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 main_color : source_color;
uniform vec3 tint_color : source_color;

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec3 c = texture(palette, UV).rgb;
	// sqrt brings linear colors closer to how far apart they look.
	float near_main = 1.0 - smoothstep(0.1, 0.2, distance(sqrt(c), sqrt(main_color)));
	vec3 shaded = tint_color * clamp(luma(c) / max(luma(main_color), 0.002), 0.5, 1.6);
	ALBEDO = mix(c, shaded, near_main);
	ROUGHNESS = 0.5;
}
