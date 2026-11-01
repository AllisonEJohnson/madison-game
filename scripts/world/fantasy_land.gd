class_name FantasyLand
extends Node3D
## Starfall Glade, a magical land reached through the portal in town.
##
## It sits in the same scene as the town, far off to the side (see World), so
## players here are seen and synced exactly like everywhere else. A path runs
## from the arrival portal to a plaza with a glowing crystal; a mushroom
## village lies to the west, a pond with animals to the east and a castle to
## the north, with floating islands overhead and mountains all around.
##
## Models come from the licensed Fantasy pack (see Art). Copies of the game
## without it get the same ground, paths, pond and portal, with forest trees
## and simple shapes standing in, so the portal always leads somewhere.

## Half the width of the walkable square; invisible walls stop you there.
const HALF := 58.0
const PORTAL_SPOT := Vector3(0, 0, 44)
const PLAZA := Vector3(0, 0, 6)
const VILLAGE := Vector3(-30, 0, 4)
const POND := Vector3(30, 0, 8)
const POND_RADIUS := 9.0
const CASTLE_Z := -50.0
## The Star Chase ring, beside the path just past the portal, so it's the
## first thing you see on arriving. Stars fall around the market and plaza.
const CHASE_SPOT := Vector3(-5, 0, 38.5)
const CHASE_FIELD := Vector3(0, 0, 22)
## The market stall that is the glade's shop, and which way it faces.
const SHOP_STALL := Vector3(-7, 0, 31)

const GRASS := Color("74cf8e")
const PLAZA_STONE := Color("e6d7f2")

const DIR := "Fantasy/prefabs/assets/"
const TREES := ["vegetation/fabulous_tree_001", "vegetation/fabulous_tree_002", "vegetation/fabulous_tree_003",
	"vegetation/fabulous_tree_005", "vegetation/fabulous_tree_007", "vegetation/fabulous_tree_008",
	"vegetation/fabulous_tree_010", "vegetation/fabulous_tree_024", "vegetation/fabulous_tree_025",
	"vegetation/fabulous_tree_026", "vegetation/fabulous_tree_053", "vegetation/fabulous_tree_054",
	"vegetation/fabulous_tree_056", "vegetation/fabulous_tree_064", "vegetation/fabulous_tree_066",
	"vegetation/fabulous_tree_069", "vegetation/fabulous_tree_070"]
## Landmark trees, a few of each.
const BIG_TREES := ["vegetation/big_fabulous_tree_001", "vegetation/big_fabulous_tree_004",
	"vegetation/big_fabulous_tree_006", "vegetation/big_fabulous_tree_007", "vegetation/big_fabulous_tree_008"]
const BUSHES := ["vegetation/bush_015", "vegetation/bush_016", "vegetation/bush_023", "vegetation/bush_024"]
const FLOWERS := ["vegetation/fabulous_plant_001", "vegetation/fabulous_plant_002", "vegetation/fabulous_plant_006",
	"vegetation/fabulous_plant_008", "vegetation/fabulous_plant_009", "vegetation/fabulous_plant_010",
	"vegetation/fabulous_plant_012", "vegetation/fabulous_plant_022", "vegetation/fabulous_plant_023",
	"vegetation/fabulous_plant_024"]
## Turnip-like plants for the village garden.
const VEGGIES := ["vegetation/fabulous_plant_013", "vegetation/fabulous_plant_015",
	"vegetation/fabulous_plant_016", "vegetation/fabulous_plant_020"]
const MUSHROOMS := ["vegetation/fabulous_mushroom_038", "vegetation/fabulous_mushroom_040",
	"vegetation/fabulous_mushroom_041", "vegetation/fabulous_mushroom_045", "vegetation/fabulous_mushroom_046",
	"vegetation/fabulous_mushroom_034"]
const GIANT_MUSHROOMS := ["vegetation/fabulous_mushroom_012", "vegetation/fabulous_mushroom_019",
	"vegetation/fabulous_mushroom_020", "vegetation/fabulous_mushroom_023", "vegetation/fabulous_mushroom_018"]
