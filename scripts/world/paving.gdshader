// Round plazas paved in rings of stones, for discs built with
// MeshUtil.cylinder. Each stone gets its own shade, with mortar lines and a
// darker band of stones around the rim.
shader_type spatial;

uniform vec3 stone_a : source_color = vec3(0.86, 0.80, 0.70);
uniform vec3 stone_b : source_color = vec3(0.76, 0.69, 0.60);
uniform vec3 rim_color : source_color = vec3(0.64, 0.58, 0.52);
uniform vec3 mortar_color : source_color = vec3(0.55, 0.50, 0.44);
uniform float radius = 9.0;
uniform float ring_width = 0.85;
uniform float stone_length = 1.0;

varying vec3 local;

void vertex() {
	local = VERTEX;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = local.xz;
	float r = length(p);
	float a = atan(p.y, p.x) / TAU + 0.5;
	float ring = floor(r / ring_width);
	float across = fract(r / ring_width);
	float count = max(6.0, floor(TAU * (ring + 0.5) * ring_width / stone_length));
	float along_f = a * count + hash(vec2(ring, 3.7));
	float stone = floor(along_f);
	float along = fract(along_f);
	// Distance to the nearest joint, in meters.
	float arc = TAU * (ring + 0.5) * ring_width / count;
	float d = min(min(along, 1.0 - along) * arc, min(across, 1.0 - across) * ring_width);
	if (ring < 1.0) {
		d = (1.0 - across) * ring_width; // One round stone in the middle.
	}
	float aa = max(fwidth(r) * 1.5, 0.004);
	float mortar = 1.0 - smoothstep(0.035, 0.035 + aa, d);
	float h = hash(vec2(ring, mod(stone, count)));
	bool rim = r > radius - ring_width * 1.1;
	vec3 col = rim ? rim_color * (0.92 + 0.12 * h) : mix(stone_b, stone_a, h);
	col *= 0.93 + 0.12 * noise(p * 3.0);
	// Stones look slightly domed: darker just inside each joint.
	col *= 0.86 + 0.14 * smoothstep(0.0, 0.16, d);
	ALBEDO = mix(col, mortar_color, mortar);
	ROUGHNESS = 0.85;
	SPECULAR = 0.3;
}
