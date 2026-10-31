extends Control
## Title screen and character creator. Everything is built in code.
## Left: name and play buttons. Middle: live 3D preview. Right: style tabs.

const CLOTH_COLORS := ["e04848", "f2994a", "f2c94c", "6fcf97", "2fa37a", "56ccf2", "3f7fd9",
		"9b51e0", "eb5f9a", "ffffff", "8a8a8a", "2f3550", "1f1f1f", "8d5b3a"]

var _profile: Dictionary
var _preview_root: Node3D
var _preview_camera: Camera3D
var _camera_target := Vector3(0, 1.0, 0)
var _camera_goal := Vector3(0.6, 1.15, 3.6)
var _preview_spin := 0.0
var _dragging := false
var _name_label: Label
var _message: Label
var _port: SpinBox
var _address: LineEdit
var _controls := {} # key -> control, to refresh after Randomize


func _ready() -> void:
	_profile = GameState.profile
	var bg := ColorRect.new()
	bg.color = Color("23304a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	row.add_child(_build_left_panel())
	row.add_child(_build_preview())
	row.add_child(_build_tabs())
	_rebuild_preview()

	_message.text = Net.menu_message
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
			get_tree().root.add_child(shot)
	for arg in args:
		if arg == "--host":
			_play()
		elif arg.begins_with("--join="):
			_address.text = arg.trim_prefix("--join=")
			_join()


# --- Left panel: name and play ---------------------------------------------

func _build_left_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 300
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Hometown Pals"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Style yourself, build a home,\nand bring your pet along!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	box.add_child(HSeparator.new())

	box.add_child(_heading("Your player name"))
	var parts: Dictionary = _profile["name_parts"]
	var adj := _option(SafeNames.NAME_ADJECTIVES, parts["adjective"], func(i): _set_name_part("adjective", i))
	var noun := _option(SafeNames.NAME_NOUNS, parts["noun"], func(i): _set_name_part("noun", i))
	var number := SpinBox.new()
	number.min_value = 0
	number.max_value = 99
	number.value = parts["number"]
	number.value_changed.connect(func(v): _set_name_part("number", int(v)))
	var name_row := HBoxContainer.new()
	name_row.add_child(adj)
	name_row.add_child(noun)
	name_row.add_child(number)
	box.add_child(name_row)
	_controls["name_adjective"] = adj
	_controls["name_noun"] = noun
	_controls["name_number"] = number
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 20)
	box.add_child(_name_label)
	_update_name_label()
	var safety := Label.new()
	safety.text = "Names are made from friendly words, and chat\nuses preset phrases, so everyone stays safe."
	safety.add_theme_font_size_override("font_size", 12)
	safety.modulate = Color(1, 1, 1, 0.7)
	box.add_child(safety)
	box.add_child(HSeparator.new())

	var randomize := Button.new()
	randomize.text = "Surprise me! (random style)"
	randomize.pressed.connect(_randomize)
	box.add_child(randomize)

	box.add_child(_heading("Play"))
	var play := Button.new()
	play.text = "Play (host a world)" if Net.online_available else "Play"
	play.custom_minimum_size.y = 44
	play.pressed.connect(_play)
	box.add_child(play)
	var port_row := HBoxContainer.new()
	port_row.visible = Net.online_available
	var port_label := Label.new()
	port_label.text = "Port"
	port_row.add_child(port_label)
	_port = SpinBox.new()
	_port.min_value = 1024
	_port.max_value = 65535
	_port.value = Net.DEFAULT_PORT
	_port.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port_row.add_child(_port)
	box.add_child(port_row)
	var join_row := HBoxContainer.new()
	join_row.visible = Net.online_available
	_address = LineEdit.new()
	_address.text = "127.0.0.1"
	_address.placeholder_text = "Host address"
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_address)
	var join := Button.new()
	join.text = "Join"
	join.pressed.connect(_join)
	join_row.add_child(join)
	box.add_child(join_row)
	if not Net.online_available:
		var solo := Label.new()
		solo.text = "In the browser, the neighborhood is just for you.\nPlaying with friends needs the downloaded game."
		solo.add_theme_font_size_override("font_size", 12)
		solo.modulate = Color(1, 1, 1, 0.7)
		box.add_child(solo)

	_message = Label.new()
	_message.modulate = Color("ffb3b3")
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_message)
	return panel


