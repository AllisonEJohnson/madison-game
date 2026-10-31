extends Control
## Title screen and character creator, built in code. Your character stands
## in a 3D scene that fills the screen; your name and the play buttons float
## on the left, and the style card on the right. The style card's tabs come
## from AvatarBuilder.tabs(), so new options show up without menu changes.

const PET_COLORS := ["e8a35a", "c49a6c", "8d5b3a", "fff3e0", "ffffff", "8a8a8a", "1f1f1f", "f2c94c",
		"e04848", "eb5f9a", "9b51e0", "3f7fd9", "56ccf2", "6fcf97", "2fa37a", "f2994a"]
## How far the camera sits from what it looks at, per view.
const CAMERA_DISTANCE := {"face": 2.6, "head": 3.2, "body": 4.8, "pet": 3.4}
## Picture card sizes for choices, biggest first; long lists get smaller cards
## so there are fewer pages to flip through.
const CARD_SIZES := [Vector2(122, 140), Vector2(96, 124), Vector2(96, 104)]

var _profile: Dictionary
var _preview_root: Node3D
var _camera: Camera3D
var _camera_target := Vector3(0, 0.95, 0)
var _camera_distance := 4.6
var _view := "body"
var _spin := 0.0
var _dragging := false
var _left: Control
var _card: PanelContainer
var _name_label: Label
var _message: PanelContainer
var _port: SpinBox
var _address: LineEdit
var _friends: PanelContainer
var _name_picker: PanelContainer
var _scrim: ColorRect
var _tabs: Array = [] # [{title, icon, view, parts: [{label, icon, key, kind, view, colors: [rows]}]}]
var _tab_buttons: Array[Button] = []
var _part_row: HFlowContainer
var _content: VBoxContainer
var _tab := 0
var _part := 0
var _option_grid: ItemGrid


func _ready() -> void:
	_profile = GameState.profile
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.theme()
	_build_stage()

	# Dragging anywhere outside the cards spins your character.
	var drag := Control.new()
	drag.set_anchors_preset(Control.PRESET_FULL_RECT)
	drag.gui_input.connect(_on_drag_input)
	add_child(drag)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	_left = _build_left()
	row.add_child(_left)
	row.add_child(_build_spin_hint())
	_card = _build_style_card()
	row.add_child(_card)

	_scrim = ColorRect.new()
	_scrim.color = Color(0.1, 0.07, 0.2, 0.4)
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.visible = false
	_scrim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close_name_picker())
	add_child(_scrim)
	_name_picker = _build_name_picker()
	add_child(_name_picker)

	_rebuild_preview()
	_show_tab(0)
	_show_message(Net.menu_message)
	Net.menu_message = ""
	_handle_command_line.call_deferred()


func _handle_command_line() -> void:
	var args := OS.get_cmdline_user_args()
	if "--smoke-test" in args:
		get_tree().root.add_child(load("res://scripts/dev/smoke_test.gd").new())
	for arg in args:
		if arg.begins_with("--screenshot="):
			var shot: Node = load("res://scripts/dev/screenshot.gd").new()
			shot.path = arg.trim_prefix("--screenshot=")
			if "--shot-build" in args:
				shot.press_actions.assign(["go_home", "build_mode"])
				shot.look_down = true
			for ui in args:
				if ui.begins_with("--shot-ui="):
					shot.ui_steps.assign(ui.trim_prefix("--shot-ui=").split(","))
			get_tree().root.add_child(shot)
	for arg in args:
		if arg == "--host":
			_play()
		elif arg.begins_with("--join="):
			_address.text = arg.trim_prefix("--join=")
			_join()


# --- Left: title, name and play ---------------------------------------------------

