class_name House
extends Node3D
## One player's plot and the home they live in there: its ready-built rooms
## (see HomeCatalog and HomeShell) and the furniture they placed. The node sits
## at the plot center; cell (0, 0) is the plot's local -X/-Z corner.
## Furniture is a list of {"id", "x", "z", "r" rotation, "c" paint color, "s" style}.

const PLOT_SIZE := HomeCatalog.PLOT
## Never more pieces than this in one home, whatever its rooms allow.
const MAX_ITEMS := 200

var owner_id := 0
## The signpost by the street: standing there opens the Homes window. Only the
## plot's own player gets it (the world turns it on).
var sign_zone: InteractZone
## The home on this plot ("" for a free plot) and the add-ons built.
var home_type := ""
var rooms: Array = []
## The furniture placed in it.
var layout: Array = []
## How many pieces of furniture this home holds (see HomeCatalog.capacity).
var capacity := 0
var _blocked := {}
var _owner_name := ""
var _items_root: Node3D
var _shell: Node3D
var _plans: Node3D
var _sign: Label3D


func _init() -> void:
	_items_root = Node3D.new()
	_items_root.name = "Items"
	add_child(_items_root)
	var lawn := MeshUtil.box(self, Vector3(PLOT_SIZE, 0.02, PLOT_SIZE), Color("7fc46a"), Vector3(0, 0.01, 0))
	lawn.name = "Lawn"
	for i in 4:
		var edge := Node3D.new()
		edge.rotation_degrees.y = 90 * i
		add_child(edge)
		MeshUtil.box(edge, Vector3(PLOT_SIZE, 0.08, 0.15), Color("e9e2cf"), Vector3(0, 0.04, PLOT_SIZE / 2.0))
	_sign = Label3D.new()
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.pixel_size = 0.008
	_sign.outline_size = 12
	_sign.position = Vector3(0, 3.6, PLOT_SIZE / 2.0)
	add_child(_sign)
	var post := HomeShell.signpost()
	post.position = Vector3(1.7, 0, PLOT_SIZE / 2.0 + 0.35)
	add_child(post)
	sign_zone = InteractZone.new().setup("Your homes", "Move to another home, or add rooms", "house_with_garden",
			"Homes", 1.6)
	sign_zone.set_meta("homes", true)
	sign_zone.enabled = false
	sign_zone.position = Vector3(1.7, 0, PLOT_SIZE / 2.0 + 1.2)
	add_child(sign_zone)


func set_owner_name(display_name: String) -> void:
	_owner_name = display_name
	_show_sign()


func _show_sign() -> void:
	if _owner_name == "":
		_sign.text = "Free plot"
	elif home_type == "":
		_sign.text = "%s's Home" % _owner_name
	else:
		_sign.text = "%s's %s" % [_owner_name, HomeCatalog.home_name(home_type)]


## Shows a home ({"type", "rooms", "items"}, checked first). The rooms are only
## rebuilt when the home or its add-ons change.
func set_home(home: Variant) -> void:
	var clean := HomeCatalog.sanitize(home)
	if clean["type"] != home_type or clean["rooms"] != rooms or _shell == null:
		home_type = clean["type"]
		rooms = clean["rooms"]
		capacity = HomeCatalog.capacity(home_type, rooms)
		_blocked = HomeCatalog.blocked(home_type)
		if _shell:
			_shell.queue_free()
		_shell = HomeShell.build(home_type, rooms)
		add_child(_shell)
		set_decorating(false)
		_show_sign()
	layout = clean["items"]
	_rebuild()


## Empties the plot (its player left).
func clear() -> void:
	home_type = ""
	rooms = []
	layout = []
	capacity = 0
	_blocked = {}
	if _shell:
		_shell.queue_free()
		_shell = null
	set_decorating(false)
	_show_sign()
	_rebuild()


## The home as it travels and saves: {"type", "rooms", "items"}.
func home() -> Dictionary:
	return {"type": home_type, "rooms": rooms.duplicate(), "items": layout.duplicate(true)}


## While its owner decorates: shows where rooms not built yet would go, labeled
## with `labels` (add-on id -> text), and hides big trees that block the view.
func set_decorating(on: bool, labels := {}) -> void:
	if _plans:
		_plans.queue_free()
		_plans = null
	if on and home_type != "":
		_plans = HomeShell.plans(home_type, rooms, labels)
		add_child(_plans)
	if _shell:
		HomeShell.show_tall_decor(_shell, not on)


static func sanitize_layout(data: Variant) -> Array:
	var out := []
	if not data is Array:
		return out
	var seen := {}
	for item in data:
		if out.size() >= MAX_ITEMS:
			break
		if not item is Dictionary:
			continue
		var id := str(item.get("id", ""))
		if not FurnitureCatalog.ITEMS.has(id):
			continue
		var x := int(item.get("x", -1)) if (item.get("x") is int or item.get("x") is float) else -1
		var z := int(item.get("z", -1)) if (item.get("z") is int or item.get("z") is float) else -1
		var r := int(item.get("r", 0)) if (item.get("r") is int or item.get("r") is float) else 0
		if x < 0 or z < 0 or x >= PLOT_SIZE or z >= PLOT_SIZE:
			continue
		var c := str(item.get("c", ""))
		if not Color.html_is_valid(c):
			c = FurnitureCatalog.ITEMS[id]["color"]
		var s := int(item.get("s", 0)) if (item.get("s") is int or item.get("s") is float) else 0
		s = clampi(s, 0, maxi(FurnitureCatalog.style_count(id) - 1, 0))
		var clean := {"id": id, "x": x, "z": z, "r": posmod(r, 4), "c": Color.html(c).to_html(false), "s": s}
		var keys := _slot_keys(clean)
		if keys.is_empty() or keys.any(func(k): return seen.has(k)):
			continue
		for k in keys:
			seen[k] = true
		out.append(clean)
	return out


## Items on the same layer in the same cell replace each other; walls also key
## on edge, and big objects take every cell they cover. Empty if off the plot.
static func _slot_keys(item: Dictionary) -> Array:
	var layer := FurnitureCatalog.layer(item["id"])
	var keys := []
	for cell in FurnitureCatalog.cells(item["id"], item["x"], item["z"], item["r"]):
		if cell.x < 0 or cell.y < 0 or cell.x >= PLOT_SIZE or cell.y >= PLOT_SIZE:
			return []
		keys.append("%s:%d:%d" % [layer, cell.x, cell.y])
	if layer == "wall":
		keys[0] += ":%d" % item["r"]
	return keys


## True when a piece could go here: on the plot, off the decor, and with room
## left in the home (counting anything it would replace).
func can_fit(id: String, x: int, z: int, r: int) -> bool:
	return _fits_plot(id, x, z, r) and _count_after(id, x, z, r) <= capacity


## True when the home is too full for this piece (but the spot itself is fine).
func is_full_for(id: String, x: int, z: int, r: int) -> bool:
	return _fits_plot(id, x, z, r) and _count_after(id, x, z, r) > capacity


func _fits_plot(id: String, x: int, z: int, r: int) -> bool:
	if not FurnitureCatalog.ITEMS.has(id) or FurnitureCatalog.layer(id) != "object" or home_type == "":
		return false
	var item := {"id": id, "x": x, "z": z, "r": posmod(r, 4)}
	if _slot_keys(item).is_empty():
		return false
	for cell in FurnitureCatalog.cells(id, x, z, r):
		if _blocked.has(cell):
			return false
	return true


func _count_after(id: String, x: int, z: int, r: int) -> int:
	var keys := _slot_keys({"id": id, "x": x, "z": z, "r": posmod(r, 4)})
	var replaced := layout.filter(func(i): return _slot_keys(i).any(func(k): return k in keys)).size()
	return layout.size() - replaced + 1


func place(id: String, x: int, z: int, r: int, color_hex: String, style := 0) -> bool:
	if not can_fit(id, x, z, r):
		return false
	var item := {"id": id, "x": x, "z": z, "r": posmod(r, 4), "c": color_hex,
		"s": clampi(style, 0, maxi(FurnitureCatalog.style_count(id) - 1, 0))}
	var keys := _slot_keys(item)
	for i in range(layout.size() - 1, -1, -1):
		if _slot_keys(layout[i]).any(func(k): return k in keys):
			layout.remove_at(i)
	if layout.size() >= MAX_ITEMS:
		return false
	layout.append(item)
	_rebuild()
	return true


## Removes the furniture on a cell. Walls and floors are part of the home,
## so they stay.
func remove_at(x: int, z: int) -> bool:
	for i in range(layout.size() - 1, -1, -1):
		var item: Dictionary = layout[i]
		if FurnitureCatalog.layer(item["id"]) != "object":
			continue
		if Vector2i(x, z) in FurnitureCatalog.cells(item["id"], item["x"], item["z"], item["r"]):
			layout.remove_at(i)
			_rebuild()
			return true
	return false


func cell_center(x: int, z: int) -> Vector3:
	return Vector3(x + 0.5 - PLOT_SIZE / 2.0, 0.0, z + 0.5 - PLOT_SIZE / 2.0)


## Where an item's node goes: the middle of everything it covers.
func item_position(id: String, x: int, z: int, r: int) -> Vector3:
	return cell_center(x, z) + FurnitureCatalog.center_offset(id, r)


## Converts a world position to a grid cell, or (-1, -1) when off the plot.
func world_to_cell(world_pos: Vector3) -> Vector2i:
	var local := to_local(world_pos) + Vector3(PLOT_SIZE / 2.0, 0, PLOT_SIZE / 2.0)
	var cell := Vector2i(floori(local.x), floori(local.z))
	if cell.x < 0 or cell.y < 0 or cell.x >= PLOT_SIZE or cell.y >= PLOT_SIZE:
		return Vector2i(-1, -1)
	return cell


func _rebuild() -> void:
	for child in _items_root.get_children():
		child.queue_free()
	for item in layout:
		var node := FurnitureCatalog.build(item["id"], item["c"], true, item.get("s", 0))
		node.position = item_position(item["id"], item["x"], item["z"], item["r"])
		node.rotation_degrees.y = 90 * item["r"]
		_items_root.add_child(node)
