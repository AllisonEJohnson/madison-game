class_name FurnitureCatalog
extends RefCounted
## Everything a player can place on their plot. Each item lives on one layer:
## a cell can hold one floor piece, one object, and one wall per edge.
## Walls sit on a cell edge chosen by rotation: 0 north, 1 west, 2 south, 3 east.

const FURNITURE := "Bright_Furniture/prefabs/assets/"
const PET_STUFF := "Animals/prefabs/assets/assets/domestic_assets/"

## Build-mode tabs, in order. Every item names one as its "category".
const CATEGORIES := [
	{"id": "build", "name": "Walls & Floors", "icon": "brick"},
	{"id": "living", "name": "Living Room", "icon": "couch_and_lamp"},
	{"id": "bedroom", "name": "Bedroom", "icon": "bed"},
	{"id": "kitchen", "name": "Kitchen", "icon": "cooking"},
	{"id": "bathroom", "name": "Bathroom", "icon": "bathtub"},
	{"id": "fun", "name": "Fun & Games", "icon": "video_game"},
	{"id": "decor", "name": "Plants & Lights", "icon": "potted_plant"},
	{"id": "pets", "name": "Pet Stuff", "icon": "paw_prints"},
]

## "size" is the footprint in cells (default 1x1): it grows toward +X and +Z
## from the clicked cell before rotation. "back" items stand against the
## cell's north wall. "styles" are licensed models (in "art_dir", default
## FURNITURE) picked in build mode; items without them, or every item when the
## art isn't installed, are built from shapes in "color", sized to "box".
const ITEMS := {
	"floor": {"name": "Wood Floor", "category": "build", "layer": "floor", "color": "c9a77c"},
	"tile": {"name": "Tile Floor", "category": "build", "layer": "floor", "color": "dfe6ea"},
	"path": {"name": "Stone Path", "category": "build", "layer": "floor", "color": "b8b2a7"},
	"wall": {"name": "Wall", "category": "build", "layer": "wall", "color": "f1e7d6"},
	"window": {"name": "Window", "category": "build", "layer": "wall", "color": "f1e7d6"},
	"door": {"name": "Doorway", "category": "build", "layer": "wall", "color": "f1e7d6"},
	"fence": {"name": "Fence", "category": "build", "layer": "wall", "color": "9a6b42"},
	"table": {"name": "Table", "category": "kitchen", "layer": "object", "color": "a8744a", "solid": true,
		"styles": ["kitchen_table/kitchen_table_007", "kitchen_table/kitchen_table_009",
			"kitchen_table/kitchen_table_005", "kitchen_table/kitchen_table_006",
			"kitchen_table/kitchen_table_012", "kitchen_table/kitchen_table_014"]},
	"chair": {"name": "Chair", "category": "kitchen", "layer": "object", "color": "a8744a",
		"styles": ["kitchen_chair/kitchen_chair_008", "kitchen_chair/kitchen_chair_010",
			"kitchen_chair/kitchen_chair_020", "kitchen_chair/kitchen_chair_007",
			"kitchen_chair/kitchen_chair_025", "kitchen_chair/kitchen_chair_012",
			"kitchen_chair/kitchen_chair_018", "kitchen_chair/kitchen_chair_006"]},
	"armchair": {"name": "Armchair", "category": "living", "layer": "object", "color": "7fb3d5",
		"box": Vector3(0.8, 0.8, 0.8),
		"styles": ["armchair/armchair_008", "armchair/armchair_002", "armchair/armchair_015",
			"armchair/armchair_003", "armchair/armchair_013", "armchair/armchair_016",
			"armchair/armchair_001", "armchair/armchair_010"]},
	"sofa": {"name": "Sofa", "category": "living", "layer": "object", "color": "e07a5f", "size": Vector2i(2, 1),
		"back": true, "solid": true,
		"styles": ["sofa/sofa_005", "sofa/sofa", "sofa/sofa_003", "sofa/sofa_004", "sofa/sofa_006",
			"sofa/sofa_011", "sofa/sofa_024"]},
	"bed": {"name": "Bed", "category": "bedroom", "layer": "object", "color": "6fa8dc", "size": Vector2i(1, 2),
		"back": true, "solid": true,
		"styles": ["bed/bed_003", "bed/bed_004", "bed/bed_002", "bed/bed_010", "bed/bed_011",
			"bed/bed_006", "bed/bed_005"]},
	"wardrobe": {"name": "Wardrobe", "category": "bedroom", "layer": "object", "color": "f2c94c", "back": true,
		"solid": true, "box": Vector3(0.8, 1.9, 0.45),
		"styles": ["closet/closet_013", "closet/closet_014", "closet/closet_015",
			"closet/closet_022", "closet/closet_026", "closet/closet_012"]},
	"bookshelf": {"name": "Bookshelf", "category": "living", "layer": "object", "color": "8d5b3a", "back": true,
		"solid": true,
		"styles": ["shelf/shelf_049", "shelf/shelf_045", "shelf/shelf_022", "shelf/shelf_026",
			"shelf/shelf_027", "shelf/shelf_040"]},
	"lamp": {"name": "Lamp", "category": "decor", "layer": "object", "color": "f6d365",
		"styles": ["lamp/lamp_003", "lamp/lamp_009", "lamp/lamp_013", "lamp/lamp_015", "lamp/lamp_022"]},
	"plant": {"name": "Plant", "category": "decor", "layer": "object", "color": "4caf50",
		"styles": ["flower/flower_002", "flower/flower_005", "flower/flower_009",
			"flower/flower_017", "flower/flower_020", "flower/flower_011", "flower/flower_023"]},
	"rug": {"name": "Rug", "category": "living", "layer": "object", "color": "b56fd1"},
	"fridge": {"name": "Fridge", "category": "kitchen", "layer": "object", "color": "e8eef2", "back": true,
		"solid": true, "box": Vector3(0.7, 1.8, 0.65),
		"styles": ["kitchen_item/kitchen_item_018", "kitchen_item/kitchen_item_019",
			"kitchen_item/kitchen_item_020", "kitchen_item/kitchen_item_023"]},
	"stove": {"name": "Stove", "category": "kitchen", "layer": "object", "color": "e8eef2", "back": true, "solid": true,
		"box": Vector3(0.7, 0.85, 0.65),
		"styles": ["kitchen_item/kitchen_item_031", "kitchen_item/kitchen_item_030",
			"kitchen_item/kitchen_item_032"]},
	"bathtub": {"name": "Bathtub", "category": "bathroom", "layer": "object", "color": "f4f8fb", "size": Vector2i(2, 1),
		"back": true, "solid": true, "box": Vector3(1.8, 0.6, 0.8),
		"styles": ["bathroom_item/bathroom_item_003", "bathroom_item/bathroom_item_020",
			"bathroom_item/bathroom_item_025"]},
	"toilet": {"name": "Toilet", "category": "bathroom", "layer": "object", "color": "f4f8fb", "back": true,
		"box": Vector3(0.4, 0.7, 0.6),
		"styles": ["bathroom_item/bathroom_item_018", "bathroom_item/bathroom_item_008"]},
	"piano": {"name": "Piano", "category": "fun", "layer": "object", "color": "3a3a4a", "back": true, "solid": true,
		"box": Vector3(0.9, 1.0, 0.4),
		"styles": ["musical_instrument/musical_instrument_017",
			"musical_instrument/musical_instrument_002"]},
	"arcade": {"name": "Arcade", "category": "fun", "layer": "object", "color": "5b6cf0", "back": true, "solid": true,
		"box": Vector3(0.7, 1.8, 0.7),
		"styles": ["entertainment/entertainment_004", "entertainment/entertainment_005",
			"entertainment/entertainment_006", "entertainment/entertainment_017",
			"entertainment/entertainment_018"]},
	"toy_box": {"name": "Toys", "category": "fun", "layer": "object", "color": "4fb3e8",
		"styles": ["toy/toy_031", "toy/toy_016", "toy/toy_035", "toy/toy_033", "toy/toy",
			"toy/toy_002", "toy/toy_009", "toy/toy_024", "toy/toy_020", "toy/toy_037"]},
	"pet_bed": {"name": "Pet Bed", "category": "pets", "layer": "object", "color": "f28fad",
		"art_dir": PET_STUFF, "styles": ["pet_bed_01", "pet_bed_02", "pet_shelter_02", "pet_shelter_01"]},
}