func _build_left() -> Control:
	var col := UiTheme.vbox(14)
	col.custom_minimum_size.x = 340
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	col.add_child(UiTheme.label("Hometown Pals", &"Title", 50))
	var tagline := UiTheme.label("Style yourself, build a home,\nand bring your pet along!", &"WorldLabel", 19)
	tagline.add_theme_font_override("font", UiTheme.font(800))
	col.add_child(tagline)

	var name_card := UiTheme.card()
	col.add_child(name_card)
	var box := UiTheme.vbox(8)
	name_card.add_child(box)
	box.add_child(UiTheme.label("Your name", &"Hint"))
	_name_label = UiTheme.label("", &"Heading", 28)
	box.add_child(_name_label)
	var buttons := UiTheme.hbox(8)
	box.add_child(buttons)
	var dice := UiTheme.button("New name", "game_die", &"BlueButton", "Pick a random name")
	dice.add_theme_font_size_override("font_size", 18)
	dice.pressed.connect(_random_name)
	buttons.add_child(dice)
	var pick := UiTheme.button("Choose", "pencil", &"", "Choose the words in your name")
	pick.add_theme_font_size_override("font_size", 18)
	pick.pressed.connect(_open_name_picker)
	buttons.add_child(pick)
	var safety := UiTheme.label("Names use friendly words and chat uses set phrases, so everyone stays safe.",
			&"Hint", 13)
	safety.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	safety.custom_minimum_size.x = 300
	box.add_child(safety)
	_update_name_label()

	col.add_child(UiTheme.spacer())

	var surprise := UiTheme.button("Surprise me!", "sparkles", &"PurpleButton", "Try a random style")
	surprise.custom_minimum_size.y = 56
	surprise.pressed.connect(_randomize)
	col.add_child(surprise)

	_message = UiTheme.card(&"Banner")
	_message.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.RED, 18, 0, Color.TRANSPARENT,
			Vector4(16, 10, 16, 10)))
	var message_label := UiTheme.label("", &"", 16, Color.WHITE)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size.x = 300
	_message.add_child(message_label)
	col.add_child(_message)

	_friends = _build_friends()
	col.add_child(_friends)

	var play := UiTheme.button("Play!", "", &"PrimaryButton")
	play.icon = UiTheme.play_icon()
	play.custom_minimum_size.y = 80
	play.add_theme_font_size_override("font_size", 34)
	play.add_theme_constant_override("icon_max_width", 34)
	play.tooltip_text = "Start your neighborhood" + (". Friends can join you." if Net.online_available else "")
	play.pressed.connect(_play)
	col.add_child(play)
	if Net.online_available:
		var friends := UiTheme.button("Play with friends", "busts_in_silhouette", &"",
				"Join a friend's neighborhood")
		friends.custom_minimum_size.y = 54
		friends.pressed.connect(func(): _friends.visible = not _friends.visible)
		col.add_child(friends)
	else:
		var solo := UiTheme.label("In the browser your neighborhood is just for you. "
				+ "Playing with friends needs the downloaded game.", &"WorldLabel", 14)
		solo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		solo.custom_minimum_size.x = 300
		col.add_child(solo)
	return col


## Joining details, for the downloaded game.
func _build_friends() -> PanelContainer:
	var card := UiTheme.card()
	card.visible = false
	var box := UiTheme.vbox(8)
	card.add_child(box)
	box.add_child(UiTheme.label("Join a friend", &"Heading", 20))
	var join_row := UiTheme.hbox(8)
	box.add_child(join_row)
	_address = LineEdit.new()
	_address.text = "127.0.0.1"
	_address.placeholder_text = "Friend's address"
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_address)
	var join := UiTheme.button("Join", "", &"BlueButton")
	join.pressed.connect(_join)
	join_row.add_child(join)
	var port_row := UiTheme.hbox(8)
	box.add_child(port_row)
	port_row.add_child(UiTheme.label("Port", &"Hint"))
	_port = SpinBox.new()
	_port.min_value = 1024
	_port.max_value = 65535
	_port.value = Net.DEFAULT_PORT
	_port.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port_row.add_child(_port)
	box.add_child(UiTheme.label("Play! hosts on this port too.", &"Hint", 13))
	return card


func _build_spin_hint() -> Control:
	var holder := UiTheme.vbox()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.alignment = BoxContainer.ALIGNMENT_END
	var chip := UiTheme.card(&"Banner")
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.INK, 0.55), 20, 0, Color.TRANSPARENT,
			Vector4(14, 6, 16, 8)))
	var row := UiTheme.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	row.add_child(UiTheme.texture_rect(UiTheme.icon("counterclockwise_arrows_button"), 22))
	row.add_child(UiTheme.label("Drag to spin", &"", 16, Color.WHITE))
	holder.add_child(chip)
	return holder


func _show_message(text: String) -> void:
	_message.visible = text != ""
	(_message.get_child(0) as Label).text = text


# --- Names --------------------------------------------------------------------------

