class_name HomeShell
extends RefCounted
## Draws a home from its plan (see HomeCatalog.plan), two ways: the inside
## (`build`: floors, walls with windows and doorways, no roof, for the space you
## walk into) and the outside (`exterior`: closed walls, roofs, front doors and
## no furniture, for town). Both have the deck railings, the front walk and the
## decor around the home. Walls stand on the line between two cells, and each
## straight run of plain wall is one piece, so even a big home costs few draw
## calls. Like the rest of the house code it must not use the autoloads (see
## HomeCatalog).

const WALL := 0.12
## The colored cap along the top of every wall: height and depth.
const CAP := Vector2(0.1, 0.18)
const RAIL_HEIGHT := 0.8
const GLASS := Color(0.7, 0.88, 1.0, 0.35)
## Windows seen from outside, where the empty inside shouldn't show through.
const GLASS_OUTSIDE := Color("a9d4ee")
const DOOR := Color("9a6232")
const KNOB := Color("f2c94c")
const HIGHLIGHT := Color("ffd166")
const HALF := HomeCatalog.PLOT / 2.0


## The inside of the home with these add-ons built: rooms without roofs, open
## doorways between them, and its entrances shut (walking into one goes back
## out). `solid` adds colliders and lights (off for pictures); the floor of room
## `highlight` is drawn in a bright color.
static func build(type: String, addon_ids: Array, solid := true, highlight := "") -> Node3D:
	var home := HomeCatalog.info(type)
	var root := Node3D.new()
	root.name = "Shell"
	var p := HomeCatalog.plan(type, addon_ids)
	var wall := MeshUtil.hex(home.get("wall"))
	var trim := MeshUtil.hex(home.get("trim"))
	var height := float(home.get("height", 2.6))
	for f in p["floors"]:
		var rect: Array = f["rect"]
		var color := HIGHLIGHT if f["id"] == highlight else MeshUtil.hex(f["color"])
		_floor(root, rect, color, f["deck"])
		if f["tent"]:
			_tent_top(root, rect, wall.darkened(0.06), trim, height)
	_walk(root, home, p["walk"])
	_edges(root, type, p["edges"], solid, false)
	for d in p["decor"]:
		root.add_child(decor(d, solid))
	return root


## The home as town sees it: closed walls, a roof over every room (canvas for
## tents), shut doors and windows, empty decks. Nothing inside is drawn.
static func exterior(type: String, addon_ids: Array, solid := true) -> Node3D:
	var home := HomeCatalog.info(type)
	var root := Node3D.new()
	root.name = "Outside"
	var p := HomeCatalog.plan(type, addon_ids)
	var wall := MeshUtil.hex(home.get("wall"))
	var trim := MeshUtil.hex(home.get("trim"))
	var roof := MeshUtil.hex(home.get("roof", home.get("trim")))
	var height := float(home.get("height", 2.6))
	for f in p["floors"]:
		var rect: Array = f["rect"]
		if f["deck"]:
			_floor(root, rect, MeshUtil.hex(f["color"]), true)
		elif f["tent"]:
			# A tent's canvas roof is the color of its trim, so it reads as a tent.
			_roof(root, rect, wall.darkened(0.06), trim.lightened(0.3), height, 1.4, false)
			_flags(root, rect, trim, height, minf(1.4, (float(mini(rect[2], rect[3])) + WALL) * 0.35))
		else:
			_roof(root, rect, wall, roof, height, 1.5, home.get("roof_spots", false))
	_walk(root, home, p["walk"])
	_edges(root, type, p["edges"].filter(func(e): return e["outside"]), solid, true)
	for d in p["decor"]:
		root.add_child(decor(d, solid))
	return root


static func _floor(root: Node3D, rect: Array, color: Color, deck: bool) -> void:
	var floor_h := FurnitureCatalog.FLOOR_H
	MeshUtil.box(root, Vector3(rect[2], floor_h, rect[3]), color,
			Vector3(rect[0] + rect[2] / 2.0 - HALF, floor_h / 2.0, rect[1] + rect[3] / 2.0 - HALF))
	if deck:
		_planks(root, rect, color.darkened(0.12))


