class_name TouchControls
extends Control
## On-screen controls for touch screens: a joystick on the left to walk, a big
## Jump button on the right, and the rest of the screen to look around (drag
## one finger to turn the camera, pinch two to zoom). A quick tap on the world
## that doesn't move is passed on as `tapped`; decorating places things with it.
##
## The joystick floats: it rests in the bottom-left corner, and a thumb put down
## anywhere on the left half of the screen brings it there. It presses the same
## move actions as the arrow keys, harder the further it's pushed, so a small
## push walks and a big one runs.
##
## Fingers on buttons and cards never reach this (it reads unhandled touches),
## but once a finger is walking or looking it keeps doing so even when it slides
## over a button. Sizes are set in screen points, so the controls stay the size
## of a thumb on a phone or a tablet. Shown only in touch mode (see TouchInput).

## Turns the camera by these angles, in radians.
signal look(yaw: float, pitch: float)
## Zooms the camera: above 1 pulls back, below 1 moves closer.
signal zoomed(factor: float)
## A finger went down on the world, so a preview can follow it.
signal pressed_at(pos: Vector2)
## That finger moved away or lifted without tapping.
signal press_ended
signal tapped(pos: Vector2)

const STICK_POINTS := 54.0 # Joystick radius, in screen points.
const JUMP_POINTS := 40.0 # Jump button radius.
const EDGE_POINTS := 20.0 # Gap to the screen's edges.
const LOOK_SPEED := 0.008 # Radians per screen point dragged.
const DEAD_ZONE := 0.12 # Pushes smaller than this (of the radius) don't walk.
const MOVES := ["move_left", "move_right", "move_forward", "move_back"]

## The joystick shows and walks (off while the decorating catalog is open).
var walk_enabled := true:
	set(value):
		walk_enabled = value
		if not value:
			_release_stick()
		_layout()
## The Jump button shows.
var jump_enabled := true:
	set(value):
		jump_enabled = value
		_layout()

## The "slide to walk" and "drag to look" hints go once each has been tried.
static var _walk_learned := false
static var _look_learned := false

var _unit := 1.0 # Layout units per screen point.
var _stick_finger := -1
var _stick_rest := Vector2.ZERO
var _stick_center := Vector2.ZERO
var _knob := Vector2.ZERO
var _looks := {} # finger index -> {start: Vector2, pos: Vector2, moved: bool}
var _pinch := 0.0 # Distance between two looking fingers, for zooming.
var _jump: PanelContainer
var _jump_finger := -2 # -1 is a real mouse (testing on a computer).
var _jump_styles: Array[StyleBoxFlat] = []
var _walk_hint: Control
var _look_hint: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_jump()
	_walk_hint = _hint("Slide to walk", "footprints")
	_look_hint = _hint("Drag to look around", "eye")
	resized.connect(_layout)
	TouchInput.mode_changed.connect(func(_on): _layout())
	_layout()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_EXIT_TREE]:
		release_all()


## Lets go of everything at once, say when a card opens over the controls.
func release_all() -> void:
	_release_stick()
	_release_jump()
	if not _looks.is_empty():
		_looks.clear()
		press_ended.emit()
	_pinch = 0.0


# --- Building and placing ------------------------------------------------------------

