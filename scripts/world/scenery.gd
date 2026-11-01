class_name Scenery
extends RefCounted
## The neighborhood's ground, roads, plaza and greenery. With the licensed art
## installed, trees, bushes, stones and most flowers come from the Fantasy
## pack's natural-looking models. Without it they come from the free KayKit
## Forest Nature Pack in assets/kaykit_forest (CC0, always in the repo), which
## also always provides the grass.

const FOREST := "res://assets/kaykit_forest/"
## Trees and how much to scale each, so they all land around 4-6 m tall.
const TREES := [
	["Tree_1_A", 1.0], ["Tree_1_B", 1.0], ["Tree_1_C", 0.65],
	["Tree_2_A", 1.0], ["Tree_2_B", 0.85], ["Tree_2_C", 0.75], ["Tree_2_D", 0.65], ["Tree_2_E", 0.6],
	["Tree_3_A", 1.15], ["Tree_3_B", 1.0], ["Tree_3_C", 0.8],
	["Tree_4_A", 0.9], ["Tree_4_B", 0.75], ["Tree_4_C", 0.5],
]
const BUSHES := ["Bush_1_C", "Bush_1_D", "Bush_1_E", "Bush_3_A", "Bush_3_B", "Bush_3_C"]
## Rocks big enough to bump into, so each gets a collider.
const ROCKS := ["Rock_1_D", "Rock_1_E", "Rock_1_F", "Rock_2_C"]
const PEBBLES := ["Rock_1_A", "Rock_1_B", "Rock_1_C", "Rock_2_B"]
## Grass tufts and how often each is picked. The big clumps cost the most to
## draw, so they are rarer.
const GRASS := [["Grass_1_A", 4], ["Grass_1_B", 3], ["Grass_1_C", 1], ["Grass_1_D", 1],
	["Grass_2_A", 4], ["Grass_2_B", 3], ["Grass_2_C", 1], ["Grass_2_D", 1]]
const GRASS_TUFTS := 1500
## Licensed flower models (the free forest pack has none).
const FLOWERS := ["Animals/prefabs/assets/assets/domestic_assets/flower_01",
	"Animals/prefabs/assets/assets/domestic_assets/flower_02",
	"Animals/prefabs/assets/assets/domestic_assets/flower_03"]
## Fantasy pack models that suit an ordinary town: leafy green trees with a
## few autumn ones, round bushes, gray stones and bright flowers.
const FANTASY := "Fantasy/prefabs/assets/"
const FANTASY_TREES := ["vegetation/big_fabulous_tree_003", "vegetation/big_fabulous_tree_005",
	"vegetation/fabulous_tree_016", "vegetation/fabulous_tree_017", "vegetation/fabulous_tree_018",
	"vegetation/fabulous_tree_019", "vegetation/fabulous_tree_020", "vegetation/fabulous_tree_040",
	"vegetation/fabulous_tree_042", "vegetation/fabulous_tree_044", "vegetation/fabulous_tree_051"]
const FANTASY_AUTUMN_TREES := ["vegetation/fabulous_tree_061", "vegetation/fabulous_tree_062",
	"vegetation/fabulous_tree_063"]
const FANTASY_BUSHES := ["vegetation/bush_015", "vegetation/bush_016", "vegetation/bush_017",
	"vegetation/bush_015", "vegetation/bush_016", "vegetation/bush_021"]
const FANTASY_ROCKS := ["stone/stone_001", "stone/stone_013", "stone/stone_014"]
const FANTASY_PEBBLES := ["stone/stone_002", "stone/stone_003", "stone/stone_004", "stone/stone_012"]
const FANTASY_FLOWERS := ["vegetation/fabulous_plant_001", "vegetation/fabulous_plant_006",
	"vegetation/fabulous_plant_008", "vegetation/fabulous_plant_010"]
## Where the portal to Starfall Glade stands, west of the plaza.
const GLADE_PORTAL := Vector3(-21, 0, 0)
## The shop stall on the east side of the plaza, facing the fountain.
const SHOP_SPOT := Vector3(7.6, 0, 0)

static var _fantasy := false


static func art_paths() -> Array:
	var paths := FLOWERS.duplicate()
	for list in [FANTASY_TREES, FANTASY_AUTUMN_TREES, FANTASY_BUSHES, FANTASY_ROCKS, FANTASY_PEBBLES, FANTASY_FLOWERS]:
		for model in list:
			if not (FANTASY + model) in paths:
				paths.append(FANTASY + model)
	return paths