const CRYSTAL := "vegetation/fabulous_plant_026"
const LILY := "vegetation/water_lily_004"
## The village homes and how tall each stands.
const HOMES := [["building/house_004", 5.5], ["building/house_014", 8.5], ["building/house_001", 6.0],
	["building/house_005", 7.0], ["building/house_010", 9.0], ["building/house_009", 5.5]]
const PATCHES := ["ground/ground_003", "ground/ground_005", "ground/ground_009", "ground/ground_011"]
const MOUNTAINS := ["mountain/mountain_005", "mountain/mountain_007", "mountain/mountain_008",
	"mountain/mountain_009", "mountain/mountain_001"]
const ISLANDS := ["flying_stone/flying_stone_003", "flying_stone/flying_stone_004"]
const PEBBLE_STONES := ["flying_stone/flying_stone_001", "flying_stone/flying_stone_008"]
const EDGE_STONES := ["stone/stone_027", "stone/stone_030", "stone/stone_033", "stone/stone_036"]
const ROCKS := ["rock/rock_005", "rock/rock_012", "rock/rock_021"]
const PROPS := {
	"pillar": "ruins/ruins_005", "arch": "ruins/ruins_008", "well": "building/well_001",
	"orb_lamp": "prop/lamp_magic_001", "tall_lamp": "prop/lamp_magic_003", "sign": "prop/pointer_002",
	"stall_a": "prop/stall_001", "stall_b": "prop/stall_005", "stall_c": "prop/stall_002",
	"fire": "prop/bonfire_002", "log": "prop/log_001", "barrel": "prop/barrel_001", "crate": "prop/box_005",
	"castle": "building/castle_main_building_001", "tower": "building/castle_tower_002",
	"wall": "building/castle_wall_001", "fence": "prop/fence_001",
}
## Animals: model, spot, facing (degrees), height, clip to loop ("" for none).
const ANIMALS := [
	["animals/fantasy_animal_009", Vector3(10, 0, -1), -130.0, 2.6, ""],
	["animals/fantasy_animal_011", Vector3(44, 0, -6), -100.0, 2.3, ""],
	["animals/fantasy_animal_014", Vector3(41, 0, -10), -70.0, 2.0, ""],
	["animals/fantasy_animal_006", Vector3(-14, 0, -30), 40.0, 1.9, ""],
	["animals/fantasy_animal_008", Vector3(-11.5, 0, -28), 70.0, 0.9, ""],
	["animals/fantasy_animal_004", Vector3(22, 0, -22), 200.0, 1.5, ""],
	["animals/fantasy_animal_005", Vector3(24.5, 0, -20), 230.0, 0.8, ""],
	["animals/fantasy_animal_001", Vector3(44, 0, 32), -140.0, 3.4, "Head"],
	["animals/fantasy_animal_010", Vector3(9, 0, -36), -20.0, 2.2, "Head"],
	["animals/fantasy_animal_013", Vector3(-14, 0, 26), 120.0, 2.4, "Fly"],
]
## Animals that stroll in circles: model, circle center, radius, height,
## laps per minute (negative goes the other way), starting angle (degrees).
const WALKERS := [
	["animals/fantasy_animal_002", POND, 14.0, 3.6, 0.8, 0.0],
	["animals/fantasy_animal_003", POND, 14.0, 1.9, 0.8, -26.0],
	["animals/fantasy_animal_007", Vector3(-36, 0, -24), 6.0, 2.0, -1.2, 90.0],
]

var portal: Portal
var chase: StarChase
## Offers the shop at the market stall nearest the portal.
var shop_zone: InteractZone
var _floaters: Array[Dictionary] = [] # {node, base, phase, speed, height}
var _walkers: Array[Dictionary] = [] # {node, center, radius, speed, angle}
var _time := 0.0
static var _sizes := {}


static func art_paths() -> Array:
	var paths := []
	for list in [TREES, BIG_TREES, BUSHES, FLOWERS, VEGGIES, MUSHROOMS, GIANT_MUSHROOMS, PATCHES, MOUNTAINS,
			ISLANDS, PEBBLE_STONES, EDGE_STONES, ROCKS, PROPS.values(), [CRYSTAL, LILY]]:
		for model in list:
			paths.append(DIR + model)
	for list in [HOMES, ANIMALS, WALKERS]:
		for entry in list:
			paths.append(DIR + entry[0])
	return paths


