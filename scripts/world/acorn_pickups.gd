class_name AcornPickups
extends Node3D
## Acorns to find around a land, the simplest way to earn. A few float at
## random spots at a time; walk into one to pick it up, and another grows
## somewhere else a little later. Now and then a golden one is worth more.
##
## Each player has their own acorns: they only exist on this device, like the
## wallet they fill. Once wallets move to a game server, the server should
## place the acorns and hand out what they're worth.

signal collected(amount: int, golden: bool, where: Vector3)

const ACTIVE := 10
const VALUE := 5
const GOLDEN_VALUE := 25
const GOLDEN_CHANCE := 0.1
## Seconds before a picked acorn grows back somewhere else.
const REGROW := Vector2(15.0, 35.0)
## How close you have to walk, in meters.
const REACH := 1.1
const HOVER := 0.75
const BROWN := Color("c98a4b")
const CAP := Color("7a5230")
const GOLD := Color("ffcf3a")
const GOLD_CAP := Color("d9961c")

## The local player, set by the world. Only they can pick acorns up.
var player: Node3D
## How often a new acorn is a golden one (the Sky Garden has more).
var golden_chance := GOLDEN_CHANCE

var _spots: Array[Vector3] = []
var _free: Array[int] = [] # spots without an acorn
var _acorns: Array[Dictionary] = [] # {node, spot, golden, phase}
var _regrow: Array[float] = []
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _ready_frames := 2
var _pops: Array[Dictionary] = [] # {node, age}


## `candidates` are spots on open ground in this node's space; any that turn
## out to be inside a tree, rock or building are dropped once physics is ready.
func setup(candidates: Array[Vector3], seed_value: int) -> AcornPickups:
	_spots = candidates
	_rng.seed = seed_value
	return self


func _physics_process(_delta: float) -> void:
	# Colliders join the physics world over the first frames; then the spots
	# are checked once and the first acorns appear.
	if _ready_frames <= 0:
		return
	_ready_frames -= 1
	if _ready_frames > 0:
		return
	_spots = clear_spots(self, _spots, 0.7)
	for i in _spots.size():
		_free.append(i)
	for i in mini(ACTIVE, _spots.size()):
		_grow()


func _process(delta: float) -> void:
	_time += delta
	for i in range(_regrow.size() - 1, -1, -1):
		_regrow[i] -= delta
		if _regrow[i] <= 0.0:
			_regrow.remove_at(i)
			_grow()
	var here := player and is_instance_valid(player) and player.is_inside_tree()
	var reach_from: Vector3 = player.global_position if here else Vector3.INF
	for i in range(_acorns.size() - 1, -1, -1):
		var a := _acorns[i]
		var node: Node3D = a["node"]
		node.position.y = a["spot"].y + HOVER + sin(_time * 2.2 + a["phase"]) * 0.12
		node.rotation.y += delta * 1.6
		var sparkle := node.get_node("Sparkle") as Sprite3D
		sparkle.modulate.a = 0.7 + 0.3 * sin(_time * 4.0 + a["phase"])
		var flat := Vector2(reach_from.x - node.global_position.x, reach_from.z - node.global_position.z)
		if flat.length() < REACH and absf(reach_from.y - a["spot"].y - global_position.y) < 2.0:
			_pick(i)
	for i in range(_pops.size() - 1, -1, -1):
		var pop := _pops[i]
		pop["age"] += delta
		var label: Label3D = pop["node"]
		label.position.y += delta * 1.4
		label.modulate.a = clampf(1.6 - pop["age"], 0.0, 1.0)
		label.outline_modulate.a = label.modulate.a
		if pop["age"] > 1.6:
			label.queue_free()
			_pops.remove_at(i)


func active_count() -> int:
	return _acorns.size()


## Where the acorns are now, in world space (for tests and screenshots).
func positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for a in _acorns:
		out.append((a["node"] as Node3D).global_position)
	return out


func _grow() -> void:
	if _free.is_empty():
		return
	var slot: int = _free.pop_at(_rng.randi() % _free.size())
	var golden := _rng.randf() < golden_chance
	var node := build_acorn(golden)
	node.position = _spots[slot] + Vector3(0, HOVER, 0)
	add_child(node)
	_acorns.append({"node": node, "spot": _spots[slot], "slot": slot, "golden": golden,
		"phase": _rng.randf() * TAU})


func _pick(i: int) -> void:
	var a: Dictionary = _acorns.pop_at(i)
	var node: Node3D = a["node"]
	var amount := GOLDEN_VALUE if a["golden"] else VALUE
	_popup("+%d" % amount, node.position, a["golden"])
	node.queue_free()
	_free.append(a["slot"])
	_regrow.append(_rng.randf_range(REGROW.x, REGROW.y))
	collected.emit(amount, a["golden"], node.global_position)


## A "+5" that floats up from where the acorn was.
func _popup(text: String, pos: Vector3, golden: bool) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = UiTheme.font(800, true)
	label.font_size = 64
	label.pixel_size = 0.006
	label.outline_size = 16
	label.modulate = GOLD if golden else Color("fff3d6")
	label.outline_modulate = Color(0.3, 0.18, 0.08)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = pos + Vector3(0, 0.4, 0)
	add_child(label)
	_pops.append({"node": label, "age": 0.0})


## An acorn made of shapes, about two-thirds of a meter tall, with a twinkle
## beside it.
static func build_acorn(golden := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Acorn"
	root.scale = Vector3.ONE * 1.35
	var nut := MeshUtil.sphere(root, 0.2, GOLD if golden else BROWN, Vector3(0, -0.04, 0), Vector3(1, 1.25, 1))
	var cap := MeshUtil.sphere(root, 0.235, GOLD_CAP if golden else CAP, Vector3(0, 0.14, 0), Vector3(1, 0.55, 1))
	MeshUtil.cylinder(root, 0.025, 0.035, 0.14, GOLD_CAP if golden else CAP, Vector3(0, 0.3, 0), Vector3(0, 0, 12))
	# A soft glow so acorns stand out against the grass.
	for mesh: MeshInstance3D in [nut, cap]:
		var mat := mesh.mesh.material as StandardMaterial3D
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 0.45 if golden else 0.18
		mat.roughness = 0.45
	var sparkle := Sprite3D.new()
	sparkle.name = "Sparkle"
	sparkle.texture = UiTheme.icon("sparkles")
	sparkle.pixel_size = 0.0035
	sparkle.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sparkle.shaded = false
	sparkle.position = Vector3(0.24, 0.4, 0)
	sparkle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sparkle)
	return root


## The spots (in `node`'s space) with nothing solid within `radius` of a point
## a meter above them, so nothing is hidden inside a tree, rock or wall. Call it
## once physics has had a frame to take in the land's colliders.
static func clear_spots(node: Node3D, spots: Array[Vector3], radius: float) -> Array[Vector3]:
	var space := node.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collide_with_areas = false
	var out: Array[Vector3] = []
	for spot in spots:
		query.transform = Transform3D(Basis.IDENTITY, node.to_global(spot + Vector3(0, 1.0, 0)))
		if space.intersect_shape(query, 1).is_empty():
			out.append(spot)
	return out
