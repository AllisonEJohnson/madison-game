class_name Scenery
extends RefCounted
## The neighborhood's ground, roads, plaza and greenery. Trees use the licensed
## models when they are installed; bushes and flowers only come with them.

const NATURE := "Animals/prefabs/assets/assets/"
## Licensed scenery models and how much to shrink them, since they are big.
const TREES := [
	["domestic_assets/forest_tree_03", 0.7], ["domestic_assets/forest_tree_04", 0.7],
	["domestic_assets/forest_tree_05", 0.7], ["forest_assets/farm_tree_01", 0.8],
	["forest_assets/farm_tree_02", 0.8], ["forest_assets/farm_tree_03", 0.8],
	["forest_assets/pine_01", 0.55], ["forest_assets/pine_03", 0.55], ["forest_assets/pine_04", 0.65],
]
const BUSHES := ["forest_assets/forest_bush_01", "forest_assets/forest_bush_02",
	"forest_assets/forest_bush_04"]
const FLOWERS := ["domestic_assets/flower_01", "domestic_assets/flower_02", "domestic_assets/flower_03"]


static func art_paths() -> Array:
	var out := []
	for tree in TREES:
		out.append(NATURE + tree[0])
	for path in BUSHES + FLOWERS:
		out.append(NATURE + path)
	return out


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
	rng.seed = 1234 # Same trees for everyone.
	for i in 60:
		_tree(ground, _open_spot(rng, 14.0), rng)
	# Bushes and flowers only come with the licensed art; they have no colliders.
	if not Art.has(NATURE + BUSHES[0]):
		return
	for i in 45:
		_scenery(ground, NATURE + BUSHES[i % BUSHES.size()], _open_spot(rng, 11.0), rng, 0.6)
	for i in 30:
		var patch := _open_spot(rng, 10.0)
		for j in 6:
			var spot := patch + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5))
			_scenery(ground, NATURE + FLOWERS[(i + j) % FLOWERS.size()], spot, rng, 1.6)


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
	var t := Node3D.new()
	t.position = pos
	var s := rng.randf_range(0.8, 1.4)
	t.scale = Vector3(s, s, s)
	t.rotation.y = rng.randf() * TAU
	# Drawn either way, so copies with and without the art share tree spots.
	var kind: Array = TREES[rng.randi() % TREES.size()]
	var leaf := Color.from_hsv(rng.randf_range(0.25, 0.38), 0.6, rng.randf_range(0.45, 0.7))
	parent.add_child(t)
	MeshUtil.collider(t, Vector3(0.5, 2.0, 0.5), Vector3(0, 1.0, 0))
	var model := Art.instance(NATURE + kind[0])
	if model:
		model.scale = Vector3.ONE * kind[1]
		t.add_child(model)
		return
	MeshUtil.cylinder(t, 0.18, 0.25, 1.6, Color("7a5230"), Vector3(0, 0.8, 0))
	MeshUtil.sphere(t, 1.1, leaf, Vector3(0, 2.3, 0))
	MeshUtil.sphere(t, 0.8, leaf.lightened(0.1), Vector3(0.4, 2.9, 0.2))


static func _scenery(parent: Node3D, path: String, pos: Vector3, rng: RandomNumberGenerator, size: float) -> void:
	var model := Art.instance(path)
	model.position = pos
	model.rotation.y = rng.randf() * TAU
	model.scale = Vector3.ONE * size * rng.randf_range(0.8, 1.2)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(model)
