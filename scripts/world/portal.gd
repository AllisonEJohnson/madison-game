class_name Portal
extends Node3D
## A glowing stone ring that carries you to another land when you walk into
## it. Only the local player's own walk-ins count; the world then moves that
## player, and everyone else sees them move through normal position syncing.
## A portal to a place that opens at a higher level is locked: a padlock
## hangs in it, the sign says when it opens, and you bump into it instead.

signal entered(player: Player)
## Walked into while locked.
signal knocked(player: Player)

const RING_RADIUS := 1.9
const SWIRL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform vec4 inner : source_color = vec4(1.0, 0.95, 1.0, 1.0);
uniform vec4 outer : source_color = vec4(0.55, 0.35, 1.0, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float swirl = sin(a * 3.0 + r * 9.0 - TIME * 2.5) * 0.5 + 0.5;
	vec3 col = mix(inner.rgb, outer.rgb, smoothstep(0.0, 1.0, r));
	col += swirl * 0.25 * (1.0 - r);
	ALBEDO = col;
	ALPHA = smoothstep(1.0, 0.9, r) * (0.55 + 0.35 * swirl);
}
"""

var title := ""
var locked := false
var _cooldown := 0.0
var _color := Color.WHITE
var _swirl: ShaderMaterial
var _sign: Label3D
var _padlock: Sprite3D
var _barrier: StaticBody3D


## `color` tints the swirl so each destination has its own look.
func setup(portal_title: String, color: Color) -> Portal:
	title = portal_title
	_color = color
	name = "Portal" + portal_title.to_pascal_case()
	# The ring stands upright, facing along the node's local Z.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RING_RADIUS
	torus.outer_radius = RING_RADIUS + 0.45
	torus.rings = 48
	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	ring.position.y = RING_RADIUS + 0.35
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("b9b2c9")
	stone.roughness = 0.8
	ring.material_override = stone
	add_child(ring)
	# Glowing gems around the ring.
	for i in 8:
		var angle := TAU * i / 8.0
		var gem := MeshUtil.sphere(self, 0.16, color.lightened(0.35),
				Vector3(cos(angle) * (RING_RADIUS + 0.22), RING_RADIUS + 0.35 + sin(angle) * (RING_RADIUS + 0.22), 0.25))
		var glow := StandardMaterial3D.new()
		glow.albedo_color = color.lightened(0.35)
		glow.emission_enabled = true
		glow.emission = color.lightened(0.2)
		glow.emission_energy_multiplier = 2.0
		gem.material_override = glow
	var disc := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * RING_RADIUS * 2.0
	disc.mesh = quad
	disc.position.y = RING_RADIUS + 0.35
	var swirl := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SWIRL_SHADER
	swirl.shader = shader
	swirl.set_shader_parameter("outer", color)
	disc.material_override = swirl
	_swirl = swirl
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	# A round stone step in front of and under the ring.
	MeshUtil.cylinder(self, 2.6, 2.8, 0.25, Color("a59fb5"), Vector3(0, 0.12, 0))
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = 7.0
	light.position = Vector3(0, RING_RADIUS + 0.35, 0.6)
	add_child(light)

	var sign := Label3D.new()
	sign.text = portal_title
	sign.font = UiTheme.font(700, true)
	sign.font_size = 72
	sign.pixel_size = 0.008
	sign.outline_size = 18
	sign.outline_modulate = Color(0.16, 0.1, 0.3)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position.y = RING_RADIUS * 2.0 + 1.3
	add_child(sign)
	_sign = sign

	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(RING_RADIUS * 1.6, RING_RADIUS * 2.0, 0.8)
	shape.shape = box
	shape.position.y = RING_RADIUS + 0.35
	area.add_child(shape)
	area.body_entered.connect(_on_body_entered)
	add_child(area)
	# The ring itself is solid, so you can only walk in through the middle.
	for side in [-1.0, 1.0]:
		MeshUtil.collider(self, Vector3(0.5, RING_RADIUS * 2.4, 0.5), Vector3(side * (RING_RADIUS + 0.2), RING_RADIUS + 0.35, 0))
	return self


## Locks or opens the portal. `level` is the level it opens at, for the sign.
func set_locked(on: bool, level := 1) -> void:
	locked = on
	_sign.text = "%s\nOpens at level %d" % [title, level] if on else title
	_swirl.set_shader_parameter("outer", Color("8a8799") if on else _color)
	_swirl.set_shader_parameter("inner", Color("d9d6e3") if on else Color(1.0, 0.95, 1.0))
	if on and not _padlock:
		_padlock = Sprite3D.new()
		_padlock.texture = UiTheme.icon("locked")
		_padlock.pixel_size = 0.015
		_padlock.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		# Drawn after the see-through swirl, so it shows in front from either side.
		_padlock.render_priority = 10
		_padlock.shaded = false
		_padlock.position.y = RING_RADIUS + 0.35
		add_child(_padlock)
		# A thin wall in the ring; thin enough that bumping it still counts as walking in.
		_barrier = StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(RING_RADIUS * 2.0, RING_RADIUS * 2.0, 0.1)
		shape.shape = box
		_barrier.add_child(shape)
		_barrier.position.y = RING_RADIUS + 0.35
		add_child(_barrier)
	if _padlock:
		_padlock.visible = on
		(_barrier.get_child(0) as CollisionShape3D).set_deferred("disabled", not on)


## Where to stand when arriving through this portal: far enough in front of
## it that you don't walk straight back in and the camera is clear of the ring.
func arrival_point() -> Vector3:
	return to_global(Vector3(0, 0.5, 7.0))


## The camera direction that looks away from the portal on arrival.
func arrival_yaw() -> float:
	# A camera yaw of 0 looks toward -Z; the arrival spot is on the portal's +Z side.
	return global_rotation.y + PI


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func _on_body_entered(body: Node3D) -> void:
	if _cooldown > 0.0 or not body is Player or not body.is_multiplayer_authority():
		return
	_cooldown = 1.5
	if locked:
		knocked.emit(body)
	else:
		entered.emit(body)
