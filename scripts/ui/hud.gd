class_name Hud
extends CanvasLayer
## In-world interface: status, pet needs, quick chat, and the build palette.

signal phrase_chosen(index: int)
signal item_selected(id: String)
signal color_changed(color: Color)
signal build_toggled
signal leave_pressed

var _status: Label
var _toast: Label
var _toast_time := 0.0
var _chat_log: Label
var _chat_lines: Array[String] = []
var _pet_title: Label
var _fullness: ProgressBar
var _happiness: ProgressBar
var _build_panel: PanelContainer
var _color_button: ColorPickerButton
var _item_buttons := {}
var _phrase_menu: PopupMenu


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Top-left: status and controls help.
	var info := _panel(root, Control.PRESET_TOP_LEFT, Vector2(12, 12))
	var info_box := VBoxContainer.new()
	info.add_child(info_box)
	_status = Label.new()
	info_box.add_child(_status)
	var help := Label.new()
	help.text = "WASD move · Space jump · Right-drag look · Wheel zoom\nF feed pet · G play with pet · T quick chat\nB build mode · H go home · Esc leave"
	help.add_theme_font_size_override("font_size", 13)
	help.modulate = Color(1, 1, 1, 0.8)
	info_box.add_child(help)

	# Top-right: pet card and buttons.
	var pet_panel := _panel(root, Control.PRESET_TOP_RIGHT, Vector2(-12, 12))
	pet_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var pet_box := VBoxContainer.new()
	pet_box.custom_minimum_size.x = 220
	pet_panel.add_child(pet_box)
	_pet_title = Label.new()
	pet_box.add_child(_pet_title)
	_fullness = _bar(pet_box, "Fullness", Color("f2994a"))
	_happiness = _bar(pet_box, "Happiness", Color("eb5f9a"))
	var buttons := HBoxContainer.new()
	pet_box.add_child(buttons)
	var chat_button := _button(buttons, "Quick Chat")
	chat_button.pressed.connect(open_quick_chat)
	_button(buttons, "Build").pressed.connect(func(): build_toggled.emit())
	_button(buttons, "Leave").pressed.connect(func(): leave_pressed.emit())

	_phrase_menu = PopupMenu.new()
	for i in SafeNames.CHAT_PHRASES.size():
		_phrase_menu.add_item(SafeNames.CHAT_PHRASES[i], i)
	_phrase_menu.id_pressed.connect(func(id): phrase_chosen.emit(id))
	add_child(_phrase_menu)

	# Bottom-left: chat log.
	_chat_log = Label.new()
	_chat_log.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_chat_log.position = Vector2(14, -180)
	_chat_log.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_chat_log.add_theme_constant_override("outline_size", 6)
	_chat_log.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_chat_log)

	# Center toast for short notices.
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 70
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(_toast)

	_build_build_panel(root)


func _build_build_panel(root: Control) -> void:
	_build_panel = PanelContainer.new()
	_build_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_build_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_build_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_build_panel.position.y = -12
	_build_panel.visible = false
	root.add_child(_build_panel)
	var box := VBoxContainer.new()
	_build_panel.add_child(box)
	var title := Label.new()
	title.text = "BUILD MODE  ·  Left click place  ·  Right click remove  ·  R rotate  ·  B done"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 9
	box.add_child(grid)
	for id in FurnitureCatalog.ids():
		var b := Button.new()
		b.text = FurnitureCatalog.ITEMS[id]["name"]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): item_selected.emit(id))
		grid.add_child(b)
		_item_buttons[id] = b
	var color_row := HBoxContainer.new()
	color_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(color_row)
	var color_label := Label.new()
	color_label.text = "Paint color:"
	color_row.add_child(color_label)
	_color_button = ColorPickerButton.new()
	_color_button.custom_minimum_size = Vector2(80, 28)
	_color_button.edit_alpha = false
	_color_button.color_changed.connect(func(c): color_changed.emit(c))
	color_row.add_child(_color_button)


func _panel(root: Control, preset: int, offset: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(preset)
	p.position += offset
	root.add_child(p)
	return p


func _bar(parent: Control, label_text: String, color: Color) -> ProgressBar:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 13)
	parent.add_child(label)
	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size.y = 14
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func _button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)


func set_status(text: String) -> void:
	if _status:
		_status.text = text


func toast(text: String) -> void:
	_toast.text = text
	_toast_time = 3.0


func set_pet(pet_name: String, species: String) -> void:
	_pet_title.text = "%s the %s" % [pet_name, species]


func set_pet_needs(fullness: float, happiness: float) -> void:
	_fullness.value = fullness
	_happiness.value = happiness


func add_chat(speaker: String, text: String) -> void:
	_chat_lines.append("%s: %s" % [speaker, text])
	while _chat_lines.size() > 7:
		_chat_lines.pop_front()
	_chat_log.text = "\n".join(_chat_lines)


func open_quick_chat() -> void:
	var mouse := get_viewport().get_mouse_position()
	_phrase_menu.popup(Rect2i(Vector2i(mouse), Vector2i.ZERO))


func show_build(active: bool) -> void:
	_build_panel.visible = active


func set_build_selection(id: String, color: Color) -> void:
	for key in _item_buttons:
		_item_buttons[key].button_pressed = key == id
	_color_button.color = color