func _update_name_label() -> void:
	_name_label.text = SafeNames.display_name(_profile["name_parts"])


func _set_name_part(key: String, value: int) -> void:
	_profile["name_parts"][key] = value
	_update_name_label()
	GameState.save_profile()


func _random_name() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_profile["name_parts"] = SafeNames.random_name_parts(rng)
	_update_name_label()
	GameState.save_profile()


## A card with every name word as a button, plus the number.
func _build_name_picker() -> PanelContainer:
	var card := UiTheme.card()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.visible = false
	var box := UiTheme.vbox(12)
	card.add_child(box)
	var head := UiTheme.hbox(10)
	box.add_child(head)
	head.add_child(UiTheme.texture_rect(UiTheme.icon("pencil"), 36))
	var title := UiTheme.label("", &"Heading", 28)
	title.name = "Preview"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var done := UiTheme.button("Done", "check_mark_button", &"PrimaryButton")
	done.add_theme_font_size_override("font_size", 22)
	done.add_theme_constant_override("icon_max_width", 28)
	done.pressed.connect(_close_name_picker)
	head.add_child(done)
	var cols := UiTheme.hbox(12)
	box.add_child(cols)
	for part in [["adjective", SafeNames.NAME_ADJECTIVES], ["noun", SafeNames.NAME_NOUNS]]:
		var well := UiTheme.card(&"Well")
		cols.add_child(well)
		var grid := GridContainer.new()
		grid.name = part[0]
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		well.add_child(grid)
		for i in part[1].size():
			var chip := UiTheme.button(part[1][i], "", &"ChipButton")
			chip.toggle_mode = true
			chip.custom_minimum_size = Vector2(98, 40)
			chip.pressed.connect(func():
				_set_name_part(part[0], i)
				_fill_name_picker())
			grid.add_child(chip)
	var number := UiTheme.card(&"Well")
	cols.add_child(number)
	var num_box := UiTheme.vbox(8)
	num_box.alignment = BoxContainer.ALIGNMENT_CENTER
	number.add_child(num_box)
	num_box.add_child(UiTheme.label("Number", &"Hint"))
	for step in [1, 0, -1]:
		if step == 0:
			var value := UiTheme.label("", &"Heading", 36)
			value.name = "Number"
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			num_box.add_child(value)
			continue
		var b := UiTheme.icon_button("up_arrow" if step > 0 else "down_arrow", "", 56)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.add_theme_constant_override("icon_max_width", 28)
		b.pressed.connect(func():
			_set_name_part("number", posmod(int(_profile["name_parts"]["number"]) + step, 100))
			_fill_name_picker())
		num_box.add_child(b)
	return card


func _fill_name_picker() -> void:
	var parts: Dictionary = _profile["name_parts"]
	(_name_picker.find_child("Preview", true, false) as Label).text = SafeNames.display_name(parts)
	(_name_picker.find_child("Number", true, false) as Label).text = str(parts["number"])
	for key in ["adjective", "noun"]:
		var grid := _name_picker.find_child(key, true, false)
		for i in grid.get_child_count():
			grid.get_child(i).set_pressed_no_signal(i == int(parts[key]))


func _open_name_picker() -> void:
	_fill_name_picker()
	_name_picker.visible = true
	_scrim.visible = true


func _close_name_picker() -> void:
	_name_picker.visible = false
	_scrim.visible = false


func _play() -> void:
	GameState.save_profile()
	Net.request_host(int(_port.value))


func _join() -> void:
	GameState.save_profile()
	Net.request_join(_address.text.strip_edges(), int(_port.value))


# --- The 3D stage -------------------------------------------------------------------

func _build_stage() -> void:
	var stage := Node3D.new()
	add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Lighting.environment(false)
	stage.add_child(env)
	var sun := Lighting.sun()
	sun.rotation_degrees = Vector3(-40, 25, 0)
	stage.add_child(sun)
	var ground := Node3D.new()
	stage.add_child(ground)
	MeshUtil.cylinder(ground, 60.0, 60.0, 0.1, Color("8fd27a"), Vector3(0, -0.12, 0))
	MeshUtil.cylinder(ground, 1.75, 1.85, 0.14, Color("fbf3e4"), Vector3(0, -0.07, 0))
	MeshUtil.cylinder(ground, 1.6, 1.6, 0.15, Color("e9b97f"), Vector3(0, -0.06, 0))
	_preview_root = Node3D.new()
	stage.add_child(_preview_root)
	_camera = Camera3D.new()
	_camera.fov = 32
	stage.add_child(_camera)
	_camera.make_current()


