class_name Scenery
extends RefCounted
## The neighborhood's ground, roads, plaza and greenery. Trees, bushes, rocks
## and grass come from the free KayKit Forest Nature Pack in assets/kaykit_forest
## (CC0, always in the repo). Flowers come with the licensed art only.

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


static func art_paths() -> Array:
	return FLOWERS.duplicate()


static func build(ground: Node3D) -> void:
	MeshUtil.box(ground, Vector3(140, 1, 140), Color("4f9442"), Vector3(0, -0.5, 0))
	MeshUtil.collider(ground, Vector3(140, 1, 140), Vector3(0, -0.5, 0))
	# Roads in front of each row of plots, and one through the plaza.
	var road := Color("c2b08a")
	for z in [-15.5, 15.5]:
		MeshUtil.box(ground, Vector3(74, 0.02, 3.5), road, Vector3(0, 0.01, z))
	MeshUtil.box(ground, Vector3(3.5, 0.02, 31), road, Vector3(0, 0.01, 0))
	# Plaza with a fountain.
	MeshUtil.cylinder(ground, 9, 9, 0.04, Color("d6bf96"), Vector3(0, 0.02, 0))
	MeshUtil.cylinder(ground, 3.2, 3.4, 0.6, Color("b0a898"), Vector3(0, 0.3, 0))
	MeshUtil.cylinder(ground, 2.9, 2.9, 0.62, Color(0.35, 0.65, 0.95, 0.85), Vector3(0, 0.32, 0))
	MeshUtil.cylinder(ground, 0.35, 0.5, 1.8, Color("b0a898"), Vector3(0, 0.9, 0))
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

	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 # Same scenery for everyone.
	for i in 60:
		_tree(ground, _open_spot(rng, 14.0), rng)
	# A thick ring of woods hides the edge of the world.
	for i in 90:
		var along := rng.randf_range(-68, 68)
		var depth := rng.randf_range(57, 68) * (1 if rng.randf() < 0.5 else -1)
		_tree(ground, Vector3(along, 0, depth) if i % 2 == 0 else Vector3(depth, 0, along), rng)
	for i in 45:
		var node := _place(ground, BUSHES[i % BUSHES.size()], _open_spot(rng, 11.0), rng, rng.randf_range(0.8, 1.2))
		_no_shadow(node)
	for i in 20:
		var node := _place(ground, ROCKS[i % ROCKS.size()], _open_spot(rng, 11.0), rng, rng.randf_range(0.6, 0.9))
		var box := Art.bounds(node)
		MeshUtil.collider(node, box.size * Vector3(0.8, 1, 0.8), box.get_center())
	for i in 40:
		_no_shadow(_place(ground, PEBBLES[i % PEBBLES.size()], _open_spot(rng, 9.5), rng, rng.randf_range(0.5, 1.0)))
	_grass(ground, rng)
	# Flowers come last so copies without the licensed art still match above.
	if not Art.has(FLOWERS[0]):
		return
	for i in 30:
		var patch := _open_spot(rng, 10.0)
		for j in 6:
			var spot := patch + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5))
			var flower := Art.instance(FLOWERS[(i + j) % FLOWERS.size()])
			flower.position = spot
			flower.rotation.y = rng.randf() * TAU
			flower.scale = Vector3.ONE * 1.6 * rng.randf_range(0.8, 1.2)
			_no_shadow(flower)
			ground.add_child(flower)


## A random spot on the grass, away from the plots, the roads and the plaza.
static func _open_spot(rng: RandomNumberGenerator, plaza_gap: float) -> Vector3:
	while true:
		var p := Vector3(rng.randf_range(-66, 66), 0, rng.randf_range(-66, 66))
		var in_plots := absf(p.x) < 40.0 and absf(p.z) > 11.0 and absf(p.z) < 34.0
		var near_center := absf(p.x) < plaza_gap and absf(p.z) < plaza_gap
		var on_road := absf(p.x) < 40.0 and absf(absf(p.z) - 15.5) < 3.0 or absf(p.x) < 2.5 and absf(p.z) < 16.0
		if not (in_plots or near_center or on_road):
			return p
	return Vector3.ZERO


static func _tree(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var tree: Array = TREES[rng.randi() % TREES.size()]
	var node := _place(parent, tree[0], pos, rng, tree[1] * rng.randf_range(0.85, 1.2))
	MeshUtil.collider(node, Vector3(0.5, 2.0, 0.5) / node.scale.x, Vector3(0, 1.0, 0) / node.scale.x)


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