static func _walk(root: Node3D, home: Dictionary, walk: Array) -> void:
	for cell in walk:
		MeshUtil.box(root, Vector3(0.84, 0.04, 0.84), MeshUtil.hex(home.get("path")),
				Vector3(cell[0] + 0.5 - HALF, 0.02, cell[1] + 0.5 - HALF))


## Walls, windows, doors, railings and gates along the plan's edges. Plain walls
## on one grid line are merged into runs. From `outside`, windows are opaque and
## every door is shut; inside, only the entrances are.
static func _edges(root: Node3D, type: String, edges: Array, solid: bool, outside: bool) -> void:
	var home := HomeCatalog.info(type)
	var wall := MeshUtil.hex(home.get("wall"))
	var trim := MeshUtil.hex(home.get("trim"))
	var wood := MeshUtil.hex(home.get("deck")).darkened(0.3)
	var height := float(home.get("height", 2.6))
	var runs := {} # "h:<line>" or "v:<line>" -> [positions] of plain walls
	for e in edges:
		var parts: PackedStringArray = e["key"].split(":")
		if e["kind"] == "wall":
			var line := "%s:%s" % [parts[0], parts[1] if parts[0] == "v" else parts[2]]
			var list: Array = runs.get(line, [])
			list.append(int(parts[2]) if parts[0] == "v" else int(parts[1]))
			runs[line] = list
			continue
		var piece := Node3D.new()
		if parts[0] == "h":
			piece.position = Vector3(int(parts[1]) + 0.5 - HALF, 0, int(parts[2]) - HALF)
		else:
			piece.position = Vector3(int(parts[1]) - HALF, 0, int(parts[2]) + 0.5 - HALF)
			piece.rotation_degrees.y = 90
		root.add_child(piece)
		match e["kind"]:
			"window":
				_window(piece, wall, trim, height, solid, outside)
			"door":
				if outside or e["entrance"]:
					var tent: bool = HomeCatalog.room(type, e.get("room", "")).get("tent", false)
					_door(piece, wall, trim, height, solid, wall.darkened(0.2) if tent else DOOR)
				else:
					_doorway(piece, wall, trim, height, solid)
			"rail":
				_rail(piece, wood, solid)
			"gate":
				_gate(piece, wood, solid)
	for line in runs:
		var list: Array = runs[line]
		list.sort()
		var start: int = list[0]
		for i in list.size():
			if i == list.size() - 1 or list[i + 1] != list[i] + 1:
				_wall_run(root, line, start, list[i], wall, trim, height, solid)
				if i < list.size() - 1:
					start = list[i + 1]


## Shows or hides the decor taller than the walls (big trees and mushrooms),
## so they don't block the view while decorating.
static func show_tall_decor(shell: Node3D, on: bool) -> void:
	for child in shell.get_children():
		if child.has_meta("tall"):
			child.visible = on