func _init() -> void:
	name = "StarfallGlade"


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 # Same land for everyone.
	_ground()
	portal = Portal.new().setup("Back to Town", Color("7fd8ff"))
	portal.position = PORTAL_SPOT
	portal.rotation.y = PI
	add_child(portal)
	chase = StarChase.new()
	chase.position = CHASE_SPOT
	chase.field_center = CHASE_FIELD - CHASE_SPOT
	add_child(chase)
	var fancy := Art.has(DIR + TREES[0])
	_shop(fancy)
	_pond(fancy)
	if fancy:
		_plaza()
		_village(rng)
		_castle()
		_market()
		_animals()
		_sky(rng)
		_mountains(rng)
	else:
		_plain_landmarks()
	_plants(rng, fancy)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	for f in _floaters:
		var node: Node3D = f["node"]
		node.position.y = f["base"].y + sin(_time * f["speed"] + f["phase"]) * f["height"]
		node.rotation.y += delta * 0.05
	for w in _walkers:
		w["angle"] += delta * w["speed"]
		var node: Node3D = w["node"]
		var a: float = w["angle"]
		node.position = w["center"] + Vector3(cos(a), 0, sin(a)) * w["radius"]
		# Faces along the circle (models look toward +Z).
		var forward := Vector3(-sin(a), 0, cos(a)) * signf(w["speed"])
		node.rotation.y = atan2(forward.x, forward.z)


# --- Ground, paths and edges ------------------------------------------------------

func _ground() -> void:
	var grass := MeshUtil.box(self, Vector3(260, 1, 260), GRASS, Vector3(0, -0.5, 0))
	MeshUtil.collider(self, Vector3(260, 1, 260), Vector3(0, -0.5, 0))
	# Paths from the portal to the plaza, and from there to each area, worn
	# into the grass (see Surfaces), with a clearing for the village.
	Surfaces.ground(grass, Surfaces.GLADE_GROUND, [
		Surfaces.strip(Vector3(4, 0, PORTAL_SPOT.z - PLAZA.z), Vector3(0, 0, (PORTAL_SPOT.z + PLAZA.z) / 2)),
		Surfaces.strip(Vector3(4, 0, PLAZA.z - CASTLE_Z - 14), Vector3(0, 0, (PLAZA.z + CASTLE_Z + 14) / 2)),
		Surfaces.strip(Vector3(absf(VILLAGE.x) - 6, 0, 3.5), Vector3(VILLAGE.x / 2 - 3, 0, VILLAGE.z)),
		Surfaces.strip(Vector3(POND.x - POND_RADIUS - 2, 0, 3.5), Vector3((POND.x - POND_RADIUS) / 2, 0, POND.z)),
		Vector3(VILLAGE.x, VILLAGE.z, 8),
	])
	Surfaces.paving(MeshUtil.cylinder(self, 10, 10, 0.04, PLAZA_STONE, PLAZA + Vector3(0, 0.02, 0)), 10, Surfaces.GLADE_PAVING)
	# Invisible walls at the edge; trees and mountains hide them.
	for side in [-1.0, 1.0]:
		MeshUtil.collider(self, Vector3(HALF * 2, 12, 1), Vector3(0, 6, side * HALF))
		MeshUtil.collider(self, Vector3(1, 12, HALF * 2), Vector3(side * HALF, 6, 0))