func _on_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_spin += event.relative.x * 0.01


func _process(delta: float) -> void:
	if not _dragging:
		_spin += delta * 0.3
	var avatar := _preview_root.get_node_or_null("Avatar") as Node3D
	if avatar:
		avatar.rotation.y = sin(_spin) * 0.6
	_place_camera(delta)


## Looks at the current view's target, shifted sideways so it sits in the gap
## between the left column and the style card.
func _place_camera(delta: float) -> void:
	var t := minf(6.0 * delta, 1.0)
	_camera_target = _camera_target.lerp(_view_target(), t)
	_camera_distance = lerpf(_camera_distance, CAMERA_DISTANCE.get(_view, 4.6) * AvatarBuilder.view_zoom(_view), t)
	_camera.position = _camera_target + Vector3(0.18, 0.12, 1.0).normalized() * _camera_distance
	_camera.look_at(_camera_target)
	var screen := get_viewport_rect().size
	if screen.x <= 0.0:
		return
	var gap_center := (_left.get_global_rect().end.x + _card.get_global_rect().position.x) / 2.0
	var ndc := gap_center / screen.x * 2.0 - 1.0
	var half_width := tan(deg_to_rad(_camera.fov) / 2.0) * screen.x / screen.y * _camera_distance
	_camera.h_offset = -ndc * half_width


func _view_target() -> Vector3:
	var face := AvatarBuilder.face_height(_profile["avatar"])
	match _view:
		"face":
			return Vector3(0, face - 0.02, 0)
		"head":
			return Vector3(0, face - 0.15, 0)
		"pet":
			var pet := _preview_root.get_node_or_null("PetModel") as Node3D
			return (pet.position if pet else Vector3.ZERO) + Vector3(0, 0.3, 0)
	return Vector3(0, face * 0.57, 0)


func _rebuild_preview() -> void:
	for child in _preview_root.get_children():
		child.free()
	_preview_root.add_child(AvatarBuilder.build(_profile["avatar"]))
	var pet := PetBuilder.build(_profile["pet"])
	# In front of the avatar, so it stays in the gap between the cards.
	pet.position = Vector3(0.5, 0, 0.7)
	pet.rotation_degrees.y = -25
	_preview_root.add_child(pet)


# --- Right: the style card ------------------------------------------------------------

func _build_style_card() -> PanelContainer:
	_tabs = _creator_tabs()
	var card := UiTheme.card()
	card.custom_minimum_size.x = 560
	var box := UiTheme.vbox(12)
	card.add_child(box)
	var tab_row := UiTheme.hbox(8)
	box.add_child(tab_row)
	for i in _tabs.size():
		var b := UiTheme.stacked_button(_tabs[i]["title"], _tabs[i]["icon"], &"TabButton", 40)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 78
		b.pressed.connect(_show_tab.bind(i))
		tab_row.add_child(b)
		_tab_buttons.append(b)
	_part_row = HFlowContainer.new()
	_part_row.add_theme_constant_override("h_separation", 6)
	_part_row.add_theme_constant_override("v_separation", 6)
	box.add_child(_part_row)
	box.add_child(HSeparator.new())
	_content = UiTheme.vbox(10)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_content)
	return card


## Turns AvatarBuilder.tabs() into tabs of parts: an option row together with
## the color rows that follow it. The pet gets its own tab.
func _creator_tabs() -> Array:
	var out := []
	for tab in AvatarBuilder.tabs():
		var parts := []
		for row in tab["rows"]:
			var colors: bool = row.has("colors")
			if colors and not parts.is_empty() and parts[-1]["kind"] == "options":
				parts[-1]["colors"].append(row)
				continue
			var kind := "colors" if colors else ("slider" if row["key"] == "height" else "options")
			parts.append({"label": row["label"], "icon": row.get("icon", tab.get("icon", "sparkles")),
				"key": row["key"], "kind": kind, "view": row.get("view", tab.get("view", "body")),
				"colors": [row] if colors else []})
		out.append({"title": tab["title"], "icon": tab.get("icon", "sparkles"), "view": tab.get("view", "body"),
			"parts": parts})
	out.append({"title": "Pet", "icon": "paw_prints", "view": "pet", "parts": [
		{"label": "Kind", "icon": "paw_prints", "key": "species", "kind": "pet_species", "view": "pet", "colors": []},
		{"label": "Name", "icon": "label", "key": "name", "kind": "pet_name", "view": "pet", "colors": []},
		{"label": "Looks", "icon": "artist_palette", "key": "coat", "kind": "pet_looks", "view": "pet", "colors": []},
	]})
	return out