## Outlines of add-ons not built yet, each with a floating label (id -> text),
## so a player decorating sees where their home can grow.
static func plans(type: String, addon_ids: Array, labels: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Plans"
	var trim := MeshUtil.hex(HomeCatalog.info(type).get("trim"))
	for r in HomeCatalog.addons(type):
		if r["id"] in addon_ids:
			continue
		var rect: Array = r["rect"]
		var center := Vector3(rect[0] + rect[2] / 2.0 - HALF, 0, rect[1] + rect[3] / 2.0 - HALF)
		var slab := MeshUtil.box(root, Vector3(rect[2] - 0.1, 0.03, rect[3] - 0.1), Color(trim, 0.28),
				center + Vector3(0, 0.03, 0))
		slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# A dashed border: short bars along each side.
		for side in 4:
			var along := float(rect[2] if side < 2 else rect[3])
			var steps := int(along * 2)
			for i in steps:
				if i % 2 == 1:
					continue
				var t := -along / 2.0 + (i + 0.5) * along / steps
				var pos := Vector3(t, 0.06, (rect[3] / 2.0 - 0.05) * (1 if side == 0 else -1)) if side < 2 \
						else Vector3((rect[2] / 2.0 - 0.05) * (1 if side == 2 else -1), 0.06, t)
				var size := Vector3(along / steps * 0.9, 0.05, 0.1) if side < 2 else Vector3(0.1, 0.05, along / steps * 0.9)
				var dash := MeshUtil.box(root, size, Color(trim, 0.9), center + pos)
				dash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var label := Label3D.new()
		label.text = labels.get(r["id"], r["name"])
		label.font = UiTheme.font(700, true)
		label.font_size = 56
		label.pixel_size = 0.008
		label.outline_size = 16
		label.outline_modulate = Color(0.16, 0.1, 0.3)
		label.modulate = Color("fff3b0")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position = center + Vector3(0, 1.3, 0)
		root.add_child(label)
	return root


## A home for a picture: its rooms on a patch of lawn, and the furniture in it.
static func preview(type: String, addon_ids: Array, items: Array, highlight := "") -> Node3D:
	var root := Node3D.new()
	# The lawn reaches one cell past the rooms, so the picture is mostly home.
	var area := Rect2i()
	for r in HomeCatalog.built_rooms(type, addon_ids):
		var rect: Array = r["rect"]
		var box := Rect2i(rect[0], rect[1], rect[2], rect[3])
		area = box if area.size == Vector2i.ZERO else area.merge(box)
	area = area.grow(1).intersection(Rect2i(0, 0, HomeCatalog.PLOT, HomeCatalog.PLOT))
	MeshUtil.box(root, Vector3(area.size.x, 0.02, area.size.y), Color("7fc46a"),
			Vector3(area.get_center().x - HALF, -0.01, area.get_center().y - HALF))
	root.add_child(build(type, addon_ids, false, highlight))
	for item in items:
		var node := FurnitureCatalog.build(item["id"], item["c"], false, item.get("s", 0))
		node.position = Vector3(item["x"] + 0.5 - HALF, 0, item["z"] + 0.5 - HALF) \
				+ FurnitureCatalog.center_offset(item["id"], item["r"])
		node.rotation_degrees.y = 90 * item["r"]
		root.add_child(node)
	return root


# --- Pieces ------------------------------------------------------------------------

## Plain wall from cell `a` to cell `b` (inclusive) along one grid line.
static func _wall_run(root: Node3D, line: String, a: int, b: int, wall: Color, trim: Color, height: float,
		solid: bool) -> void:
	var parts := line.split(":")
	var at := int(parts[1]) - HALF
	var mid := (a + b + 1) / 2.0 - HALF
	var length := b - a + 1 + WALL
	var horizontal := parts[0] == "h"
	var size := Vector3(length, height, WALL) if horizontal else Vector3(WALL, height, length)
	var pos := Vector3(mid, height / 2.0, at) if horizontal else Vector3(at, height / 2.0, mid)
	MeshUtil.box(root, size, wall, pos)
	var cap := Vector3(length, CAP.x, CAP.y) if horizontal else Vector3(CAP.y, CAP.x, length)
	MeshUtil.box(root, cap, trim, Vector3(pos.x, height + CAP.x / 2.0, pos.z))
	if solid:
		MeshUtil.collider(root, size, pos)


## A wall piece with a window. Pieces run along their own X axis. From
## outside, the glass is opaque with a cross of glazing bars.
static func _window(piece: Node3D, wall: Color, trim: Color, height: float, solid: bool, outside := false) -> void:
	var low := height * 0.35
	var high := height * 0.77
	var width := 1.0 + WALL
	MeshUtil.box(piece, Vector3(width, low, WALL), wall, Vector3(0, low / 2.0, 0))
	MeshUtil.box(piece, Vector3(width, height - high, WALL), wall, Vector3(0, (high + height) / 2.0, 0))
	for x in [-0.46, 0.46]:
		MeshUtil.box(piece, Vector3(0.2, high - low, WALL), wall, Vector3(x, (low + high) / 2.0, 0))
	MeshUtil.box(piece, Vector3(0.72, high - low, 0.03), GLASS_OUTSIDE if outside else GLASS, Vector3(0, (low + high) / 2.0, 0))
	if outside:
		MeshUtil.box(piece, Vector3(0.72, 0.04, 0.06), trim.lightened(0.5), Vector3(0, (low + high) / 2.0, 0))
		MeshUtil.box(piece, Vector3(0.04, high - low, 0.06), trim.lightened(0.5), Vector3(0, (low + high) / 2.0, 0))
	MeshUtil.box(piece, Vector3(0.86, 0.05, WALL + 0.12), trim, Vector3(0, low, 0))
	MeshUtil.box(piece, Vector3(width, CAP.x, CAP.y), trim, Vector3(0, height + CAP.x / 2.0, 0))
	if solid:
		MeshUtil.collider(piece, Vector3(1.0, height, WALL), Vector3(0, height / 2.0, 0))


## A wall piece with an open doorway in the middle.
static func _doorway(piece: Node3D, wall: Color, trim: Color, height: float, solid: bool) -> void:
	var door_h := minf(2.1, height - 0.25)
	for x in [-0.45, 0.45]:
		MeshUtil.box(piece, Vector3(0.22 + WALL / 2.0, door_h, WALL), wall, Vector3(x * (1.0 + WALL / 4.0), door_h / 2.0, 0))
		MeshUtil.box(piece, Vector3(0.06, door_h, WALL + 0.05), trim, Vector3(signf(x) * 0.33, door_h / 2.0, 0))
		if solid:
			MeshUtil.collider(piece, Vector3(0.22, door_h, WALL), Vector3(x, door_h / 2.0, 0))
	MeshUtil.box(piece, Vector3(1.0 + WALL, height - door_h, WALL), wall, Vector3(0, (door_h + height) / 2.0, 0))
	MeshUtil.box(piece, Vector3(0.72, 0.06, WALL + 0.05), trim, Vector3(0, door_h, 0))
	MeshUtil.box(piece, Vector3(1.0 + WALL, CAP.x, CAP.y), trim, Vector3(0, height + CAP.x / 2.0, 0))
	if solid:
		MeshUtil.collider(piece, Vector3(1.0, height - door_h, WALL), Vector3(0, (door_h + height) / 2.0, 0))


## A doorway with a shut door in it: a front door (walk into it to go in or
## out) or, from outside, any door.
static func _door(piece: Node3D, wall: Color, trim: Color, height: float, solid: bool, color: Color) -> void:
	_doorway(piece, wall, trim, height, solid)
	var door_h := minf(2.1, height - 0.25) - 0.03
	MeshUtil.box(piece, Vector3(0.62, door_h, 0.06), color, Vector3(0, door_h / 2.0, 0))
	MeshUtil.box(piece, Vector3(0.28, 0.28, 0.08), GLASS_OUTSIDE, Vector3(0, door_h * 0.74, 0))
	for face in [-1.0, 1.0]:
		MeshUtil.sphere(piece, 0.04, KNOB, Vector3(0.21, door_h * 0.48, face * 0.05))
	if solid:
		MeshUtil.collider(piece, Vector3(0.66, door_h, WALL), Vector3(0, door_h / 2.0, 0))


## A stretch of deck railing: two posts and two rails.
static func _rail(piece: Node3D, wood: Color, solid: bool) -> void:
	for x in [-0.47, 0.47]:
		MeshUtil.box(piece, Vector3(0.1, RAIL_HEIGHT, 0.1), wood, Vector3(x, RAIL_HEIGHT / 2.0, 0))
	for y in [0.4, RAIL_HEIGHT - 0.06]:
		MeshUtil.box(piece, Vector3(1.0, 0.07, 0.07), wood, Vector3(0, y, 0))
	if solid:
		MeshUtil.collider(piece, Vector3(1.0, RAIL_HEIGHT, 0.1), Vector3(0, RAIL_HEIGHT / 2.0, 0))


## A gate in a deck's railing: taller posts and a shut gate of slats.
static func _gate(piece: Node3D, wood: Color, solid: bool) -> void:
	for x in [-0.47, 0.47]:
		MeshUtil.box(piece, Vector3(0.13, RAIL_HEIGHT + 0.25, 0.13), wood, Vector3(x, (RAIL_HEIGHT + 0.25) / 2.0, 0))
		MeshUtil.sphere(piece, 0.08, wood.lightened(0.2), Vector3(x, RAIL_HEIGHT + 0.3, 0))
	var slat := wood.lightened(0.25)
	for i in 5:
		MeshUtil.box(piece, Vector3(0.1, RAIL_HEIGHT - 0.1, 0.05), slat, Vector3(-0.32 + i * 0.16, RAIL_HEIGHT / 2.0, 0))
	for y in [0.2, RAIL_HEIGHT - 0.12]:
		MeshUtil.box(piece, Vector3(0.82, 0.07, 0.07), wood, Vector3(0, y, 0.03))
	if solid:
		MeshUtil.collider(piece, Vector3(1.0, RAIL_HEIGHT, 0.1), Vector3(0, RAIL_HEIGHT / 2.0, 0))


## A gable roof over a room, its ridge along the room's long side: two sloping
## slabs that overhang a little, and wall-colored triangles closing each end.
## `spots` dots it with white, like a toadstool's cap.
static func _roof(root: Node3D, rect: Array, gable: Color, color: Color, height: float, max_rise: float,
		spots: bool) -> void:
	var along_x: bool = rect[2] >= rect[3]
	var length := float(rect[2] if along_x else rect[3]) + WALL
	var span := float(rect[3] if along_x else rect[2]) + WALL
	var rise := minf(span * 0.35, max_rise)
	var yaw := 0.0 if along_x else PI / 2.0
	var turn := Basis(Vector3.UP, yaw)
	var base := Vector3(rect[0] + rect[2] / 2.0 - HALF, height + CAP.x, rect[1] + rect[3] / 2.0 - HALF)
	for end in [-1.0, 1.0]:
		var g := PrismMesh.new()
		g.size = Vector3(span, rise, WALL)
		MeshUtil.add(root, g, gable, base + turn * Vector3(end * (length - WALL) / 2.0, rise / 2.0, 0),
				Vector3(0, rad_to_deg(yaw) + 90.0, 0))
	var angle := atan2(rise, span / 2.0)
	var slope := (span / 2.0) / cos(angle) + 0.35
	for side in [-1.0, 1.0]:
		var down := Vector3(0, -sin(angle), side * cos(angle))
		var up := Vector3(0, cos(angle), side * sin(angle))
		var mid := Vector3(0, rise / 2.0, side * span / 4.0) + down * 0.17 + up * 0.05
		var slab := MeshUtil.box(root, Vector3(length + 0.35, 0.1, slope), color, base + turn * mid)
		slab.rotation = Vector3(side * angle, yaw, 0)
		if spots:
			for i in 3:
				var at := Vector3((i - 1) * length * 0.3, rise * 0.45, side * span * 0.28) + up * 0.08
				MeshUtil.sphere(root, 0.24, Color("fff6ea"), base + turn * at, Vector3(1, 0.35, 1))
	MeshUtil.box(root, Vector3(length + 0.35, 0.09, 0.18), color.darkened(0.2), base + Vector3(0, rise + 0.04, 0),
			Vector3(0, rad_to_deg(yaw), 0))


## A tent's top: a ridge pole along its long side, held up over the middle of
## each end, with a canvas triangle closing each end. The middle stays open, so
## you can see in.
static func _tent_top(root: Node3D, rect: Array, canvas: Color, trim: Color, height: float) -> void:
	var along_x: bool = rect[2] >= rect[3]
	var length := float(rect[2] if along_x else rect[3])
	var span := float(rect[3] if along_x else rect[2])
	var rise := minf(1.1, span * 0.4)
	var center := Vector3(rect[0] + rect[2] / 2.0 - HALF, height, rect[1] + rect[3] / 2.0 - HALF)
	var turn := Vector3(0, 0 if along_x else 90, 0)
	var wood := Color("8d5b3a")
	var pole := CylinderMesh.new()
	pole.top_radius = 0.05
	pole.bottom_radius = 0.05
	pole.height = length + 0.3
	pole.radial_segments = 8
	MeshUtil.add(root, pole, wood, center + Vector3(0, rise, 0), Vector3(0, turn.y, 90))
	for end in [-1, 1]:
		var gable := PrismMesh.new()
		gable.size = Vector3(span + WALL, rise, 0.06)
		var offset := Vector3(end * length / 2.0, rise / 2.0, 0).rotated(Vector3.UP, deg_to_rad(turn.y))
		MeshUtil.add(root, gable, canvas, center + offset, Vector3(0, turn.y + 90, 0))
	_flags(root, rect, trim, height, rise)


## A little pennant on a pole at each end of a tent's ridge.
static func _flags(root: Node3D, rect: Array, trim: Color, height: float, rise: float) -> void:
	var along_x: bool = rect[2] >= rect[3]
	var length := float(rect[2] if along_x else rect[3])
	var center := Vector3(rect[0] + rect[2] / 2.0 - HALF, height, rect[1] + rect[3] / 2.0 - HALF)
	var turn := 0.0 if along_x else 90.0
	for end in [-1, 1]:
		var flag := Vector3(end * (length / 2.0 + 0.1), rise + 0.25, 0).rotated(Vector3.UP, deg_to_rad(turn))
		MeshUtil.box(root, Vector3(0.04, 0.5, 0.04), Color("8d5b3a"), center + flag)
		MeshUtil.add(root, _pennant(), trim, center + flag + Vector3(0, 0.12, 0), Vector3(0, turn, -90))


static func _pennant() -> PrismMesh:
	var m := PrismMesh.new()
	m.size = Vector3(0.22, 0.34, 0.02)
	return m


## Darker lines across a deck, so it reads as boards.
static func _planks(root: Node3D, rect: Array, color: Color) -> void:
	var along_x: bool = rect[2] >= rect[3]
	var across := float(rect[3] if along_x else rect[2])
	var count := int(across / 0.5)
	for i in range(1, count):
		var t: float = rect[1 if along_x else 0] + i * 0.5 - HALF
		var size := Vector3(rect[2] - 0.04, 0.004, 0.025) if along_x else Vector3(0.025, 0.004, rect[3] - 0.04)
		var pos := Vector3(rect[0] + rect[2] / 2.0 - HALF, FurnitureCatalog.FLOOR_H + 0.002, t) if along_x \
				else Vector3(t, FurnitureCatalog.FLOOR_H + 0.002, rect[1] + rect[3] / 2.0 - HALF)
		MeshUtil.box(root, size, color, pos)


## One piece of decor standing on its cells: the licensed model scaled to its
## height, or a simple stand-in made of shapes.
static func decor(d: Dictionary, solid := true) -> Node3D:
	var cells: Array = d["cells"]
	var root := Node3D.new()
	root.position = Vector3(cells[0] + cells[2] / 2.0 - HALF, 0, cells[1] + cells[3] / 2.0 - HALF)
	var height := float(d.get("height", 1.0))
	if height > 3.0:
		root.set_meta("tall", true)
	var model := Art.instance(d["model"])
	var footprint := Vector3(cells[2], height, cells[3])
	if model:
		var box := Art.bounds(model)
		var s := height / maxf(box.size.y, 0.01)
		model.scale = Vector3.ONE * s
		model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * s
		model.rotation_degrees.y = 90 * int(d.get("turn", 0))
		model.position = model.position.rotated(Vector3.UP, PI / 2.0 * int(d.get("turn", 0)))
		root.add_child(model)
	else:
		_decor_shape(root, str(d.get("shape", "")), height, footprint)
	if solid:
		# Trunks and stems block, not the leaves or caps above them.
		var tall := str(d.get("shape", "")) in ["tree", "mushroom", "lamp"]
		var size := Vector3(0.6, minf(height, 2.0), 0.6) if tall else Vector3(cells[2] * 0.8, minf(height, 1.0), cells[3] * 0.8)
		MeshUtil.collider(root, size, Vector3(0, size.y / 2.0, 0))
		if d.has("light"):
			var light := OmniLight3D.new()
			light.light_color = MeshUtil.hex(d["light"])
			light.position = Vector3(0, height * 0.8, 0)
			light.omni_range = 4.5
			light.light_energy = 1.2
			root.add_child(light)
	return root


## The signpost in front of a plot, facing the street (+Z).
static func signpost() -> Node3D:
	var root := Node3D.new()
	root.name = "Signpost"
	var model := Art.instance(HomeCatalog.SIGNPOST)
	if model:
		var box := Art.bounds(model)
		var s := 1.6 / maxf(box.size.y, 0.01)
		model.scale = Vector3.ONE * s
		model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * s
		root.add_child(model)
	else:
		MeshUtil.box(root, Vector3(0.1, 1.5, 0.1), Color("8d5b3a"), Vector3(0, 0.75, 0))
		MeshUtil.box(root, Vector3(0.7, 0.35, 0.06), Color("c9965f"), Vector3(0, 1.25, 0.05))
	MeshUtil.collider(root, Vector3(0.2, 1.5, 0.2), Vector3(0, 0.75, 0))
	var icon := Sprite3D.new()
	icon.texture = UiTheme.icon("house_with_garden")
	icon.pixel_size = 0.004
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.shaded = false
	icon.position.y = 2.0
	root.add_child(icon)
	return root


static func _decor_shape(root: Node3D, shape: String, height: float, footprint: Vector3) -> void:
	var wood := Color("8d5b3a")
	match shape:
		"tree":
			MeshUtil.cylinder(root, 0.22, 0.32, height * 0.5, wood, Vector3(0, height * 0.25, 0))
			MeshUtil.sphere(root, height * 0.3, Color("5aa04a"), Vector3(0, height * 0.65, 0))
			MeshUtil.sphere(root, height * 0.22, Color("6fb85a"), Vector3(height * 0.15, height * 0.82, height * 0.1))
		"mushroom":
			MeshUtil.cylinder(root, 0.3, 0.4, height * 0.7, Color("f3ead8"), Vector3(0, height * 0.35, 0))
			MeshUtil.sphere(root, footprint.x * 0.5, Color("e2504c"), Vector3(0, height * 0.75, 0), Vector3(1, 0.5, 1))
		"lamp":
			MeshUtil.cylinder(root, 0.05, 0.07, height, Color("4a3d5c"), Vector3(0, height / 2.0, 0))
			MeshUtil.sphere(root, 0.18, Color("e4d4ff"), Vector3(0, height, 0))
		"fire":
			for i in 6:
				var a := TAU * i / 6.0
				MeshUtil.sphere(root, 0.1, Color("8a8580"), Vector3(cos(a) * 0.3, 0.08, sin(a) * 0.3))
			MeshUtil.cylinder(root, 0.0, 0.22, height * 0.8, Color("ff9a3c"), Vector3(0, height * 0.4, 0))
		"log":
			MeshUtil.cylinder(root, 0.2, 0.2, maxf(footprint.x, footprint.z) * 0.8, wood, Vector3(0, 0.2, 0),
					Vector3(0, 0, 90) if footprint.x >= footprint.z else Vector3(90, 0, 0))
		_:
			MeshUtil.cylinder(root, 0.3, 0.3, height, wood, Vector3(0, height / 2.0, 0))