func _pond(fancy: bool) -> void:
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = POND_RADIUS
	disc.bottom_radius = POND_RADIUS
	disc.height = 0.1
	disc.radial_segments = 48
	disc.rings = 1
	water.mesh = disc
	Surfaces.water(water, POND_RADIUS)
	water.position = POND + Vector3(0, 0.05, 0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	# You walk around the pond, not across it.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = POND_RADIUS - 0.3
	cyl.height = 4.0
	shape.shape = cyl
	body.add_child(shape)
	body.position = POND + Vector3(0, 2, 0)
	add_child(body)
	if not fancy:
		MeshUtil.torus(self, POND_RADIUS - 0.2, POND_RADIUS + 0.6, Color("c9c1d6"), POND + Vector3(0, 0.05, 0), Vector3.ZERO, 48)
		return
	var count := 26
	for i in count:
		var a := TAU * i / count
		var stone := _put(EDGE_STONES[i % EDGE_STONES.size()], POND + Vector3(cos(a), 0, sin(a)) * (POND_RADIUS + 0.3), a * 3.0, 0.0)
		stone.scale = Vector3.ONE * 1.6
	for i in 9:
		var a := TAU * i / 9.0 + 0.4
		var r := POND_RADIUS * (0.45 + 0.35 * fmod(i * 0.37, 1.0))
		var lily := _put(LILY, POND + Vector3(cos(a) * r, 0.11, sin(a) * r), a, 0.0)
		lily.scale = Vector3.ONE * 2.2
	for a in [0.9, 2.6, 4.4]:
		_put(CRYSTAL, POND + Vector3(cos(a), 0, sin(a)) * (POND_RADIUS + 2.2), a, 1.8)


# --- Landmarks -----------------------------------------------------------------------

func _plaza() -> void:
	# A tall glowing crystal on a round stand, ringed by old pillars.
	MeshUtil.cylinder(self, 2.2, 2.6, 0.6, Color("c9bde0"), PLAZA + Vector3(0, 0.3, 0))
	MeshUtil.collider(self, Vector3(3.6, 1, 3.6), PLAZA + Vector3(0, 0.5, 0))
	var crystal := _put(CRYSTAL, PLAZA + Vector3(0, 0.55, 0), 0.3, 4.0)
	_glow(crystal, Color("8fe9ff"), 6.0)
	for i in 8:
		var a := TAU * i / 8.0 + TAU / 16.0
		var pillar := _put(PROPS["pillar"], PLAZA + Vector3(cos(a), 0, sin(a)) * 8.6, -a, 3.2)
		_solid(pillar, 0.7)
	for a in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		_put(PROPS["orb_lamp"], PLAZA + Vector3(cos(a), 0, sin(a)) * 4.4, a, 2.4)


func _village(rng: RandomNumberGenerator) -> void:
	var well := _put(PROPS["well"], VILLAGE, 0.6, 3.4)
	_solid(well, 0.8)
	# Homes in a ring facing the well, leaving the east side open for the path.
	for i in HOMES.size():
		var a := deg_to_rad(45.0 + 54.0 * i)
		var spot := VILLAGE + Vector3(cos(a), 0, sin(a)) * 14.0
		var home := _put(HOMES[i][0], spot, _facing(spot, VILLAGE), HOMES[i][1])
		_solid(home, 0.8)
		_put(PROPS["tall_lamp"], VILLAGE + Vector3(cos(a + 0.42), 0, sin(a + 0.42)) * 10.5, a, 4.0)
	for i in GIANT_MUSHROOMS.size():
		var a := deg_to_rad(72.0 + 54.0 * i)
		var spot := VILLAGE + Vector3(cos(a), 0, sin(a)) * 21.0
		var mushroom := _put(GIANT_MUSHROOMS[i], spot, rng.randf() * TAU, rng.randf_range(7.0, 9.5))
		_trunk(mushroom, 0.8)
	# A little vegetable garden by the path.
	for x in 4:
		for z in 3:
			var spot := VILLAGE + Vector3(7.5 + x * 1.3, 0, -5.0 - z * 1.4)
			_put(VEGGIES[(x + z * 2) % VEGGIES.size()], spot, rng.randf() * TAU, 0.0)
	_fence_row(VILLAGE + Vector3(6.6, 0, -3.8), 6.0)


func _castle() -> void:
	var castle := _put(PROPS["castle"], Vector3(0, 0, CASTLE_Z), 0.0, 30.0)
	_solid(castle, 0.85)
	for side in [-1.0, 1.0]:
		var wall := _put(PROPS["wall"], Vector3(side * 16.0, 0, CASTLE_Z + 1.0), 0.0, 9.0)
		_solid(wall, 1.0)
		var tower := _put(PROPS["tower"], Vector3(side * 24.0, 0, CASTLE_Z + 1.0), 0.0, 23.0)
		_solid(tower, 0.8)
	# An old stone arch on the path to the castle.
	var arch := _put(PROPS["arch"], Vector3(0, 0, -24), 0.0, 9.0)
	var box := Art.bounds(arch)
	for side in [-1.0, 1.0]:
		MeshUtil.collider(arch, Vector3(box.size.x * 0.16, box.size.y, box.size.z * 0.7),
				Vector3(side * box.size.x * 0.4, box.size.y / 2, box.get_center().z))


func _market() -> void:
	var sign := _put(PROPS["sign"], PORTAL_SPOT + Vector3(3.6, 0, -6), PI * 0.8, 2.6)
	_solid(sign, 0.6)
	var stalls := [["stall_b", Vector3(7.2, 0, 26), -PI / 2], ["stall_c", Vector3(-7, 0, 20), PI / 2]]
	for s in stalls:
		var stall := _put(PROPS[s[0]], s[1], s[2], 2.7)
		_solid(stall, 0.8)
	for spot in [Vector3(-9, 0, 28.5), Vector3(-8.6, 0, 33.4), Vector3(9.3, 0, 24)]:
		_solid(_put(PROPS["barrel"], spot, spot.x, 1.0), 0.8)
	_solid(_put(PROPS["crate"], Vector3(9.2, 0, 28.3), 0.4, 0.8), 0.9)
	# A campfire with log seats, a cozy place to meet.
	var fire_spot := Vector3(10, 0, 37)
	var fire := _put(PROPS["fire"], fire_spot, 0.0, 1.2)
	_glow(fire, Color("ffb35c"), 2.5)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		_put(PROPS["log"], fire_spot + Vector3(cos(a), 0, sin(a)) * 2.3, -a, 0.6)


## The market stall by the portal is a shop. Without the licensed art a stall
## made of shapes stands there instead.
func _shop(fancy: bool) -> void:
	if not fancy:
		var stall := ShopStall.new()
		stall.position = SHOP_STALL
		stall.rotation.y = PI / 2
		add_child(stall)
		shop_zone = stall.zone
		return
	var model := _put(PROPS["stall_a"], SHOP_STALL, PI / 2, 2.7)
	_solid(model, 0.8)
	var sign := Label3D.new()
	sign.text = "Shop"
	sign.font = UiTheme.font(700, true)
	sign.font_size = 72
	sign.pixel_size = 0.008
	sign.outline_size = 18
	sign.outline_modulate = Color(0.16, 0.1, 0.3)
	sign.modulate = Color("fff3b0")
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = SHOP_STALL + Vector3(0, 3.6, 0)
	add_child(sign)
	shop_zone = InteractZone.new().setup("Shop", "Furniture and clothes", "shopping_bags", "Shop", 2.0)
	shop_zone.position = SHOP_STALL + Vector3(2.4, 0, 0)
	add_child(shop_zone)


## Open spots for acorns, the same for everyone.
func acorn_spots(count: int) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var out: Array[Vector3] = []
	for i in count:
		out.append(_open_spot(rng, 1.0))
	return out


func _animals() -> void:
	for entry in ANIMALS:
		var animal := _put(entry[0], entry[1], deg_to_rad(entry[2]), entry[3])
		_play(animal, entry[4])
		_solid(animal, 0.6)
	for entry in WALKERS:
		var animal := _put(entry[0], entry[1], 0.0, entry[3])
		_play(animal, "Walk")
		_walkers.append({"node": animal, "center": entry[1], "radius": entry[2],
			"speed": TAU * entry[4] / 60.0, "angle": deg_to_rad(entry[5])})


## Floating islands drifting high above the land.
func _sky(rng: RandomNumberGenerator) -> void:
	var spots := [Vector3(-22, 17, -16), Vector3(24, 21, -30), Vector3(38, 15, 30), Vector3(-40, 19, 30),
		Vector3(-8, 24, -38)]
	for i in spots.size():
		var island := _put(ISLANDS[i % ISLANDS.size()], spots[i], rng.randf() * TAU, 0.0)
		island.scale = Vector3.ONE * rng.randf_range(0.9, 1.3)
		_floaters.append({"node": island, "base": spots[i], "phase": rng.randf() * TAU,
			"speed": rng.randf_range(0.35, 0.55), "height": 0.8})
		for j in 3:
			var offset := Vector3(rng.randf_range(-9, 9), rng.randf_range(-5, 3), rng.randf_range(-9, 9))
			var pebble := _put(PEBBLE_STONES[j % PEBBLE_STONES.size()], spots[i] + offset, rng.randf() * TAU, 0.0)
			pebble.scale = Vector3.ONE * rng.randf_range(0.8, 1.4)
			_floaters.append({"node": pebble, "base": pebble.position, "phase": rng.randf() * TAU,
				"speed": rng.randf_range(0.5, 0.9), "height": 0.5})


func _mountains(rng: RandomNumberGenerator) -> void:
	var count := 14
	for i in count:
		var a := TAU * i / count + rng.randf_range(-0.1, 0.1)
		var dist := rng.randf_range(92.0, 104.0)
		var model: String = MOUNTAINS[i % (MOUNTAINS.size() - 1)]
		# The tall spire stands behind the castle.
		if i == count * 3 / 4:
			model = MOUNTAINS[-1]
		var mountain := _put(model, Vector3(cos(a), 0, sin(a)) * dist, _facing(Vector3(cos(a), 0, sin(a)), Vector3.ZERO), 0.0)
		mountain.scale = Vector3.ONE * (1.0 if model == MOUNTAINS[-1] else rng.randf_range(1.8, 2.4))
		_no_shadow(mountain)


## Without the licensed models: big toadstools made of shapes mark the plaza
## and the village, so the land still has landmarks.
func _plain_landmarks() -> void:
	MeshUtil.cylinder(self, 2.2, 2.6, 0.6, Color("c9bde0"), PLAZA + Vector3(0, 0.3, 0))
	MeshUtil.collider(self, Vector3(3.6, 1, 3.6), PLAZA + Vector3(0, 0.5, 0))
	var gem := MeshUtil.sphere(self, 1.2, Color("8fe9ff"), PLAZA + Vector3(0, 2.2, 0), Vector3(1, 1.6, 1))
	_glow(gem, Color("8fe9ff"), 3.0)
	var caps := [Color("ff6b8b"), Color("a98bff"), Color("ffb85c"), Color("5cd6ff")]
	for i in 6:
		var a := deg_to_rad(45.0 + 54.0 * i)
		var spot := VILLAGE + Vector3(cos(a), 0, sin(a)) * 14.0
		MeshUtil.cylinder(self, 0.9, 1.2, 4.0, Color("f4ead8"), spot + Vector3(0, 2, 0))
		MeshUtil.sphere(self, 3.0, caps[i % caps.size()], spot + Vector3(0, 4.2, 0), Vector3(1, 0.55, 1))
		MeshUtil.collider(self, Vector3(2, 4, 2), spot + Vector3(0, 2, 0))


# --- Plants ----------------------------------------------------------------------------

func _plants(rng: RandomNumberGenerator, fancy: bool) -> void:
	if not fancy:
		for i in 110:
			Scenery.tree(self, _open_spot(rng, 3.0) if i < 60 else _edge_spot(rng), rng)
		return
	for i in 70:
		_tree(TREES[rng.randi() % TREES.size()], _open_spot(rng, 3.0), rng, rng.randf_range(6.0, 9.0))
	for i in 10:
		_tree(BIG_TREES[i % BIG_TREES.size()], _open_spot(rng, 5.0), rng, rng.randf_range(10.0, 13.0))
	# A thick ring of trees hides the walls at the edge.
	for i in 90:
		_tree(TREES[rng.randi() % TREES.size()], _edge_spot(rng), rng, rng.randf_range(7.0, 11.0))
	for i in 40:
		var bush := _put(BUSHES[i % BUSHES.size()], _open_spot(rng, 1.5), rng.randf() * TAU, rng.randf_range(1.0, 1.8))
		_no_shadow(bush)
	for i in 34:
		var patch := _open_spot(rng, 2.0)
		for j in 5:
			var spot := patch + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))
			var flower := _put(FLOWERS[(i + j) % FLOWERS.size()], spot, rng.randf() * TAU, rng.randf_range(0.7, 1.3))
			_no_shadow(flower)
	for i in 30:
		var patch := _open_spot(rng, 1.5)
		for j in 3:
			var spot := patch + Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))
			_no_shadow(_put(MUSHROOMS[(i + j) % MUSHROOMS.size()], spot, rng.randf() * TAU, rng.randf_range(0.5, 1.1)))
	for i in 12:
		var rock := _put(ROCKS[i % ROCKS.size()], _open_spot(rng, 3.0), rng.randf() * TAU, rng.randf_range(1.6, 2.6))
		_solid(rock, 0.8)
	# Soft colored patches in the grass.
	for i in 22:
		var patch := _put(PATCHES[i % PATCHES.size()], _open_spot(rng, 4.0) + Vector3(0, -0.32, 0), rng.randf() * TAU, 0.0)
		patch.scale = Vector3(rng.randf_range(1.0, 1.6), 0.5, rng.randf_range(1.0, 1.6))
		_no_shadow(patch)