func _set_name_part(key: String, value: int) -> void:
	_profile["name_parts"][key] = value
	_update_name_label()
	GameState.save_profile()


func _update_name_label() -> void:
	_name_label.text = SafeNames.display_name(_profile["name_parts"])


func _play() -> void:
	GameState.save_profile()
	Net.request_host(int(_port.value))


func _join() -> void:
	GameState.save_profile()
	Net.request_join(_address.text.strip_edges(), int(_port.value))


# --- Preview ------------------------------------------------------------------

func _build_preview() -> Control:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.gui_input.connect(_on_preview_input)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	container.add_child(vp)

	var env := WorldEnvironment.new()
	var environment := Lighting.environment(false)
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("8ec5ff")
	env.environment = environment
	vp.add_child(env)
	var light := Lighting.sun()
	light.rotation_degrees = Vector3(-35, 30, 0)
	vp.add_child(light)
	var floor_node := Node3D.new()
	vp.add_child(floor_node)
	MeshUtil.cylinder(floor_node, 1.6, 1.6, 0.1, Color("7fc46a"), Vector3(0, -0.05, 0))

	_preview_root = Node3D.new()
	vp.add_child(_preview_root)
	_preview_camera = Camera3D.new()
	_preview_camera.fov = 40
	vp.add_child(_preview_camera)
	_preview_camera.position = _camera_goal
	return container


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_preview_spin += event.relative.x * 0.01


func _process(delta: float) -> void:
	if not _dragging:
		_preview_spin += delta * 0.3
	if _preview_root:
		var avatar := _preview_root.get_node_or_null("Avatar") as Node3D
		if avatar:
			avatar.rotation.y = sin(_preview_spin) * 0.6
	if _preview_camera:
		_preview_camera.position = _preview_camera.position.lerp(_camera_goal, minf(6.0 * delta, 1.0))
		_preview_camera.look_at(_camera_target)


func _focus_camera(on_face: bool) -> void:
	var h := float(_profile["avatar"]["height"])
	if on_face:
		_camera_target = Vector3(0, 1.58 * h, 0)
		_camera_goal = Vector3(0.15, 1.62 * h, 1.5)
	else:
		_camera_target = Vector3(0.2, 0.95, 0)
		_camera_goal = Vector3(0.7, 1.2, 4.0)


func _rebuild_preview() -> void:
	for child in _preview_root.get_children():
		child.free()
	var avatar := AvatarBuilder.build(_profile["avatar"])
	_preview_root.add_child(avatar)
	var pet := PetBuilder.build(_profile["pet"])
	pet.position = Vector3(0.9, 0, 0.4)
	pet.rotation_degrees.y = -30
	_preview_root.add_child(pet)


# --- Style tabs ---------------------------------------------------------------

func _build_tabs() -> Control:
	var tabs := TabContainer.new()
	tabs.custom_minimum_size.x = 360
	tabs.add_child(_tab("Face", [
		["Eyes", "eyes"], ["Eye color", "eye_color", AvatarBuilder.EYE_COLORS],
		["Eyebrows", "brows"], ["Nose", "nose"], ["Mouth", "mouth"], ["Cheeks", "cheeks"],
		["Glasses", "glasses"], ["Glasses color", "glasses_color", CLOTH_COLORS],
	]))
	tabs.add_child(_tab("Body & Hair", [
		["Skin tone", "skin", AvatarBuilder.SKIN_TONES], ["Height", "height"], ["Body", "build"],
		["Hair style", "hair"], ["Hair color", "hair_color", AvatarBuilder.HAIR_COLORS],
	]))
	tabs.add_child(_tab("Clothes", [
		["Top", "top"], ["Top color", "top_color", CLOTH_COLORS], ["Top detail color", "top_accent", CLOTH_COLORS],
		["Bottoms", "bottom"], ["Bottoms color", "bottom_color", CLOTH_COLORS],
		["Shoes", "shoes"], ["Shoe color", "shoe_color", CLOTH_COLORS],
	]))
	tabs.add_child(_tab("Extras", [
		["Hat & hair clips", "hat"], ["Hat color", "hat_color", CLOTH_COLORS],
		["On your back", "back"], ["Back item color", "back_color", CLOTH_COLORS],
	]))
	tabs.add_child(_pet_tab())
	tabs.tab_changed.connect(func(i): _focus_camera(i == 0))
	_focus_camera(true)
	return tabs


