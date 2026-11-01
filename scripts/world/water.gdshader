// Calm water for round pools (MeshUtil-style cylinders centered on their
// node): deep blue in the middle, lighter near the rim, with gentle ripples.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 deep : source_color = vec4(0.18, 0.45, 0.9, 1.0);
uniform vec4 shallow : source_color = vec4(0.5, 0.9, 0.95, 1.0);
uniform float radius = 9.0;

varying vec3 world;
varying float edge;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	edge = length(VERTEX.xz) / radius;
}

void fragment() {
	float ripple = sin(world.x * 1.7 + TIME * 1.3) * sin(world.z * 1.3 - TIME * 1.1);
	ripple += 0.5 * sin((world.x + world.z) * 3.1 - TIME * 2.0);
	vec3 col = mix(deep.rgb, shallow.rgb, smoothstep(0.55, 1.0, edge));
	ALBEDO = col + ripple * 0.04;
	ROUGHNESS = 0.12;
	SPECULAR = 0.8;
}