const FLOOR_H := 0.06
## Wall pieces are 0.12 thick on the cell edge, so "back" items stop here.
const WALL_DEPTH := 0.12
## How far a model may hang over its footprint before it is shrunk to fit.
const OVERHANG := 0.1


static func ids() -> Array:
	return ITEMS.keys()


## Every look a player can pick in build mode, one per style (or one for an
## item without styles), keyed "id:style". Shapes have no styles to show
## when the art isn't installed.
static func entries() -> Array:
	var out := []
	for id in ITEMS:
		var item: Dictionary = ITEMS[id]
		var looks := style_count(id) if has_art(id) else 1
		for s in looks:
			out.append({"key": "%s:%d" % [id, s], "id": id, "style": s, "name": item["name"],
				"category": item.get("category", CATEGORIES[0]["id"]), "group": item["name"],
				"tags": id.replace("_", " ")})
	return out


## Splits an entry key back into [id, style], or [] when it isn't a real item.
static func parse_key(key: String) -> Array:
	var parts := key.split(":")
	if parts.size() != 2 or not ITEMS.has(parts[0]) or not parts[1].is_valid_int():
		return []
	return [parts[0], clampi(int(parts[1]), 0, maxi(style_count(parts[0]) - 1, 0))]


static func layer(id: String) -> String:
	return ITEMS[id]["layer"] if ITEMS.has(id) else ""


