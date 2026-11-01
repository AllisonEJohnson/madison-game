class_name Surfaces
extends RefCounted
## Materials for the big flat surfaces that fill most of the screen: grass,
## paths and paved plazas. Flat single colors there made the world look like
## a blank test level next to the detailed models, so these add gentle
## painted variation, worked out on the graphics card from position (no
## textures to download, so they cost nothing in the browser build).
##
## Each land passes its own colors; a palette is a Dictionary of shader
## uniform names to colors (see ground.gdshader and paving.gdshader).

const GROUND_SHADER := preload("res://scripts/world/ground.gdshader")
const PAVING_SHADER := preload("res://scripts/world/paving.gdshader")
const WATER_SHADER := preload("res://scripts/world/water.gdshader")
## The ground shader holds this many path boxes and circles.
const MAX_BOXES := 16
const MAX_CIRCLES := 8

const TOWN_GROUND := {"base_color": Color("5aa64a"), "light_color": Color("93cc5a"),
	"dark_color": Color("3b8040"), "accent_color": Color("b0c45a"),
	"path_color": Color("d4b98d"), "path_dark": Color("b39773"),
	"pebble_color": Color("ebdcc0"), "edge_color": Color("8a9a55")}
const TOWN_PAVING := {"stone_a": Color("e3d6bf"), "stone_b": Color("cbbca3"),
	"rim_color": Color("a99a88"), "mortar_color": Color("8f8272")}
const GLADE_GROUND := {"base_color": Color("5cbf8e"), "light_color": Color("9fdf9c"),
	"dark_color": Color("2f8f80"), "accent_color": Color("b9a6ff"),
	"path_color": Color("f0dcc2"), "path_dark": Color("d8bfa8"),
	"pebble_color": Color("fff4e4"), "edge_color": Color("8fc9a2")}
const GLADE_PAVING := {"stone_a": Color("ece0f6"), "stone_b": Color("d7c8ea"),
	"rim_color": Color("b4a3d1"), "mortar_color": Color("a08fbd")}


## Gives a ground box (built with MeshUtil.box, centered on its land) grass
## with paths worn into it. Each path is a Rect2 (a strip, from `strip()`) or
## a Vector3 (x, z, radius) for a round clearing, in the box's own space.
static func ground(mesh: MeshInstance3D, palette: Dictionary, paths: Array = []) -> void:
	var mat := _material(GROUND_SHADER, palette)
	var boxes := PackedVector4Array()
	var circles := PackedVector3Array()
	for path in paths:
		if path is Rect2:
			boxes.append(Vector4(path.get_center().x, path.get_center().y, path.size.x / 2.0, path.size.y / 2.0))
		elif path is Vector3:
			circles.append(path)
	assert(boxes.size() <= MAX_BOXES and circles.size() <= MAX_CIRCLES, "Too many paths for the ground shader")
	mat.set_shader_parameter("box_count", mini(boxes.size(), MAX_BOXES))
	mat.set_shader_parameter("circle_count", mini(circles.size(), MAX_CIRCLES))
	boxes.resize(MAX_BOXES)
	circles.resize(MAX_CIRCLES)
	mat.set_shader_parameter("boxes", boxes)
	mat.set_shader_parameter("circles", circles)
	mesh.material_override = mat


## A straight path `size` across (x and z), centered on `center`; the same
## numbers a flat MeshUtil.box for it would take.
static func strip(size: Vector3, center: Vector3) -> Rect2:
	return Rect2(Vector2(center.x - size.x / 2.0, center.z - size.z / 2.0), Vector2(size.x, size.z))


## Paves a flat disc built with MeshUtil.cylinder.
static func paving(mesh: MeshInstance3D, radius: float, palette: Dictionary) -> void:
	# Rounder than MeshUtil's 16 sides, so the rim of stones follows the edge.
	if mesh.mesh is CylinderMesh:
		(mesh.mesh as CylinderMesh).radial_segments = 64
	var mat := _material(PAVING_SHADER, palette)
	mat.set_shader_parameter("radius", radius)
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Rippling water for a round pool of the given radius.
static func water(mesh: MeshInstance3D, radius: float) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("radius", radius)
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _material(shader: Shader, palette: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	for key in palette:
		mat.set_shader_parameter(key, palette[key])
	return mat