func _tab(title: String, rows: Array) -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	var avatar: Dictionary = _profile["avatar"]
	for row in rows:
		var key: String = row[1]
		box.add_child(_heading(row[0]))
		if row.size() > 2:
			box.add_child(_color_row(avatar, key, row[2]))
		elif key == "height":
			var slider := HSlider.new()
			slider.min_value = 0.85
			slider.max_value = 1.15
			slider.step = 0.01
			slider.value = avatar["height"]
			slider.value_changed.connect(func(v): _set_avatar("height", v))
			box.add_child(slider)
			_controls["avatar_height"] = slider
		else:
			var opt := _option(AvatarBuilder.OPTIONS[key], avatar[key], func(i): _set_avatar(key, i))
			box.add_child(opt)
			_controls["avatar_" + key] = opt
	return scroll


func _pet_tab() -> Control:
	var box := VBoxContainer.new()
	box.name = "Pet"
	box.add_theme_constant_override("separation", 6)
	var pet: Dictionary = _profile["pet"]
	box.add_child(_heading("Kind of pet"))
	box.add_child(_option(PetBuilder.SPECIES, pet["species"], func(i): _set_pet("species", i)))
	box.add_child(_heading("Pet name"))
	var names := _option(SafeNames.PET_NAMES, maxi(SafeNames.PET_NAMES.find(pet["name"]), 0),
			func(i): _set_pet("name", SafeNames.PET_NAMES[i]))
	box.add_child(names)
	for row in [["Fur / feather color", "color"], ["Belly & ear color", "accent"], ["Collar color", "collar"]]:
		box.add_child(_heading(row[0]))
		box.add_child(_color_row(pet, row[1], CLOTH_COLORS + ["e8a35a", "fff3e0", "c49a6c"], true))
	return box


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.modulate = Color("ffe9a8")
	return l


func _option(items: Array, selected: int, on_select: Callable) -> OptionButton:
	var opt := OptionButton.new()
	for item in items:
		opt.add_item(str(item))
	opt.select(clampi(selected, 0, items.size() - 1))
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.item_selected.connect(on_select)
	return opt


## A row of preset swatches plus a picker for any custom color.
func _color_row(target: Dictionary, key: String, palette: Array, is_pet := false) -> Control:
	var flow := HFlowContainer.new()
	var picker := ColorPickerButton.new()
	picker.edit_alpha = false
	picker.custom_minimum_size = Vector2(44, 26)
	picker.color = MeshUtil.hex(target[key])
	picker.tooltip_text = "Pick any color"
	for hex_value in palette:
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(26, 26)
		var style := StyleBoxFlat.new()
		style.bg_color = Color.html(hex_value)
		style.set_corner_radius_all(13)
		style.set_border_width_all(2)
		style.border_color = Color(1, 1, 1, 0.5)
		for state in ["normal", "hover", "pressed", "focus"]:
			swatch.add_theme_stylebox_override(state, style)
		swatch.pressed.connect(func():
			picker.color = Color.html(hex_value)
			_set_color(key, hex_value, is_pet))
		flow.add_child(swatch)
	picker.color_changed.connect(func(c): _set_color(key, c.to_html(false), is_pet))
	flow.add_child(picker)
	if not is_pet:
		_controls["color_" + key] = picker
	return flow


func _set_color(key: String, hex_value: String, is_pet: bool) -> void:
	if is_pet:
		_set_pet(key, hex_value)
	else:
		_set_avatar(key, hex_value)


func _set_avatar(key: String, value: Variant) -> void:
	_profile["avatar"][key] = value
	_profile["avatar"] = AvatarBuilder.sanitize(_profile["avatar"])
	GameState.save_profile()
	_rebuild_preview()


func _set_pet(key: String, value: Variant) -> void:
	_profile["pet"][key] = value
	GameState.save_profile()
	_rebuild_preview()


func _randomize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_profile["avatar"] = AvatarBuilder.random_config(rng)
	var avatar: Dictionary = _profile["avatar"]
	for key in AvatarBuilder.OPTIONS:
		if _controls.has("avatar_" + key):
			_controls["avatar_" + key].select(avatar[key])
	_controls["avatar_height"].set_value_no_signal(avatar["height"])
	for key in avatar:
		if _controls.has("color_" + key):
			_controls["color_" + key].color = MeshUtil.hex(avatar[key])
	GameState.save_profile()
	_rebuild_preview()