static func footprint(id: String) -> Vector2i:
	return ITEMS.get(id, {}).get("size", Vector2i.ONE)


static func style_count(id: String) -> int:
	return ITEMS.get(id, {}).get("styles", []).size()


static func style_path(id: String, style: int) -> String:
	var item: Dictionary = ITEMS.get(id, {})
	var styles: Array = item.get("styles", [])
	if styles.is_empty():
		return ""
	return item.get("art_dir", FURNITURE) + styles[clampi(style, 0, styles.size() - 1)]


## True when the item shows a licensed model, so its paint color doesn't apply.
static func has_art(id: String) -> bool:
	return style_count(id) > 0 and Art.has(style_path(id, 0))


static func art_paths() -> Array:
	var out := []
	for id in ITEMS:
		for i in style_count(id):
			out.append(style_path(id, i))
	return out


## The cells an item covers when its corner is in cell (x, z) and it is turned
## `r` quarter turns, matching `rotation_degrees.y = 90 * r`.
static func cells(id: String, x: int, z: int, r: int) -> Array[Vector2i]:
	var size := footprint(id)
	var out: Array[Vector2i] = []
	for dx in size.x:
		for dz in size.y:
			var turned := Vector2i(dx, dz)
			match posmod(r, 4):
				1: turned = Vector2i(dz, -dx)
				2: turned = Vector2i(-dx, -dz)
				3: turned = Vector2i(-dz, dx)
			out.append(Vector2i(x, z) + turned)
	return out


## From the corner cell's center to the middle of the footprint.
static func center_offset(id: String, r: int) -> Vector3:
	var size := footprint(id)
	return Vector3((size.x - 1) / 2.0, 0, (size.y - 1) / 2.0).rotated(Vector3.UP, PI / 2.0 * r)


## Builds one item centered on its footprint, facing +Z. `solid` adds
## colliders and lights (off for ghosts).
static func build(id: String, color_hex: String, solid := true, style := 0) -> Node3D:
	var art := _build_art(id, style, solid)
	if art:
		return art
	var root := Node3D.new()
	var c := MeshUtil.hex(color_hex, MeshUtil.hex(ITEMS.get(id, {}).get("color", "ffffff")))
	var wood := Color("8d5b3a")
	var y := FLOOR_H
	match id:
		"floor", "tile", "path":
			MeshUtil.box(root, Vector3(1.0, FLOOR_H, 1.0), c, Vector3(0, FLOOR_H / 2.0, 0))
			if id == "tile":
				MeshUtil.box(root, Vector3(0.96, 0.005, 0.96), c.lightened(0.15), Vector3(0, FLOOR_H + 0.002, 0))
		"wall":
			_wall_piece(root, c, Vector3(1.0, 2.6, 0.12), Vector3(0, 1.3, 0), solid)
		"window":
			_wall_piece(root, c, Vector3(1.0, 0.9, 0.12), Vector3(0, 0.45, 0), solid)
			_wall_piece(root, c, Vector3(1.0, 0.6, 0.12), Vector3(0, 2.3, 0), solid)
			_wall_piece(root, c, Vector3(0.15, 1.1, 0.12), Vector3(-0.425, 1.45, 0), solid)
			_wall_piece(root, c, Vector3(0.15, 1.1, 0.12), Vector3(0.425, 1.45, 0), solid)
			MeshUtil.box(root, Vector3(0.7, 1.1, 0.03), Color(0.7, 0.88, 1.0, 0.35), Vector3(0, 1.45, -0.45))
			if solid:
				MeshUtil.collider(root, Vector3(0.7, 1.1, 0.12), Vector3(0, 1.45, -0.44))
		"door":
			_wall_piece(root, c, Vector3(0.2, 2.6, 0.12), Vector3(-0.4, 1.3, 0), solid)
			_wall_piece(root, c, Vector3(0.2, 2.6, 0.12), Vector3(0.4, 1.3, 0), solid)
			_wall_piece(root, c, Vector3(0.6, 0.5, 0.12), Vector3(0, 2.35, 0), solid)
		"fence":
			for x in [-0.45, 0.45]:
				_wall_piece(root, c, Vector3(0.1, 0.8, 0.1), Vector3(x, 0.4, 0), false)
			for h in [0.3, 0.6]:
				_wall_piece(root, c, Vector3(1.0, 0.08, 0.05), Vector3(0, h, 0), false)
			if solid:
				MeshUtil.collider(root, Vector3(1.0, 0.8, 0.1), Vector3(0, 0.4, -0.45))
		"table":
			MeshUtil.box(root, Vector3(0.9, 0.06, 0.9), c, Vector3(0, y + 0.72, 0))
			for p in [Vector2(-0.38, -0.38), Vector2(0.38, -0.38), Vector2(-0.38, 0.38), Vector2(0.38, 0.38)]:
				MeshUtil.box(root, Vector3(0.07, 0.72, 0.07), c.darkened(0.15), Vector3(p.x, y + 0.36, p.y))
			if solid:
				MeshUtil.collider(root, Vector3(0.9, 0.78, 0.9), Vector3(0, y + 0.39, 0))
		"chair":
			MeshUtil.box(root, Vector3(0.45, 0.06, 0.45), c, Vector3(0, y + 0.45, 0))
			MeshUtil.box(root, Vector3(0.45, 0.5, 0.06), c, Vector3(0, y + 0.72, -0.2))
			for p in [Vector2(-0.19, -0.19), Vector2(0.19, -0.19), Vector2(-0.19, 0.19), Vector2(0.19, 0.19)]:
				MeshUtil.box(root, Vector3(0.05, 0.45, 0.05), c.darkened(0.15), Vector3(p.x, y + 0.225, p.y))
		"bed":
			# Two cells long: the headboard is on the north edge.
			MeshUtil.box(root, Vector3(0.9, 0.3, 1.8), wood, Vector3(0, y + 0.15, 0.05))
			MeshUtil.box(root, Vector3(0.86, 0.14, 1.6), c, Vector3(0, y + 0.37, 0.12))
			MeshUtil.box(root, Vector3(0.6, 0.12, 0.25), Color.WHITE, Vector3(0, y + 0.38, -0.7))
			MeshUtil.box(root, Vector3(0.9, 0.7, 0.08), wood, Vector3(0, y + 0.35, -0.84))
			if solid:
				MeshUtil.collider(root, Vector3(0.9, 0.45, 1.8), Vector3(0, y + 0.22, 0.05))
		"sofa":
			# Two cells wide.
			MeshUtil.box(root, Vector3(1.9, 0.35, 0.7), c, Vector3(0, y + 0.2, 0.05))
			MeshUtil.box(root, Vector3(1.9, 0.45, 0.2), c.darkened(0.1), Vector3(0, y + 0.55, -0.27))
			for x in [-0.89, 0.89]:
				MeshUtil.box(root, Vector3(0.12, 0.25, 0.7), c.darkened(0.1), Vector3(x, y + 0.48, 0.05))
			if solid:
				MeshUtil.collider(root, Vector3(1.9, 0.6, 0.8), Vector3(0, y + 0.3, 0))
		"lamp":
			MeshUtil.cylinder(root, 0.15, 0.15, 0.04, wood, Vector3(0, y + 0.02, 0))
			MeshUtil.cylinder(root, 0.025, 0.025, 1.3, wood, Vector3(0, y + 0.65, 0))
			MeshUtil.cylinder(root, 0.14, 0.22, 0.28, c, Vector3(0, y + 1.35, 0))
			if solid:
				_lamp_light(root, c, y + 1.25)
		"plant":
			MeshUtil.cylinder(root, 0.18, 0.13, 0.3, Color("c46a3f"), Vector3(0, y + 0.15, 0))
			for i in 5:
				var a := TAU * float(i) / 5.0
				MeshUtil.sphere(root, 0.15, c, Vector3(cos(a) * 0.1, y + 0.5 + (i % 2) * 0.12, sin(a) * 0.1))
		"bookshelf":
			MeshUtil.box(root, Vector3(0.9, 1.8, 0.35), c, Vector3(0, y + 0.9, -0.3))
			var book_colors := [Color("e05555"), Color("55a0e0"), Color("e0c055"), Color("6fbf73")]
			for shelf in 3:
				for b in 6:
					MeshUtil.box(root, Vector3(0.1, 0.35, 0.05), book_colors[(b + shelf) % 4],
							Vector3(-0.33 + b * 0.13, y + 0.35 + shelf * 0.55, -0.1))
			if solid:
				MeshUtil.collider(root, Vector3(0.9, 1.8, 0.35), Vector3(0, y + 0.9, -0.3))
		"rug":
			MeshUtil.cylinder(root, 0.48, 0.48, 0.02, c, Vector3(0, y + 0.01, 0))
			MeshUtil.cylinder(root, 0.32, 0.32, 0.022, c.lightened(0.3), Vector3(0, y + 0.012, 0))
		"pet_bed":
			MeshUtil.torus(root, 0.18, 0.38, c, Vector3(0, y + 0.08, 0))
			MeshUtil.cylinder(root, 0.25, 0.25, 0.06, c.lightened(0.35), Vector3(0, y + 0.04, 0))
		"toy_box":
			MeshUtil.box(root, Vector3(0.7, 0.45, 0.5), c, Vector3(0, y + 0.225, 0))
			MeshUtil.box(root, Vector3(0.74, 0.06, 0.54), c.darkened(0.2), Vector3(0, y + 0.47, 0))
			MeshUtil.sphere(root, 0.1, Color("f2c94c"), Vector3(0.15, y + 0.58, 0))
			if solid:
				MeshUtil.collider(root, Vector3(0.7, 0.5, 0.5), Vector3(0, y + 0.25, 0))
		_:
			# Items added along with the licensed art get a plain stand-in.
			var size: Vector3 = ITEMS.get(id, {}).get("box", Vector3(0.8, 0.8, 0.8))
			var z := _back_z(id) + size.z / 2.0 if ITEMS.get(id, {}).get("back", false) else 0.0
			MeshUtil.box(root, size, c, Vector3(0, y + size.y / 2.0, z))
			if solid and ITEMS.get(id, {}).get("solid", false):
				MeshUtil.collider(root, size, Vector3(0, y + size.y / 2.0, z))
	return root


## A licensed model shrunk to fit its footprint if needed, standing on the
## floor, or null when the item has no styles or the art isn't installed.
static func _build_art(id: String, style: int, solid: bool) -> Node3D:
	var path := style_path(id, style)
	var model := Art.instance(path) if path != "" else null
	if not model:
		return null
	var item: Dictionary = ITEMS[id]
	var size := footprint(id)
	var back: bool = item.get("back", false)
	var box := Art.bounds(model)
	var room := Vector2(size.x + OVERHANG, size.y + OVERHANG - (WALL_DEPTH if back else 0.0))
	var s := minf(1.0, minf(room.x / box.size.x, room.y / box.size.z))
	model.scale = Vector3.ONE * s
	var z := _back_z(id) - box.position.z * s if back else -box.get_center().z * s
	model.position = Vector3(-box.get_center().x * s, FLOOR_H - box.position.y * s, z)
	var root := Node3D.new()
	root.add_child(model)
	if solid and item.get("solid", false):
		MeshUtil.collider(root, box.size * s, model.position + box.get_center() * s)
	if solid and id == "lamp":
		_lamp_light(root, Color.html(item["color"]), FLOOR_H + box.size.y * s * 0.8)
	return root


## Where the back of a "back" item goes: just in front of a north wall.
static func _back_z(id: String) -> float:
	return -footprint(id).y / 2.0 + WALL_DEPTH


