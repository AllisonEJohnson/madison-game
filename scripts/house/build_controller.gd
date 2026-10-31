class_name BuildController
extends Node
## Lets the local player edit their own plot: a ghost preview follows the
## mouse on the grid, and edits are saved locally and sent to the host.

signal layout_edited(layout: Array)
## Sent after a successful placement with the entry key ("sofa:3").
signal item_placed(key: String)
## Sent instead of placing when the picked look hasn't been bought yet.
signal purchase_needed(id: String, style: int)
## Sent instead of placing when the home holds all the furniture it can.
signal home_full

const SEND_DELAY := 0.3

var active := false
var house: House
var player: Player
var item_id := "sofa"
var item_rotation := 0
var item_color := Color.html(FurnitureCatalog.ITEMS["sofa"]["color"])
var item_style := 0
## When on, a left click removes instead of placing.
var erasing := false

var _styles := {} # item id -> last style picked, so switching items keeps it

var _ghost: Node3D
var _cell := Vector2i(-1, -1)
var _right_press := Vector2.ZERO
var _send_timer := -1.0


func set_active(on: bool) -> void:
	active = on and house != null and player != null
	# While decorating, outlines show where the home could grow.
	if house:
		house.set_decorating(active, Homes.plan_labels(house.home_type))
	_refresh_ghost()


## Picks what to place. A negative style keeps the last one used for the item.
func select_item(id: String, style := -1) -> void:
	if id != item_id:
		item_color = Color.html(FurnitureCatalog.ITEMS[id]["color"])
	item_id = id
	item_style = style if style >= 0 else _styles.get(id, 0)
	_styles[id] = item_style
	erasing = false
	_refresh_ghost()


## True when the picked look is free or bought, so it can be placed.
func owns_item() -> bool:
	var style := item_style if FurnitureCatalog.has_art(item_id) else 0
	return GameState.owns(ShopCatalog.furniture_key(item_id, style))


func set_erasing(on: bool) -> void:
	erasing = on
	_refresh_ghost()


func rotate_item() -> void:
	item_rotation = (item_rotation + 1) % 4


## Moves to the next (1) or previous (-1) look for the selected item.
func step_style(step: int) -> void:
	var count := FurnitureCatalog.style_count(item_id)
	if count == 0:
		return
	item_style = posmod(item_style + step, count)
	_styles[item_id] = item_style
	_refresh_ghost()


func set_color(c: Color) -> void:
	item_color = c
	_refresh_ghost()


func _refresh_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	if not active:
		return
	if erasing:
		# A red tile marks the cell whose top-most piece will go.
		_ghost = Node3D.new()
		MeshUtil.box(_ghost, Vector3(0.96, 0.1, 0.96), Color(1.0, 0.3, 0.3, 0.55), Vector3(0, 0.08, 0))
		house.add_child(_ghost)
		return
	_ghost = FurnitureCatalog.build(item_id, item_color.to_html(false), false, item_style)
	# Models keep their look so the style can be seen; shapes take a tint.
	MeshUtil.make_ghost(_ghost, Color(0.45, 0.85, 1.0, 0.5), FurnitureCatalog.has_art(item_id))
	house.add_child(_ghost)


func _process(delta: float) -> void:
	if _send_timer >= 0.0:
		_send_timer -= delta
		if _send_timer < 0.0:
			layout_edited.emit(house.layout.duplicate(true))
	if not active or not player.camera:
		return
	var mouse := player.get_viewport().get_mouse_position()
	var origin := player.camera.project_ray_origin(mouse)
	var normal := player.camera.project_ray_normal(mouse)
	var hit = Plane(Vector3.UP, house.global_position.y).intersects_ray(origin, normal)
	_cell = house.world_to_cell(hit) if hit != null else Vector2i(-1, -1)
	# No ghost while the mouse is over a panel or button.
	if player.get_viewport().gui_get_hovered_control() != null:
		_cell = Vector2i(-1, -1)
	_ghost.visible = _cell.x >= 0
	if _ghost.visible and erasing:
		_ghost.position = house.cell_center(_cell.x, _cell.y)
	elif _ghost.visible:
		_ghost.position = house.item_position(item_id, _cell.x, _cell.y, item_rotation)
		_ghost.rotation_degrees.y = 90 * item_rotation


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("build_rotate"):
		rotate_item()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _cell.x >= 0:
			if erasing:
				if house.remove_at(_cell.x, _cell.y):
					_edited()
			elif not owns_item():
				purchase_needed.emit(item_id, item_style)
			elif house.is_full_for(item_id, _cell.x, _cell.y, item_rotation):
				home_full.emit()
			elif house.place(item_id, _cell.x, _cell.y, item_rotation, item_color.to_html(false), item_style):
				_edited()
				item_placed.emit("%s:%d" % [item_id, item_style])
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# A short right click removes; a right drag still orbits the camera.
			if event.pressed:
				_right_press = event.position
			elif event.position.distance_to(_right_press) < 6.0 and _cell.x >= 0:
				if house.remove_at(_cell.x, _cell.y):
					_edited()


func _edited() -> void:
	Homes.set_items(house.layout)
	_send_timer = SEND_DELAY
