class_name SkyGarden
extends Node3D
## The Sky Garden: a flower-covered island floating high above Starfall Glade,
## the first place that opens with a level (level 5, see Levels.AREAS). A
## portal at the castle door takes you up; golden acorns grow here more often
## than anywhere else, and from the edge you can see the whole glade below.
##
## It belongs to the glade's scene (World puts it there), so it shows and hides
## with the glade and players up here are synced like everywhere else. Its
## origin is the middle of the island's grass. Without the licensed art the
## island is a grassy disc on a rocky cone, with shapes for flowers.

## The walkable circle; a low fence and an invisible wall stand just inside it.
const RADIUS := 14.0
const ISLAND := "flying_stone/flying_stone_003"
const TREES := ["vegetation/fabulous_tree_003", "vegetation/fabulous_tree_024", "vegetation/fabulous_tree_053",
	"vegetation/fabulous_tree_066"]
const FLOWERS := ["vegetation/fabulous_plant_001", "vegetation/fabulous_plant_002", "vegetation/fabulous_plant_006",
	"vegetation/fabulous_plant_008", "vegetation/fabulous_plant_009", "vegetation/fabulous_plant_010",
	"vegetation/fabulous_plant_012", "vegetation/fabulous_plant_022"]
const MUSHROOMS := ["vegetation/fabulous_mushroom_038", "vegetation/fabulous_mushroom_041",
	"vegetation/fabulous_mushroom_045"]
const CRYSTAL := "vegetation/fabulous_plant_026"
const LAMP := "prop/lamp_magic_001"
const FENCE := "prop/fence_001"
## A bird that flaps around the middle.
const BIRD := "animals/fantasy_animal_013"
const GRASS := Color("8fdc8a")
const ROCK := Color("b39b8a")
## Where the portal back down stands, near the edge so you arrive with the
## garden in front of you.
const PORTAL_SPOT := Vector3(0, 0, -11.5)

var portal: Portal
var _bird: Node3D
var _time := 0.0


static func art_paths() -> Array:
	var paths := []
	for model in TREES + FLOWERS + MUSHROOMS + [ISLAND, CRYSTAL, LAMP, FENCE, BIRD]:
		paths.append(FantasyLand.DIR + model)
	return paths


func _init() -> void:
	name = "SkyGarden"


func _ready() -> void:
	var fancy := Art.has(FantasyLand.DIR + ISLAND)
	_island(fancy)
	_edge(fancy)
	portal = Portal.new().setup("Back to the Glade", Color("7fd8ff"))
	portal.position = PORTAL_SPOT
	add_child(portal)
	if fancy:
		_garden()
	else:
		_plain_garden()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _bird == null:
		return
	_time += delta
	var a := _time * 0.35
	_bird.position = Vector3(cos(a) * 6.0, 4.5 + sin(_time * 1.3) * 0.6, sin(a) * 6.0)
	_bird.rotation.y = atan2(-sin(a), cos(a))


## Open spots for acorns on the grass, the same for everyone.
func acorn_spots(count: int) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7070
	var out: Array[Vector3] = []
	while out.size() < count:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (RADIUS - 2.0)
		var spot := Vector3(cos(a) * r, 0, sin(a) * r)
		# Not in the portal or the crystal in the middle.
		if spot.distance_to(PORTAL_SPOT) > 4.0 and spot.length() > 3.0:
			out.append(spot)
	return out


# --- The island ---------------------------------------------------------------------

func _island(fancy: bool) -> void:
	# Walk on a flat disc; the model's grass top sits at its height.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RADIUS + 1.0
	cyl.height = 2.0
	shape.shape = cyl
	body.add_child(shape)
	body.position.y = -1.0
	add_child(body)
	if fancy:
		var island := Art.instance(FantasyLand.DIR + ISLAND)
		var box := Art.bounds(island)
		var s := (RADIUS + 2.5) * 2.0 / maxf(box.size.x, box.size.z)
		island.scale = Vector3.ONE * s
		# The grass top is a little below the model's highest point.
		island.position.y = -box.end.y * s + 0.25
		FantasyLand._no_shadow(island)
		add_child(island)
		return
	var top := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS + 1.5
	disc.bottom_radius = RADIUS + 0.5
	disc.height = 1.0
	top.mesh = disc
	top.material_override = _flat(GRASS)
	top.position.y = -0.5
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(top)
	var under := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = RADIUS + 0.5
	cone.bottom_radius = 1.0
	cone.height = 12.0
	under.mesh = cone
	under.material_override = _flat(ROCK)
	under.position.y = -7.0
	under.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(under)