## A random spot on open grass, `room` meters clear of paths and landmarks.
func _open_spot(rng: RandomNumberGenerator, room: float) -> Vector3:
	for attempt in 200:
		var p := Vector3(rng.randf_range(-HALF + 4, HALF - 4), 0, rng.randf_range(-HALF + 4, HALF - 4))
		var on_main_path := absf(p.x) < 3.0 + room and p.z > CASTLE_Z + 10 and p.z < PORTAL_SPOT.z + 6
		var on_side_path := absf(p.z - PLAZA.z) < 2.5 + room and p.x > VILLAGE.x and p.x < POND.x
		var busy := p.distance_to(PLAZA) < 11 + room or p.distance_to(VILLAGE) < 17 + room \
				or p.distance_to(POND) < POND_RADIUS + 5 + room or p.distance_to(PORTAL_SPOT) < 8 + room \
				or (absf(p.x) < 30 + room and p.z < CASTLE_Z + 12 + room) \
				or (absf(p.x) < 12 + room and p.z > 17 - room and p.z < 40 + room)
		if not (on_main_path or on_side_path or busy):
			return p
	return Vector3(-HALF + 6, 0, -HALF + 6)


func _edge_spot(rng: RandomNumberGenerator) -> Vector3:
	var along := rng.randf_range(-HALF - 8, HALF + 8)
	var depth := rng.randf_range(HALF - 3, HALF + 8) * (1.0 if rng.randf() < 0.5 else -1.0)
	return Vector3(along, 0, depth) if rng.randf() < 0.5 else Vector3(depth, 0, along)


