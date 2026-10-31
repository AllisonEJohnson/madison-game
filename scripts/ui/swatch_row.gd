class_name SwatchRow
extends HFlowContainer
## Round color swatches plus a rainbow button that opens a full color picker.
## The picked swatch gets a ring. With `original`, an "Original" chip first
## picks "", which keeps a model's own colors.

signal color_chosen(hex: String)

const SWATCH := 40

var _hex := ""
var _swatches := {} # hex -> Button
var _original: Button
var _picker: ColorPicker
var _popup: PopupPanel


func _init(palette: Array, current: String, custom := true, original := false) -> void:
	add_theme_constant_override("h_separation", 8)
	add_theme_constant_override("v_separation", 8)
	if original:
		_original = UiTheme.button("Original", "sparkles", &"ChipButton", "Keep its own colors")
		_original.toggle_mode = true
		_original.custom_minimum_size.y = SWATCH
		_original.pressed.connect(func(): _choose(""))
		add_child(_original)
	for hex_value in palette:
		var b := Button.new()
		b.custom_minimum_size = Vector2(SWATCH, SWATCH)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = "#" + hex_value
		b.pressed.connect(func(): _choose(hex_value))
		add_child(b)
		_swatches[Color.html(hex_value).to_html(false)] = b
	if custom:
		var more := UiTheme.button("", "rainbow", &"IconButton", "Pick any color")
		more.custom_minimum_size = Vector2(SWATCH + 8, SWATCH)
		more.add_theme_constant_override("icon_max_width", 26)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var s := UiTheme.box(Color.WHITE, SWATCH / 2, 2, UiTheme.LINE, Vector4(4, 2, 4, 2))
			if state != "normal":
				s.border_color = UiTheme.BLUE
			more.add_theme_stylebox_override(state, s)
		more.pressed.connect(_open_picker.bind(more))
		add_child(more)
	set_color(current)


## Shows `hex` as the current color without sending color_chosen.
func set_color(hex: String) -> void:
	_hex = Color.html(hex).to_html(false) if Color.html_is_valid(hex) else ""
	if _original:
		_original.set_pressed_no_signal(_hex == "")
	for key in _swatches:
		var b: Button = _swatches[key]
		var picked: bool = key == _hex
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			var s := UiTheme.box(Color.html(key), SWATCH / 2, 0, Color.TRANSPARENT, Vector4.ZERO)
			s.border_color = Color.WHITE if picked else Color(0, 0, 0, 0.12)
			s.set_border_width_all(4 if picked else (3 if state == "hover" else 2))
			if picked:
				# A white ring with a dark halo around it.
				s.expand_margin_left = 4
				s.expand_margin_right = 4
				s.expand_margin_top = 4
				s.expand_margin_bottom = 4
				s.shadow_color = UiTheme.INK
				s.shadow_size = 3
			b.add_theme_stylebox_override(state, s)


func _choose(hex: String) -> void:
	set_color(hex)
	color_chosen.emit(_hex)


func _open_picker(anchor: Control) -> void:
	if not _popup:
		_popup = PopupPanel.new()
		_picker = ColorPicker.new()
		_picker.edit_alpha = false
		_picker.presets_visible = false
		_picker.color_modes_visible = false
		_picker.sliders_visible = false
		_picker.hex_visible = false
		_picker.sampler_visible = false
		_picker.picker_shape = ColorPicker.SHAPE_VHS_CIRCLE
		_picker.color_changed.connect(func(c: Color):
			set_color(c.to_html(false))
			color_chosen.emit(_hex))
		_popup.add_child(_picker)
		add_child(_popup)
	if _hex != "":
		_picker.color = Color.html(_hex)
	var at := anchor.get_global_rect().position + Vector2(0, anchor.size.y + 6)
	_popup.popup(Rect2i(Vector2i(at), Vector2i.ZERO))