func _build_jump() -> void:
	_jump = PanelContainer.new()
	_jump.mouse_filter = Control.MOUSE_FILTER_STOP
	for pressed in [false, true]:
		var style := UiTheme.box(UiTheme.GREEN if not pressed else UiTheme.GREEN.darkened(0.06), 999, 0,
				UiTheme.GREEN.darkened(0.22), Vector4.ZERO)
		style.border_width_bottom = 2 if pressed else 7
		style.shadow_color = UiTheme.SHADOW
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 4)
		_jump_styles.append(style)
	_jump.add_theme_stylebox_override("panel", _jump_styles[0])
	var box := UiTheme.vbox(0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_jump.add_child(box)
	var icon := UiTheme.texture_rect(UiTheme.icon("up_arrow"), 40)
	icon.name = "Icon"
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var text := UiTheme.label("Jump", &"Heading", 20, Color.WHITE)
	text.name = "Text"
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_color_override("font_outline_color", UiTheme.GREEN.darkened(0.3))
	text.add_theme_constant_override("outline_size", 5)
	box.add_child(text)
	_jump.gui_input.connect(_on_jump_input)
	add_child(_jump)


func _hint(text: String, icon_name: String) -> Control:
	var chip := UiTheme.card(&"Banner")
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UiTheme.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	row.add_child(UiTheme.texture_rect(UiTheme.icon(icon_name), 26))
	row.add_child(UiTheme.label(text, &"Heading", 18, Color.WHITE))
	add_child(chip)
	return chip


func _layout() -> void:
	if not is_node_ready():
		return
	visible = TouchInput.active
	if size.x <= 0.0:
		return
	_unit = 1.0 / TouchInput.points_per_unit()
	var edge := EDGE_POINTS * _unit
	var r := _stick_radius()
	_stick_rest = Vector2(edge + r, size.y - edge - r)
	if _stick_finger == -1:
		_stick_center = _stick_rest
	var jr := clampf(JUMP_POINTS * _unit, 52.0, 110.0)
	_jump.visible = jump_enabled
	_jump.custom_minimum_size = Vector2(jr, jr) * 2.0
	_jump.size = _jump.custom_minimum_size
	_jump.position = size - Vector2(edge, edge) - _jump.size
	var icon := _jump.find_child("Icon", true, false) as Control
	icon.custom_minimum_size = Vector2(jr, jr) * 0.75
	(_jump.find_child("Text", true, false) as Label).add_theme_font_size_override("font_size", roundi(jr * 0.3))
	_walk_hint.visible = walk_enabled and not _walk_learned
	_walk_hint.reset_size()
	_walk_hint.position = Vector2(maxf(edge, _stick_rest.x - _walk_hint.size.x / 2),
			_stick_rest.y - r - _walk_hint.size.y - 14)
	_look_hint.visible = jump_enabled and not _look_learned
	_look_hint.reset_size()
	_look_hint.position = Vector2(size.x - edge - _look_hint.size.x, _jump.position.y - _look_hint.size.y - 18)
	queue_redraw()


func _stick_radius() -> float:
	return clampf(STICK_POINTS * _unit, 60.0, 150.0)


## The top of the joystick's corner, so other things can sit above it.
func reserved_top() -> float:
	return _stick_rest.y - _stick_radius() - EDGE_POINTS * _unit


# --- Fingers ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed or not is_visible_in_tree():
		return
	if walk_enabled and _stick_finger == -1 and touch.position.x < size.x * 0.5:
		_stick_finger = touch.index
		var r := _stick_radius()
		_stick_center = touch.position.clamp(Vector2(r, r), size - Vector2(r, r))
		_move_stick(touch.position)
		return
	_looks[touch.index] = {"start": touch.position, "pos": touch.position, "moved": false}
	if _looks.size() == 1:
		pressed_at.emit(touch.position)
	else:
		# A second finger: pinch to zoom, and neither finger is a tap any more.
		if _looks.size() == 2:
			press_ended.emit()
		for info in _looks.values():
			info["moved"] = true
		_pinch = _pinch_distance()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		if event.index == _stick_finger:
			_move_stick(event.position)
			get_viewport().set_input_as_handled()
		elif _looks.has(event.index):
			_drag_look(event)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and not event.pressed:
		if event.index == _stick_finger:
			_release_stick()
		elif _looks.has(event.index):
			_end_look(event)


func _move_stick(pos: Vector2) -> void:
	var r := _stick_radius()
	_knob = (pos - _stick_center).limit_length(r)
	var push := _knob / r
	var amount := inverse_lerp(DEAD_ZONE, 1.0, push.length())
	push = push.normalized() * amount if amount > 0.0 else Vector2.ZERO
	if push != Vector2.ZERO and not _walk_learned:
		_walk_learned = true
		_walk_hint.visible = false
	_press("move_right", push.x)
	_press("move_left", -push.x)
	_press("move_back", push.y)
	_press("move_forward", -push.y)
	queue_redraw()


func _press(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func _release_stick() -> void:
	if _stick_finger == -1 and _knob == Vector2.ZERO:
		return
	_stick_finger = -1
	_knob = Vector2.ZERO
	_stick_center = _stick_rest
	for action in MOVES:
		_press(action, 0.0)
	queue_redraw()


func _drag_look(drag: InputEventScreenDrag) -> void:
	var info: Dictionary = _looks[drag.index]
	# Browsers can report a wrong `relative` while two fingers are down, so
	# each finger's own last position gives the distance moved.
	var moved: Vector2 = drag.position - info["pos"]
	info["pos"] = drag.position
	if not info["moved"] and drag.position.distance_to(info["start"]) > TouchInput.tap_slop():
		info["moved"] = true
		press_ended.emit()
	if _looks.size() >= 2:
		var d := _pinch_distance()
		if _pinch > 0.0 and d > 0.0:
			zoomed.emit(_pinch / d)
		_pinch = d
	elif info["moved"]:
		var turn := LOOK_SPEED / _unit
		look.emit(-moved.x * turn, -moved.y * turn)
		if not _look_learned:
			_look_learned = true
			_look_hint.visible = false


func _end_look(touch: InputEventScreenTouch) -> void:
	var info: Dictionary = _looks[touch.index]
	_looks.erase(touch.index)
	_pinch = _pinch_distance() if _looks.size() >= 2 else 0.0
	if _looks.is_empty() and not info["moved"]:
		if touch.canceled:
			press_ended.emit()
		else:
			tapped.emit(touch.position)


func _pinch_distance() -> float:
	var points: Array = _looks.values()
	if points.size() < 2:
		return 0.0
	return (points[0]["pos"] as Vector2).distance_to(points[1]["pos"])


func _on_jump_input(event: InputEvent) -> void:
	# A touch, or a real mouse; never the pretend mouse a touch also makes.
	var finger := -2
	var down := false
	if event is InputEventScreenTouch:
		finger = event.index
		down = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		finger = -1
		down = event.pressed
	else:
		return
	_jump.accept_event()
	if down and _jump_finger == -2:
		_jump_finger = finger
		Input.action_press("jump")
		_jump.add_theme_stylebox_override("panel", _jump_styles[1])
	elif not down and finger == _jump_finger:
		_release_jump()


func _release_jump() -> void:
	if _jump_finger == -2:
		return
	_jump_finger = -2
	Input.action_release("jump")
	_jump.add_theme_stylebox_override("panel", _jump_styles[0])


# --- Drawing --------------------------------------------------------------------------

func _draw() -> void:
	if not walk_enabled:
		return
	var r := _stick_radius()
	var c := _stick_center
	var held := _stick_finger != -1
	var fade := 1.0 if held else 0.8
	draw_circle(c + Vector2(0, 5), r, Color(UiTheme.SHADOW, 0.16 * fade), true, -1.0, true)
	draw_circle(c, r, Color(1, 1, 1, 0.3 * fade), true, -1.0, true)
	draw_arc(c, r - 2.0, 0.0, TAU, 72, Color(1, 1, 1, 0.9 * fade), 4.0, true)
	# Little arrows around the edge say "push me any way".
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var tip := c + dir * r * 0.86
		var back := c + dir * r * 0.7
		var side := dir.orthogonal() * r * 0.11
		draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), Color(1, 1, 1, 0.9 * fade))
	var k := c + _knob
	var kr := r * 0.46
	draw_circle(k + Vector2(0, 5), kr, Color(UiTheme.SHADOW, 0.3), true, -1.0, true)
	draw_circle(k, kr, UiTheme.PAPER, true, -1.0, true)
	draw_arc(k, kr - 3.0, 0.0, TAU, 48, UiTheme.BLUE, 6.0, true)
	var icon := UiTheme.icon("footprints")
	var s := kr * 1.05
	draw_texture_rect(icon, Rect2(k - Vector2(s, s) / 2.0, Vector2(s, s)), false)