# --- Helpers ---------------------------------------------------------------------------

## Places a model from the pack, scaled to stand `height` meters tall (0 keeps
## its own size).
func _put(model: String, pos: Vector3, yaw: float, height: float) -> Node3D:
	var node := Art.instance(DIR + model)
	if height > 0.0:
		node.scale = Vector3.ONE * height / maxf(_size(model, node).y, 0.01)
	node.position = pos
	node.rotation.y = yaw
	add_child(node)
	return node


func _tree(model: String, pos: Vector3, rng: RandomNumberGenerator, height: float) -> void:
	var tree := _put(model, pos, rng.randf() * TAU, height)
	_trunk(tree, 0.7)


## A post-shaped collider up the middle, so you bump into the trunk only.
func _trunk(node: Node3D, width: float) -> void:
	var s := node.scale.x
	MeshUtil.collider(node, Vector3(width, 3.0, width) / s, Vector3(0, 1.5, 0) / s)


## A box collider around the model, `shrink` times its width.
func _solid(node: Node3D, shrink: float) -> void:
	var box := Art.bounds(node)
	MeshUtil.collider(node, box.size * Vector3(shrink, 1, shrink), box.get_center())


func _fence_row(start: Vector3, length: float) -> void:
	var step := 1.9
	for i in int(length / step):
		_put(PROPS["fence"], start + Vector3(i * step + step / 2, 0, 0), 0.0, 0.0)


static func _facing(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(d.x, d.z)


static func _size(model: String, node: Node3D) -> Vector3:
	if not _sizes.has(model):
		_sizes[model] = Art.bounds(node).size
	return _sizes[model]


## Loops one of the model's own animations.
static func _play(node: Node3D, clip: String) -> void:
	var player := node.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if clip == "" or player == null or not player.has_animation(clip):
		return
	player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	player.play(clip)


## Adds a soft colored light to a model. Each light costs draw time in
## browsers, so only a few landmarks get one.
static func _glow(node: Node3D, color: Color, energy: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 6.0
	light.position = Vector3(0, Art.bounds(node).end.y * 0.7, 0)
	node.add_child(light)


static func _no_shadow(node: Node3D) -> void:
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
