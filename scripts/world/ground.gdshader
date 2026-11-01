// A land's ground: painted-looking grass with soft lighter and darker
// patches and a fine mottle up close, and packed-earth paths with ragged,
// grassy edges. Paths are boxes and circles given in the ground mesh's own
// space; overlapping ones merge cleanly where they cross. Everything comes
// from position, so it costs no textures and stays cheap enough for browsers.
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.37, 0.66, 0.29);
uniform vec3 light_color : source_color = vec3(0.55, 0.78, 0.33);
uniform vec3 dark_color : source_color = vec3(0.24, 0.52, 0.27);
// A tint that shows in a few spots, for variety.
uniform vec3 accent_color : source_color = vec3(0.66, 0.76, 0.33);
uniform float patch_scale = 0.045;
uniform float detail_scale = 0.7;

uniform vec3 path_color : source_color = vec3(0.80, 0.70, 0.52);
uniform vec3 path_dark : source_color = vec3(0.66, 0.55, 0.40);
uniform vec3 pebble_color : source_color = vec3(0.90, 0.84, 0.72);
uniform vec3 edge_color : source_color = vec3(0.55, 0.60, 0.36);
// Paths: (center x, center z, half width, half length) and (x, z, radius).
uniform vec4 boxes[16];
uniform int box_count = 0;
uniform vec3 circles[8];
uniform int circle_count = 0;
// How far the ragged edge eats into a path, in meters.
uniform float edge_width = 0.4;

varying vec3 world;
varying vec2 local;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local = VERTEX.xz;
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

float fbm(vec2 p) {
	float v = 0.5 * noise(p);
	v += 0.25 * noise(p * 2.03 + 17.1);
	v += 0.125 * noise(p * 4.01 + 31.7);
	return v / 0.875;
}

// Signed distance to the nearest path: negative inside one.
float path_distance(vec2 p) {
	float d = 1e5;
	for (int i = 0; i < box_count; i++) {
		vec2 q = abs(p - boxes[i].xy) - boxes[i].zw;
		d = min(d, length(max(q, 0.0)) + min(max(q.x, q.y), 0.0));
	}
	for (int i = 0; i < circle_count; i++) {
		d = min(d, length(p - circles[i].xy) - circles[i].z);
	}
	return d;
}

void fragment() {
	vec2 p = world.xz;
	// Fine detail fades out where it would shimmer in the distance.
	float fine = 1.0 - smoothstep(0.25, 0.9, length(fwidth(p * detail_scale)));

	float patches = fbm(p * patch_scale);
	vec3 grass = mix(dark_color, base_color, smoothstep(0.25, 0.5, patches));
	grass = mix(grass, light_color, smoothstep(0.55, 0.8, patches));
	float accent = smoothstep(0.62, 0.85, fbm(p * patch_scale * 0.6 + 40.0));
	grass = mix(grass, accent_color, accent * 0.5);
	vec2 q = p * detail_scale;
	float mottle = noise(q) * 0.6 + noise(q * 2.7 + 9.0) * 0.4;
	grass *= 1.0 + (mottle - 0.5) * 0.22 * fine;

	vec3 col = grass;
	if (box_count + circle_count > 0) {
		float wobble = noise(p * 1.6) * 0.7 + noise(p * 5.0) * 0.3;
		// How far inside the path's ragged edge this point is.
		float inside = -path_distance(local) - wobble * edge_width;
		float aa = max(length(fwidth(local)), 0.002);
		float on_path = smoothstep(-aa, aa, inside);
		if (on_path > 0.0) {
			float n = noise(p * 0.9) * 0.6 + noise(p * 3.1) * 0.4;
			vec3 dirt = mix(path_dark, path_color, smoothstep(0.2, 0.75, n));
			float pebble = smoothstep(0.8, 0.86, noise(p * 4.0 + 7.3)) * fine;
			dirt = mix(dirt, pebble_color, pebble * 0.7);
			// A worn, grassy rim.
			dirt = mix(edge_color, dirt, smoothstep(0.0, 0.3, inside));
			col = mix(grass, dirt, on_path);
		}
		// A soft shadowy line where the grass meets the path.
		col *= 1.0 - 0.12 * (1.0 - smoothstep(0.0, 0.25, abs(inside))) * (1.0 - on_path);
	}
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
}