static func build(ground: Node3D) -> void:
	var grass := MeshUtil.box(ground, Vector3(140, 1, 140), Color("4f9442"), Vector3(0, -0.5, 0))
	MeshUtil.collider(ground, Vector3(140, 1, 140), Vector3(0, -0.5, 0))
	# Roads in front of each row of plots, and one through the plaza, worn
	# into the grass (see Surfaces).
	var roads := []
	for z in [-15.5, 15.5]:
		roads.append(Surfaces.strip(Vector3(106, 0, 3.5), Vector3(0, 0, z)))
	roads.append(Surfaces.strip(Vector3(3.5, 0, 31), Vector3.ZERO))
	# A short path west from the plaza to the portal.
	roads.append(Surfaces.strip(Vector3(absf(GLADE_PORTAL.x) - 6, 0, 3.5), Vector3((GLADE_PORTAL.x - 6) / 2, 0, 0)))
	Surfaces.ground(grass, Surfaces.TOWN_GROUND, roads)
	# Plaza with a fountain.
	Surfaces.paving(MeshUtil.cylinder(ground, 9, 9, 0.04, Color("d6bf96"), Vector3(0, 0.02, 0)), 9, Surfaces.TOWN_PAVING)
	MeshUtil.cylinder(ground, 3.2, 3.4, 0.6, Color("cdbfa9"), Vector3(0, 0.3, 0))
	Surfaces.water(MeshUtil.cylinder(ground, 2.9, 2.9, 0.62, Color(0.35, 0.65, 0.95, 0.85), Vector3(0, 0.32, 0)), 2.9)
	MeshUtil.cylinder(ground, 0.35, 0.5, 1.8, Color("cdbfa9"), Vector3(0, 0.9, 0))
	MeshUtil.sphere(ground, 0.5, Color(0.45, 0.75, 1.0, 0.8), Vector3(0, 2.0, 0))
	var fountain_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 3.4
	cyl.height = 0.6
	shape.shape = cyl
	shape.position.y = 0.3
	fountain_body.add_child(shape)
	ground.add_child(fountain_body)

	_fantasy = Art.has(FANTASY + FANTASY_TREES[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 # Same scenery for everyone.
	for i in 60:
		tree(ground, _open_spot(rng, 14.0), rng, _fantasy)
	# A thick ring of woods hides the edge of the world.
	for i in 90:
		var along := rng.randf_range(-68, 68)
		var depth := rng.randf_range(57, 68) * (1 if rng.randf() < 0.5 else -1)
		tree(ground, Vector3(along, 0, depth) if i % 2 == 0 else Vector3(depth, 0, along), rng, _fantasy)
	for i in 45:
		var spot := _open_spot(rng, 11.0)
		var node := _fantasy_model(ground, FANTASY_BUSHES[i % FANTASY_BUSHES.size()], spot, rng, rng.randf_range(0.9, 1.5)) \
				if _fantasy else _place(ground, BUSHES[i % BUSHES.size()], spot, rng, rng.randf_range(0.8, 1.2))
		_no_shadow(node)
	for i in 20:
		var spot := _open_spot(rng, 11.0)
		var node := _fantasy_model(ground, FANTASY_ROCKS[i % FANTASY_ROCKS.size()], spot, rng, rng.randf_range(0.9, 1.4)) \
				if _fantasy else _place(ground, ROCKS[i % ROCKS.size()], spot, rng, rng.randf_range(0.6, 0.9))
		var box := Art.bounds(node)
		MeshUtil.collider(node, box.size * Vector3(0.8, 1, 0.8), box.get_center())
	for i in 40:
		var spot := _open_spot(rng, 9.5)
		_no_shadow(_fantasy_model(ground, FANTASY_PEBBLES[i % FANTASY_PEBBLES.size()], spot, rng, rng.randf_range(0.3, 0.6))
				if _fantasy else _place(ground, PEBBLES[i % PEBBLES.size()], spot, rng, rng.randf_range(0.5, 1.0)))
	_grass(ground, rng)
	# Flowers come last so copies without the licensed art still match above.
	if not Art.has(FLOWERS[0]):
		return
	for i in 30:
		var patch := _open_spot(rng, 10.0)
		for j in 6:
			var spot := patch + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5))
			var flower: Node3D
			if _fantasy and j % 3 == 0:
				flower = _fantasy_model(ground, FANTASY_FLOWERS[(i + j) % FANTASY_FLOWERS.size()], spot, rng,
						rng.randf_range(0.6, 0.9))
			else:
				flower = Art.instance(FLOWERS[(i + j) % FLOWERS.size()])
				flower.position = spot
				flower.rotation.y = rng.randf() * TAU
				flower.scale = Vector3.ONE * 1.6 * rng.randf_range(0.8, 1.2)
				ground.add_child(flower)
			_no_shadow(flower)