## A ring of fence posts around the edge, and an invisible wall so nobody falls off.
func _edge(fancy: bool) -> void:
	var count := 40
	for i in count:
		var a := TAU * i / count
		var spot := Vector3(cos(a), 0, sin(a)) * (RADIUS + 0.4)
		var wall := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.6, 4.0, TAU * (RADIUS + 0.4) / count + 0.3)
		shape.shape = box
		wall.add_child(shape)
		wall.position = spot + Vector3(0, 2.0, 0)
		wall.rotation.y = -a
		add_child(wall)
		# Leave a gap behind the portal; the wall still closes it.
		if fancy and i % 2 == 0 and spot.distance_to(PORTAL_SPOT) > 5.0:
			var fence := _put(FENCE, spot, -a + PI / 2, 0.0)
			fence.scale = Vector3.ONE * 1.1


func _garden() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	# A tall glowing crystal in the middle, with lamps around it.
	var crystal := _put(CRYSTAL, Vector3.ZERO, 0.4, 3.6)
	FantasyLand._glow(crystal, Color("ffb3e6"), 4.0)
	# As wide as the crystal, so the camera stops outside it too.
	var width := maxf(Art.bounds(crystal).size.x, Art.bounds(crystal).size.z) * crystal.scale.x * 0.75
	_solid(crystal, Vector3(width, 3.0, width))
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		_put(LAMP, Vector3(cos(a), 0, sin(a)) * 3.4, a, 2.4)
	# Trees around the edge, with space between for the view.
	for i in TREES.size():
		var a := TAU * i / TREES.size() + PI / 4
		var spot := Vector3(cos(a), 0, sin(a)) * (RADIUS - 3.0)
		var tree := _put(TREES[i], spot, rng.randf() * TAU, rng.randf_range(5.5, 7.0))
		_solid(tree, Vector3(0.7, 3.0, 0.7))
	# Rings of flowers, thickest near the middle, and a few mushrooms.
	for i in 70:
		var a := rng.randf() * TAU
		var r := lerpf(4.5, RADIUS - 1.2, sqrt(rng.randf()))
		var spot := Vector3(cos(a), 0, sin(a)) * r
		if spot.distance_to(PORTAL_SPOT) < 3.5:
			continue
		var flower := _put(FLOWERS[rng.randi() % FLOWERS.size()], spot, rng.randf() * TAU, 0.0)
		flower.scale *= rng.randf_range(0.9, 1.3)
	for i in 8:
		var a := rng.randf() * TAU
		var spot := Vector3(cos(a), 0, sin(a)) * rng.randf_range(6.0, RADIUS - 2.0)
		if spot.distance_to(PORTAL_SPOT) > 3.5:
			_put(MUSHROOMS[i % MUSHROOMS.size()], spot, rng.randf() * TAU, rng.randf_range(0.8, 1.4))
	_bird = _put(BIRD, Vector3(6, 4.5, 0), 0.0, 1.6)
	FantasyLand._play(_bird, "Fly")


## Without the licensed models: a glowing pillar and dots of color for flowers.
func _plain_garden() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var pillar := MeshUtil.cylinder(self, 0.6, 0.9, 3.0, Color("ffb3e6"), Vector3(0, 1.5, 0))
	pillar.material_override = _flat(Color("ffb3e6"))
	MeshUtil.collider(self, Vector3(1.2, 3.0, 1.2), Vector3(0, 1.5, 0))
	var colors := [Color("ff6fa8"), Color("ffcf3a"), Color("9b6bff"), Color("4b9cff"), Color.WHITE]
	for i in 50:
		var a := rng.randf() * TAU
		var spot := Vector3(cos(a), 0, sin(a)) * lerpf(3.0, RADIUS - 1.0, sqrt(rng.randf()))
		if spot.distance_to(PORTAL_SPOT) > 3.0:
			MeshUtil.sphere(self, 0.22, colors[i % colors.size()], spot + Vector3(0, 0.25, 0))


func _put(model: String, pos: Vector3, yaw: float, height: float) -> Node3D:
	var node := Art.instance(FantasyLand.DIR + model)
	if height > 0.0:
		node.scale = Vector3.ONE * height / maxf(Art.bounds(node).size.y, 0.01)
	node.position = pos
	node.rotation.y = yaw
	add_child(node)
	return node


## A box collider of `size` at the bottom middle of a model.
func _solid(node: Node3D, size: Vector3) -> void:
	MeshUtil.collider(self, size, node.position + Vector3(0, size.y / 2.0, 0))


static func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat
