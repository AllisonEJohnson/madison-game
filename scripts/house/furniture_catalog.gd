class_name FurnitureCatalog
extends RefCounted
## Everything a player can place on their plot. Each item lives on one layer:
## a cell can hold one floor piece, one object, and one wall per edge.
## Walls sit on a cell edge chosen by rotation: 0 north, 1 west, 2 south, 3 east.

const ITEMS := {
	"floor": {"name": "Wood Floor", "layer": "floor", "color": "c9a77c"},
	"tile": {"name": "Tile Floor", "layer": "floor", "color": "dfe6ea"},
	"path": {"name": "Stone Path", "layer": "floor", "color": "b8b2a7"},
	"wall": {"name": "Wall", "layer": "wall", "color": "f1e7d6"},
	"window": {"name": "Window", "layer": "wall", "color": "f1e7d6"},
	"door": {"name": "Doorway", "layer": "wall", "color": "f1e7d6"},
	"fence": {"name": "Fence", "layer": "wall", "color": "9a6b42"},
	"table": {"name": "Table", "layer": "object", "color": "a8744a"},
	"chair": {"name": "Chair", "layer": "object", "color": "a8744a"},
	"bed": {"name": "Bed", "layer": "object", "color": "6fa8dc"},
	"sofa": {"name": "Sofa", "layer": "object", "color": "e07a5f"},
	"lamp": {"name": "Lamp", "layer": "object", "color": "f6d365"},
	"plant": {"name": "Plant", "layer": "object", "color": "4caf50"},
	"bookshelf": {"name": "Bookshelf", "layer": "object", "color": "8d5b3a"},
	"rug": {"name": "Rug", "layer": "object", "color": "b56fd1"},
	"pet_bed": {"name": "Pet Bed", "layer": "object", "color": "f28fad"},
	"toy_box": {"name": "Toy Box", "layer": "object", "color": "4fb3e8"},
}

const FLOOR_H := 0.06


static func ids() -> Array:
	return ITEMS.keys()


static func layer(id: String) -> String:
	return ITEMS[id]["layer"] if ITEMS.has(id) else ""


## Builds one item centered on its cell. `solid` adds colliders (off for ghosts).
static func build(id: String, color_hex: String, solid := true) -> Node3D:
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
			MeshUtil.box(root, Vector3(0.9, 0.3, 0.95), wood, Vector3(0, y + 0.15, 0))
			MeshUtil.box(root, Vector3(0.86, 0.14, 0.75), c, Vector3(0, y + 0.37, 0.08))
			MeshUtil.box(root, Vector3(0.6, 0.12, 0.2), Color.WHITE, Vector3(0, y + 0.38, -0.36))
			MeshUtil.box(root, Vector3(0.9, 0.7, 0.08), wood, Vector3(0, y + 0.35, -0.47))
			if solid:
				MeshUtil.collider(root, Vector3(0.9, 0.45, 0.95), Vector3(0, y + 0.22, 0))
		"sofa":
			MeshUtil.box(root, Vector3(0.95, 0.35, 0.7), c, Vector3(0, y + 0.2, 0.05))
			MeshUtil.box(root, Vector3(0.95, 0.45, 0.2), c.darkened(0.1), Vector3(0, y + 0.55, -0.3))
			for x in [-0.42, 0.42]:
				MeshUtil.box(root, Vector3(0.12, 0.25, 0.7), c.darkened(0.1), Vector3(x, y + 0.48, 0.05))
			if solid:
				MeshUtil.collider(root, Vector3(0.95, 0.6, 0.8), Vector3(0, y + 0.3, 0))
		"lamp":
			MeshUtil.cylinder(root, 0.15, 0.15, 0.04, wood, Vector3(0, y + 0.02, 0))
			MeshUtil.cylinder(root, 0.025, 0.025, 1.3, wood, Vector3(0, y + 0.65, 0))
			MeshUtil.cylinder(root, 0.14, 0.22, 0.28, c, Vector3(0, y + 1.35, 0))
			if solid:
				var light := OmniLight3D.new()
				light.position = Vector3(0, y + 1.25, 0)
				light.light_color = c.lightened(0.5)
				light.omni_range = 4.0
				light.light_energy = 0.8
				root.add_child(light)
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
	return root


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
	layout.append({"id": "bed", "x": 4, "z": 4, "r": 0, "c": "6fa8dc"})
	layout.append({"id": "lamp", "x": 3, "z": 4, "r": 0, "c": "f6d365"})
	layout.append({"id": "rug", "x": 6, "z": 6, "r": 0, "c": "b56fd1"})
	layout.append({"id": "table", "x": 7, "z": 4, "r": 0, "c": "a8744a"})
	layout.append({"id": "chair", "x": 7, "z": 5, "r": 2, "c": "a8744a"})
	layout.append({"id": "plant", "x": 8, "z": 7, "r": 0, "c": "4caf50"})
	layout.append({"id": "pet_bed", "x": 3, "z": 7, "r": 0, "c": "f28fad"})
	return layout
