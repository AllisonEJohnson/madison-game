class_name House
extends Node3D
## One player's plot: a square grid of cells holding floors, walls and objects.
## The node sits at the plot center; cell (0, 0) is the plot's local -X/-Z corner.

const PLOT_SIZE := 12
const MAX_ITEMS := 600

var owner_id := 0
var layout: Array = []
var _items_root: Node3D
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


func set_owner_name(display_name: String) -> void:
	_sign.text = "%s's Home" % display_name if display_name != "" else "Free plot"


func set_layout(new_layout: Variant) -> void:
	layout = sanitize_layout(new_layout)
	_rebuild()


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
		var clean := {"id": id, "x": x, "z": z, "r": posmod(r, 4), "c": Color.html(c).to_html(false)}
		var key := _slot_key(clean)
		if seen.has(key):
			continue
		seen[key] = true
		out.append(clean)
	return out


## Items on the same layer in the same cell replace each other; walls also key on edge.
static func _slot_key(item: Dictionary) -> String:
	var layer := FurnitureCatalog.layer(item["id"])
	var suffix := ":%d" % item["r"] if layer == "wall" else ""
	return "%s:%d:%d%s" % [layer, item["x"], item["z"], suffix]


func place(id: String, x: int, z: int, r: int, color_hex: String) -> bool:
	if not FurnitureCatalog.ITEMS.has(id) or x < 0 or z < 0 or x >= PLOT_SIZE or z >= PLOT_SIZE:
		return false
	var item := {"id": id, "x": x, "z": z, "r": posmod(r, 4), "c": color_hex}
	var key := _slot_key(item)
	for i in range(layout.size() - 1, -1, -1):
		if _slot_key(layout[i]) == key:
			layout.remove_at(i)
	if layout.size() >= MAX_ITEMS:
		return false
	layout.append(item)
	_rebuild()
	return true


## Removes the top-most thing in a cell: an object, then a wall, then the floor.
func remove_at(x: int, z: int) -> bool:
	for wanted in ["object", "wall", "floor"]:
		for i in range(layout.size() - 1, -1, -1):
			var item: Dictionary = layout[i]
			if item["x"] == x and item["z"] == z and FurnitureCatalog.layer(item["id"]) == wanted:
				layout.remove_at(i)
				_rebuild()
				return true
	return false


func cell_center(x: int, z: int) -> Vector3:
	return Vector3(x + 0.5 - PLOT_SIZE / 2.0, 0.0, z + 0.5 - PLOT_SIZE / 2.0)


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
		var node := FurnitureCatalog.build(item["id"], item["c"])
		node.position = cell_center(item["x"], item["z"])
		node.rotation_degrees.y = 90 * item["r"]
		_items_root.add_child(node)