func _show_tab(i: int) -> void:
	_tab = clampi(i, 0, _tabs.size() - 1)
	for j in _tab_buttons.size():
		_tab_buttons[j].set_pressed_no_signal(j == _tab)
	for child in _part_row.get_children():
		child.free()
	var parts: Array = _tabs[_tab]["parts"]
	for j in parts.size():
		var chip := UiTheme.button(parts[j]["label"], parts[j]["icon"], &"ChipButton")
		chip.toggle_mode = true
		chip.custom_minimum_size.y = 44
		chip.pressed.connect(_show_part.bind(j))
		_part_row.add_child(chip)
	_part_row.visible = parts.size() > 1
	_show_part(0)


func _show_part(j: int) -> void:
	var parts: Array = _tabs[_tab]["parts"]
	_part = clampi(j, 0, parts.size() - 1)
	for k in _part_row.get_child_count():
		_part_row.get_child(k).set_pressed_no_signal(k == _part)
	var part: Dictionary = parts[_part]
	_view = part["view"] if CAMERA_DISTANCE.has(part["view"]) else "body"
	for child in _content.get_children():
		child.free()
	_option_grid = null
	match part["kind"]:
		"options":
			_add_option_grid(part)
		"slider":
			_add_height_slider()
		"pet_species":
			_add_pet_species()
		"pet_name":
			_add_pet_names()
		"pet_looks":
			_add_pet_looks()
	for row in part["colors"]:
		_add_color_row(row)
	if part["kind"] == "colors":
		_content.add_child(UiTheme.spacer())


## Every choice for one option key, each with a picture of you wearing it.
func _add_option_grid(part: Dictionary) -> void:
	var key: String = part["key"]
	var view: String = part["view"]
	_option_grid = _new_grid(CARD_SIZES)
	_option_grid.show_names = true
	_option_grid.select(str(int(_profile["avatar"].get(key, 0))))
	_option_grid.set_items(_option_items(key, view))
	_option_grid.chosen.connect(func(k): _set_avatar(key, int(k)))


## One card per choice, each showing you with that choice and your colors.
func _option_items(key: String, view: String) -> Array:
	var choices := AvatarBuilder.options(key)
	var items := []
	for i in choices.size():
		var config: Dictionary = _profile["avatar"].duplicate()
		config[key] = i
		var thumb_key := "avatar:%s:%s" % [view, JSON.stringify(config).md5_text()]
		items.append({"key": str(i), "name": str(choices[i]),
			"thumb": func(): return Thumbs.texture(thumb_key, func(): return AvatarBuilder.build(config), view)})
	return items


func _add_height_slider() -> void:
	var well := UiTheme.card(&"Well")
	_content.add_child(well)
	var row := UiTheme.hbox(12)
	well.add_child(row)
	row.add_child(UiTheme.texture_rect(UiTheme.icon("person_standing"), 32))
	var slider := HSlider.new()
	slider.min_value = 0.85
	slider.max_value = 1.15
	slider.step = 0.01
	slider.value = _profile["avatar"]["height"]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.y = 40
	slider.value_changed.connect(func(v): _set_avatar("height", v))
	row.add_child(slider)
	row.add_child(UiTheme.texture_rect(UiTheme.icon("person_standing"), 52))
	_content.add_child(UiTheme.spacer())


func _add_color_row(row: Dictionary, is_pet := false) -> void:
	_content.add_child(UiTheme.label(row["label"], &"Hint", 16))
	var target: Dictionary = _profile["pet"] if is_pet else _profile["avatar"]
	var palette := SwatchRow.new(row["colors"], str(target.get(row["key"], "")), true, row.get("original", false))
	palette.color_chosen.connect(func(hex):
		if is_pet:
			_set_pet(row["key"], hex)
		else:
			_set_avatar(row["key"], hex))
	_fit_swatches(palette)
	_content.add_child(palette)