## Open spots for acorns, the same for everyone: anywhere but the plots, the
## roads and the fountain, and not deep in the woods at the edge.
static func acorn_spots(count: int) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var out: Array[Vector3] = []
	while out.size() < count:
		var p := _open_spot(rng, 5.0)
		if absf(p.x) < 50.0 and absf(p.z) < 50.0:
			out.append(p)
	return out


## A random spot on the grass, away from the plots, the roads and the plaza.
static func _open_spot(rng: RandomNumberGenerator, plaza_gap: float) -> Vector3:
	while true:
		var p := Vector3(rng.randf_range(-66, 66), 0, rng.randf_range(-66, 66))
		# The plots are 22 m lots, four on each side of the plaza (see World.plot_center).
		var in_plots := absf(p.x) < 53.0 and absf(p.z) > 11.0 and absf(p.z) < 42.0
		var near_center := absf(p.x) < plaza_gap and absf(p.z) < plaza_gap
		var on_road := absf(p.x) < 54.0 and absf(absf(p.z) - 15.5) < 3.0 or absf(p.x) < 2.5 and absf(p.z) < 16.0 \
				or p.x < 0.0 and p.x > GLADE_PORTAL.x - 6.0 and absf(p.z) < 6.0
		if not (in_plots or near_center or on_road):
			return p
	return Vector3.ZERO


## A tree with a collider around its trunk. Starfall Glade borrows it when the
## licensed art is missing, so it always uses the free forest trees there.
static func tree(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator, fantasy := false) -> void:
	var node: Node3D
	if fantasy:
		# Mostly green, with one autumn tree in eight for color.
		var list := FANTASY_AUTUMN_TREES if rng.randf() < 0.125 else FANTASY_TREES
		node = _fantasy_model(parent, list[rng.randi() % list.size()], pos, rng, rng.randf_range(5.0, 7.5))
	else:
		var tree: Array = TREES[rng.randi() % TREES.size()]
		node = _place(parent, tree[0], pos, rng, tree[1] * rng.randf_range(0.85, 1.2))
	MeshUtil.collider(node, Vector3(0.5, 2.0, 0.5) / node.scale.x, Vector3(0, 1.0, 0) / node.scale.x)


## A Fantasy pack model scaled to stand `height` meters tall.
static func _fantasy_model(parent: Node3D, model: String, pos: Vector3, rng: RandomNumberGenerator, height: float) -> Node3D:
	var node := Art.instance(FANTASY + model)
	node.position = pos
	node.rotation.y = rng.randf() * TAU
	node.scale = Vector3.ONE * height / maxf(Art.bounds(node).size.y, 0.01)
	parent.add_child(node)
	return node


static func _model(model_name: String) -> Node3D:
	return (load(FOREST + model_name + "_Color1.gltf") as PackedScene).instantiate() as Node3D


static func _place(parent: Node3D, model_name: String, pos: Vector3, rng: RandomNumberGenerator, size: float) -> Node3D:
	var model := _model(model_name)
	model.position = pos
	model.rotation.y = rng.randf() * TAU
	model.scale = Vector3.ONE * size
	parent.add_child(model)
	return model


static func _no_shadow(node: Node3D) -> void:
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Hundreds of grass tufts, one MultiMesh per kind so browsers draw them cheaply.
static func _grass(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var spots: Array[Array] = []
	var weights := PackedFloat32Array()
	for kind: Array in GRASS:
		spots.append([])
		weights.append(kind[1])
	for i in GRASS_TUFTS:
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.5, 0.85))
		spots[rng.rand_weighted(weights)].append(Transform3D(basis, _open_spot(rng, 9.5)))
	for k in GRASS.size():
		var source := _model(GRASS[k][0])
		var mesh := (source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
		source.free()
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = spots[k].size()
		for j in spots[k].size():
			multi.set_instance_transform(j, spots[k][j])
		var node := MultiMeshInstance3D.new()
		node.multimesh = multi
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
