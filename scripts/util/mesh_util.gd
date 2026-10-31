class_name MeshUtil
extends RefCounted
## Small helpers for building low-poly models out of primitive meshes,
## so the prototype needs no imported art assets.


static func material(color: Color, roughness := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func add(parent: Node3D, mesh: PrimitiveMesh, color: Color, pos := Vector3.ZERO,
		rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	mesh.material = material(color)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, color: Color, pos := Vector3.ZERO,
		rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return add(parent, m, color, pos, rot_deg)


static func sphere(parent: Node3D, radius: float, color: Color, pos := Vector3.ZERO,
		scl := Vector3.ONE) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 16
	m.rings = 8
	return add(parent, m, color, pos, Vector3.ZERO, scl)


static func capsule(parent: Node3D, radius: float, height: float, color: Color,
		pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	m.radial_segments = 16
	m.rings = 4
	return add(parent, m, color, pos, rot_deg, scl)


static func cylinder(parent: Node3D, top: float, bottom: float, height: float, color: Color,
		pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = 16
	m.rings = 1
	return add(parent, m, color, pos, rot_deg, scl)


static func torus(parent: Node3D, inner: float, outer: float, color: Color,
		pos := Vector3.ZERO, rot_deg := Vector3.ZERO, ring_segments := 16) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = ring_segments
	m.ring_segments = 8
	return add(parent, m, color, pos, rot_deg)


## Adds a static box collider (used for walls and furniture).
static func collider(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.position = pos
	body.add_child(shape)
	parent.add_child(body)


## Makes every mesh under `root` see-through, for build-mode ghost previews.
## With `keep_look` the meshes keep their own colors instead of the tint.
static func make_ghost(root: Node, tint: Color, keep_look := false) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			if keep_look:
				child.transparency = 0.35
			else:
				var m := StandardMaterial3D.new()
				m.albedo_color = tint
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				child.material_override = m
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		make_ghost(child, tint, keep_look)


static func hex(value: Variant, fallback := Color.WHITE) -> Color:
	if value is Color:
		return value
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback
