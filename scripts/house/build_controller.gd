class_name BuildController
extends Node
## Lets the local player edit their own plot: a ghost preview follows the
## mouse on the grid, and edits are saved locally and sent to the host.

signal layout_edited(layout: Array)

const SEND_DELAY := 0.3

var active := false
var house: House
var player: Player
var item_id := "wall"
var item_rotation := 0
var item_color := Color.html(FurnitureCatalog.ITEMS["wall"]["color"])

var _ghost: Node3D
var _cell := Vector2i(-1, -1)
var _right_press := Vector2.ZERO
var _send_timer := -1.0


func set_active(on: bool) -> void:
	active = on and house != null and player != null
	_refresh_ghost()


func select_item(id: String) -> void:
	item_id = id
	item_color = Color.html(FurnitureCatalog.ITEMS[id]["color"])
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
	_ghost = FurnitureCatalog.build(item_id, item_color.to_html(false), false)
	MeshUtil.make_ghost(_ghost, Color(0.45, 0.85, 1.0, 0.5))
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
	_ghost.visible = _cell.x >= 0
	if _ghost.visible:
		_ghost.position = house.cell_center(_cell.x, _cell.y)
		_ghost.rotation_degrees.y = 90 * item_rotation


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("build_rotate"):
		item_rotation = (item_rotation + 1) % 4
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _cell.x >= 0:
			if house.place(item_id, _cell.x, _cell.y, item_rotation, item_color.to_html(false)):
				_edited()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# A short right click removes; a right drag still orbits the camera.
			if event.pressed:
				_right_press = event.position
			elif event.position.distance_to(_right_press) < 6.0 and _cell.x >= 0:
				if house.remove_at(_cell.x, _cell.y):
					_edited()


func _edited() -> void:
	GameState.profile["house"] = house.layout.duplicate(true)
	GameState.save_profile()
	_send_timer = SEND_DELAY
