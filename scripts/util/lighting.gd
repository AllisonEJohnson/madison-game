class_name Lighting
extends RefCounted
## The game's shared look: sky, sunlight and color grading. The world and the
## character preview both use it, so an avatar looks the same in each.
## Effects a renderer lacks (ambient occlusion in browsers) are skipped by Godot.

const SKY_TOP := Color("2a7fe6")
const SKY_HORIZON := Color("c2e3fa")
const GROUND_BOTTOM := Color("5a7d4a")
const SUN_COLOR := Color("fff0d6")
const SUN_ENERGY := 1.3
const AMBIENT_ENERGY := 0.7
# The Compatibility renderer (used in browsers) comes out much brighter for the
# same values, so it gets dimmer lights to match the desktop look.
const COMPAT_SUN_ENERGY := 0.95
const COMPAT_AMBIENT_ENERGY := 0.35
## Each land's own sky and light. Hometown's values are the constants above;
## Starfall Glade has a lilac sky that turns pink at the horizon, warmer
## light and more glow, so magic lamps and crystals shine.
const LANDS := {
	"town": {"sky_top": SKY_TOP, "sky_horizon": SKY_HORIZON, "ground": GROUND_BOTTOM, "sun": SUN_COLOR, "glow": 0.25},
	"glade": {"sky_top": Color("6a5cf0"), "sky_horizon": Color("f7cfe9"), "ground": Color("4c4a78"),
		"sun": Color("ffe1ec"), "glow": 0.45},
}


static func is_compatibility() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


static func environment(outdoor := true, land := "town") -> Environment:
	var look: Dictionary = LANDS.get(land, LANDS["town"])
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = look["sky_top"]
	sky_mat.sky_horizon_color = look["sky_horizon"]
	sky_mat.sky_curve = 0.1
	sky_mat.ground_bottom_color = look["ground"]
	sky_mat.ground_horizon_color = look["sky_horizon"]
	sky_mat.sun_angle_max = 25.0
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var e := Environment.new()
	e.sky = sky
	e.background_mode = Environment.BG_SKY
	# Shade is lit by the sky, so shadows turn a soft blue instead of gray.
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = COMPAT_AMBIENT_ENERGY if is_compatibility() else AMBIENT_ENERGY
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# AgX keeps bright areas from blowing out to white; the saturation boost
	# below brings back the colors it mutes.
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.ssao_enabled = true
	e.ssao_radius = 1.0
	e.ssao_intensity = 1.5
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.35
	e.adjustment_contrast = 1.08
	if outdoor:
		e.glow_enabled = true
		e.glow_intensity = look["glow"]
		e.glow_bloom = 0.05
		# Distant trees fade into the horizon instead of ending at a hard edge.
		e.fog_enabled = true
		e.fog_mode = Environment.FOG_MODE_DEPTH
		e.fog_light_color = look["sky_horizon"]
		e.fog_depth_begin = 35.0
		e.fog_depth_end = 160.0
		e.fog_depth_curve = 1.5
		e.fog_sky_affect = 0.0
	return e


static func sun(land := "town") -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -35, 0)
	light.light_color = LANDS.get(land, LANDS["town"])["sun"]
	light.light_energy = COMPAT_SUN_ENERGY if is_compatibility() else SUN_ENERGY
	light.shadow_enabled = true
	light.shadow_blur = 1.5
	light.directional_shadow_max_distance = 70.0
	return light