static func _lamp_light(root: Node3D, c: Color, height: float) -> void:
	var light := OmniLight3D.new()
	light.position = Vector3(0, height, 0)
	light.light_color = c.lightened(0.5)
	light.omni_range = 4.0
	light.light_energy = 0.8
	root.add_child(light)


static func _wall_piece(root: Node3D, c: Color, size: Vector3, pos: Vector3, solid: bool) -> void:
	# Wall pieces hug the cell's north edge; rotation moves them to other edges.
	var p := pos + Vector3(0, 0, -0.44)
	MeshUtil.box(root, size, c, p)
	if solid:
		MeshUtil.collider(root, size, p)


static func starter_layout() -> Array:
	var layout := []
	for x in range(3, 9):
		for z in range(3, 9):
			layout.append({"id": "floor", "x": x, "z": z, "r": 0, "c": "c9a77c"})
	for i in range(3, 9):
		layout.append({"id": "wall", "x": i, "z": 3, "r": 0, "c": "f1e7d6"})
		layout.append({"id": "window" if i == 5 else "wall", "x": 3, "z": i, "r": 1, "c": "f1e7d6"})
		layout.append({"id": "window" if i == 6 else "wall", "x": 8, "z": i, "r": 3, "c": "f1e7d6"})
		var south := "door" if i == 5 else ("window" if i in [3, 8] else "wall")
		layout.append({"id": south, "x": i, "z": 8, "r": 2, "c": "f1e7d6"})
	for z in range(9, 12):
		layout.append({"id": "path", "x": 5, "z": z, "r": 0, "c": "b8b2a7"})
	# [id, x, z, rotation, style]: a bed corner, a sofa corner and a little table.
	for item in [["bed", 3, 3, 0, 0], ["lamp", 4, 3, 0, 0], ["wardrobe", 5, 3, 0, 0], ["sofa", 7, 3, 0, 0],
			["rug", 7, 4, 0, 0], ["armchair", 8, 5, 3, 3], ["table", 4, 6, 0, 1], ["chair", 4, 7, 2, 0],
			["chair", 5, 6, 3, 0], ["plant", 8, 7, 0, 0], ["pet_bed", 3, 7, 0, 0], ["toy_box", 3, 6, 0, 0]]:
		layout.append({"id": item[0], "x": item[1], "z": item[2], "r": item[3],
			"c": ITEMS[item[0]]["color"], "s": item[4]})
	return layout