## Shrinks a long row of swatches to fit one line where it can, which leaves
## the picture grid above room for a second row of cards.
func _fit_swatches(palette: SwatchRow) -> void:
	var width := _content.size.x if _content.size.x > 0.0 else 520.0
	var count := palette.get_child_count()
	var natural := float((count - 1) * palette.get_theme_constant("h_separation"))
	for swatch in palette.get_children():
		natural += swatch.custom_minimum_size.x
	if natural <= width:
		return
	var gap := 5
	var side := clampi(floori((width + gap) / count) - gap, 28, SwatchRow.SWATCH)
	palette.add_theme_constant_override("h_separation", gap)
	palette.add_theme_constant_override("v_separation", gap)
	for swatch in palette.get_children():
		swatch.custom_minimum_size = Vector2(swatch.custom_minimum_size.x if swatch.text != "" else side, side)
		if swatch.icon:
			swatch.add_theme_constant_override("icon_max_width", side - 10)


func _add_pet_species() -> void:
	var grid := _new_grid([Vector2(112, 130)])
	grid.show_names = true
	var pet: Dictionary = _profile["pet"]
	var items := []
	for i in PetBuilder.SPECIES.size():
		var config := PetBuilder.sanitize(pet.merged({"species": i, "coat": 0}, true))
		items.append({"key": str(i), "name": PetBuilder.SPECIES[i], "thumb": _pet_thumb.bind(config)})
	grid.select(str(int(pet["species"])))
	grid.set_items(items)
	grid.chosen.connect(func(k):
		_set_pet("species", int(k))
		_show_part(_part))


func _add_pet_names() -> void:
	var grid := _new_grid([Vector2(116, 52)])
	var items := []
	for pet_name in SafeNames.PET_NAMES:
		items.append({"key": pet_name, "name": pet_name})
	grid.select(_profile["pet"]["name"])
	grid.set_items(items)
	grid.chosen.connect(func(k): _set_pet("name", k))


## Pets with a model pick a coat; the shape-built ones pick colors.
func _add_pet_looks() -> void:
	var pet: Dictionary = _profile["pet"]
	if not PetBuilder.has_art(pet):
		for row in [["Fur or feathers", "color"], ["Belly and ears", "accent"], ["Collar", "collar"]]:
			_add_color_row({"label": row[0], "key": row[1], "colors": PET_COLORS}, true)
		_content.add_child(UiTheme.spacer())
		return
	var grid := _new_grid(CARD_SIZES)
	grid.show_names = true
	var names := PetBuilder.coat_names(pet)
	var items := []
	for i in names.size():
		var config := PetBuilder.sanitize(pet.merged({"coat": i}, true))
		items.append({"key": str(i), "name": names[i], "thumb": _pet_thumb.bind(config)})
	grid.select(str(int(pet["coat"])))
	grid.set_items(items)
	grid.chosen.connect(func(k): _set_pet("coat", int(k)))


func _pet_thumb(config: Dictionary) -> Texture2D:
	var cache := PetBuilder.has_art(config)
	return Thumbs.texture("pet:" + JSON.stringify(config), func(): return PetBuilder.build(config), "pet", cache)


func _new_grid(card_sizes: Array) -> ItemGrid:
	var grid := ItemGrid.new()
	grid.card_size = card_sizes[0]
	grid.card_sizes = card_sizes
	_content.add_child(grid)
	return grid


func _set_avatar(key: String, value: Variant) -> void:
	_profile["avatar"][key] = value
	_profile["avatar"] = AvatarBuilder.sanitize(_profile["avatar"])
	GameState.save_profile()
	_rebuild_preview()
	# The pictures of the choices show the new color too.
	var part: Dictionary = _tabs[_tab]["parts"][_part]
	if value is String and _option_grid:
		_option_grid.set_items(_option_items(part["key"], part["view"]), true)


func _set_pet(key: String, value: Variant) -> void:
	_profile["pet"][key] = value
	# Keeps the coat in range for the new species (the profile also holds needs).
	_profile["pet"]["coat"] = PetBuilder.sanitize(_profile["pet"])["coat"]
	GameState.save_profile()
	_rebuild_preview()


func _randomize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_profile["avatar"] = AvatarBuilder.random_config(rng)
	GameState.save_profile()
	_rebuild_preview()
	_show_part(_part)
