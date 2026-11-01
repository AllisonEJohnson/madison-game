class_name Lighting
extends RefCounted
## The game's shared look: sky, sunlight and color grading. The world, the
## character preview and item pictures all use it, so things look the same
## in each.
##
## The settings follow the ithappy packs' own preview scenes: filmic tone
## mapping (bright, saturated colors, which the cartoon palettes are painted
## for), a warm sun, and a soft sky-blue fill from a fixed ambient color (the
## two renderers gather light from the sky differently; a fixed color keeps
## them matching). Effects a renderer lacks (ambient occlusion in browsers)
## are skipped by Godot.

const SUN_ENERGY := 1.1
const AMBIENT_ENERGY := 0.55
## Browsers use the Compatibility renderer, which adds a shadow-casting sun's
## light on top of the rest after converting each to screen colors instead of
## before (Godot issue 90259). That washes sunlit places out to nearly white,
## so there the sun is dimmed to land close to the desktop look. 0.25 came
## from comparing the same views in both renderers.
const COMPAT_SUN_SCALE := 0.25
## The painted cloud sky from the Fantasy pack (see sky_paths()). Copies
## without the licensed art get a plain gradient sky in the same colors.
const SKY_TEXTURE := "Fantasy/textures/Skybox_8.png"
## Each land's own sky and light. Starfall Glade has a lilac sky that turns
## pink at the horizon, warmer light and more glow, so magic lamps and
## crystals shine.
const LANDS := {
	"town": {
		"sky_top": Color("3f8ee0"), "sky_horizon": Color("cfe6f5"), "ground": Color("7a9e66"),
		"sky_tint": Color("3a7cc7"), "sky_tint_amount": 0.12,
		"sun": Color("fff1da"), "ambient": Color("c9dcff"), "glow": 0.3, "fog": Color("d3e6f3"),
	},
	"glade": {
		"sky_top": Color("6a5cf0"), "sky_horizon": Color("f7cfe9"), "ground": Color("4c4a78"),
		"sky_tint": Color("a77cf2"), "sky_tint_amount": 0.35,
		"sun": Color("ffe8ee"), "ambient": Color("d9cbff"), "glow": 0.45, "fog": Color("efd5f1"),
	},
}
## Indoors (the character preview, homes): no fog, a little more fill light.
const INDOOR_AMBIENT := 0.7

const SKY_SHADER := """
shader_type sky;
uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color;
uniform float tint_amount = 0.12;
void sky() {
	// Squeezed down so the clouds sit on the horizon, as in the pack's scenes.
	vec3 c = texture(panorama, vec2(SKY_COORDS.x, SKY_COORDS.y * 0.72)).rgb;
	COLOR = mix(c, tint, tint_amount);
}
"""

static var _sky_shader: Shader


static func is_compatibility() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


## Licensed art files the look needs (kept by scripts/dev/prune_art.gd).
static func sky_paths() -> Array:
	return [SKY_TEXTURE]


static func environment(outdoor := true, land := "town") -> Environment:
	var look: Dictionary = LANDS.get(land, LANDS["town"])
	var e := Environment.new()
	e.sky = _sky(look)
	e.background_mode = Environment.BG_SKY
	# A fixed fill color rather than light from the sky: the two renderers
	# gather sky light differently, and the color keeps shade a soft blue.
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = look["ambient"]
	e.ambient_light_energy = AMBIENT_ENERGY if outdoor else INDOOR_AMBIENT
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = true
	e.ssao_radius = 1.2
	e.ssao_intensity = 0.8
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.08
	e.glow_enabled = true
	e.glow_intensity = look["glow"] if outdoor else 0.15
	e.glow_bloom = 0.03
	if outdoor:
		# Distant trees fade into the horizon instead of ending at a hard edge.
		e.fog_enabled = true
		e.fog_mode = Environment.FOG_MODE_DEPTH
		e.fog_light_color = look["fog"]
		e.fog_depth_begin = 60.0
		e.fog_depth_end = 260.0
		e.fog_depth_curve = 1.8
		e.fog_sky_affect = 0.0
	return e


static func sun(land := "town") -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -35, 0)
	light.light_color = LANDS.get(land, LANDS["town"])["sun"]
	light.light_energy = SUN_ENERGY * (COMPAT_SUN_SCALE if is_compatibility() else 1.0)
	light.shadow_enabled = true
	light.shadow_blur = 1.5
	light.directional_shadow_max_distance = 70.0
	return light


static func _sky(look: Dictionary) -> Sky:
	var sky := Sky.new()
	var path: String = Art.ROOT + SKY_TEXTURE
	if ResourceLoader.exists(path):
		if _sky_shader == null:
			_sky_shader = Shader.new()
			_sky_shader.code = SKY_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = _sky_shader
		mat.set_shader_parameter("panorama", load(path))
		mat.set_shader_parameter("tint", look["sky_tint"])
		mat.set_shader_parameter("tint_amount", look["sky_tint_amount"])
		sky.sky_material = mat
	else:
		var mat := ProceduralSkyMaterial.new()
		mat.sky_top_color = look["sky_top"]
		mat.sky_horizon_color = look["sky_horizon"]
		mat.sky_curve = 0.1
		mat.ground_bottom_color = look["ground"]
		mat.ground_horizon_color = look["sky_horizon"]
		mat.sun_angle_max = 25.0
		sky.sky_material = mat
	# Reflections on these rough cartoon materials are soft, so a small
	# radiance map is plenty (and quick to make in browsers).
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	return sky
