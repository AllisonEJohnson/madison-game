class_name UiTheme
extends RefCounted
## The game's look for menus and the in-world interface: a rounded font,
## chunky buttons with a raised bottom edge, soft cream cards, and colorful
## icons. Screens apply `theme()` to their root and pick a look per control
## with `theme_type_variation` (for example &"PrimaryButton" or &"Card").
##
## Fonts: Fredoka for titles and buttons, Nunito for everything else (both
## SIL Open Font License, see assets/ui/fonts). Icons: Microsoft Fluent Emoji
## (MIT, see assets/ui/icons/LICENSE.txt), saved as 128 px PNGs.

const INK := Color("3b3552")
const INK_SOFT := Color("7d7694")
const PAPER := Color("fffaf2")
const PAPER_DIM := Color("f2eadc")
const LINE := Color("e3d8c6")
const GREEN := Color("35c26b")
const BLUE := Color("4b9cff")
const PINK := Color("ff6fa8")
const ORANGE := Color("ffa53c")
const PURPLE := Color("9b6bff")
const YELLOW := Color("ffcf3a")
const RED := Color("ff5a5f")
const SHADOW := Color(0.12, 0.08, 0.25, 0.28)

const ICON_DIR := "res://assets/ui/icons/"
const FALLBACK_ICON := "sparkles"

static var _theme: Theme
static var _fonts := {}
static var _icons := {}


## Nunito, or Fredoka when `display` is true, at a given weight (100-900).
static func font(weight := 700, display := false) -> Font:
	var key := "%s%d" % ["display" if display else "body", weight]
	if not _fonts.has(key):
		var f := FontVariation.new()
		f.base_font = load("res://assets/ui/fonts/%s.ttf" % ("Fredoka" if display else "Nunito"))
		var wght := TextServerManager.get_primary_interface().name_to_tag("wght")
		f.variation_opentype = {wght: weight}
		_fonts[key] = f
	return _fonts[key]


## A colorful icon by its file name in assets/ui/icons, such as "house".
static func icon(icon_name: String) -> Texture2D:
	if not _icons.has(icon_name):
		var path := ICON_DIR + icon_name + ".png"
		_icons[icon_name] = load(path) if ResourceLoader.exists(path) else null
		if _icons[icon_name] == null and icon_name != FALLBACK_ICON:
			_icons[icon_name] = icon(FALLBACK_ICON)
	return _icons[icon_name]


## An icon shrunk to `size` pixels, for places that draw icons at their own
## size (such as a text field's icon).
static func small_icon(icon_name: String, size: int) -> Texture2D:
	var key := "%s@%d" % [icon_name, size]
	if not _icons.has(key):
		var img := icon(icon_name).get_image()
		img.resize(size, size, Image.INTERPOLATE_LANCZOS)
		_icons[key] = ImageTexture.create_from_image(img)
	return _icons[key]


static func box(color: Color, radius := 18, border := 0, border_color := Color.TRANSPARENT,
		margin := Vector4(14, 10, 14, 10)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.content_margin_left = margin.x
	s.content_margin_top = margin.y
	s.content_margin_right = margin.z
	s.content_margin_bottom = margin.w
	s.anti_aliasing_size = 1.0
	return s


## A soft card with a drop shadow.
static func card_box(color := PAPER, radius := 26, pad := 18) -> StyleBoxFlat:
	var s := box(color, radius, 0, Color.TRANSPARENT, Vector4(pad, pad, pad, pad))
	s.shadow_color = SHADOW
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 5)
	return s


## Chunky button looks: a darker bottom edge that flattens when pressed.
static func _chunky(theme: Theme, type: StringName, color: Color, text: Color, radius := 18,
		pad := Vector4(18, 10, 18, 12)) -> void:
	var edge := color.darkened(0.22)
	var normal := box(color, radius, 0, edge, pad)
	normal.border_width_bottom = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.1)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.06)
	pressed.border_width_bottom = 2
	pressed.content_margin_top = pad.y + 4
	pressed.content_margin_bottom = pad.w - 4
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = color.lerp(Color("cfc8bd"), 0.7)
	disabled.border_color = disabled.bg_color.darkened(0.15)
	var focus := box(Color.TRANSPARENT, radius + 2, 3, BLUE.lightened(0.3))
	focus.draw_center = false
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	for pair in [["normal", normal], ["hover", hover], ["pressed", pressed], ["hover_pressed", pressed],
			["disabled", disabled], ["focus", focus]]:
		theme.set_stylebox(pair[0], type, pair[1])
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color",
			"font_focus_color"]:
		theme.set_color(state, type, text)
	theme.set_color("font_disabled_color", type, Color(text, 0.6))
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color",
			"icon_focus_color"]:
		theme.set_color(state, type, Color.WHITE)


## A toggle (tab, chip or card) that turns `on` color when picked.
static func _toggle(theme: Theme, type: StringName, off: Color, on: Color, radius: int, pad: Vector4,
		on_text := Color.WHITE, border := 0) -> void:
	var normal := box(off, radius, border, LINE, pad)
	var hover := box(off.lightened(0.5) if off.v < 0.98 else Color.WHITE, radius, maxi(border, 3), on.lightened(0.45), pad)
	var pressed := box(on, radius, border, on.darkened(0.2), pad)
	pressed.border_width_bottom = 4
	pressed.border_color = on.darkened(0.22)
	for pair in [["normal", normal], ["hover", hover], ["pressed", pressed], ["hover_pressed", pressed],
			["disabled", normal], ["focus", StyleBoxEmpty.new()]]:
		theme.set_stylebox(pair[0], type, pair[1])
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		theme.set_color(state, type, INK)
	theme.set_color("font_pressed_color", type, on_text)
	theme.set_color("font_hover_pressed_color", type, on_text)


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font(700)
	t.default_font_size = 18
	_theme = t

	# Labels
	t.set_color("font_color", "Label", INK)
	t.set_type_variation(&"Title", &"Label")
	t.set_font("font", &"Title", font(600, true))
	t.set_font_size("font_size", &"Title", 44)
	t.set_color("font_color", &"Title", Color.WHITE)
	t.set_color("font_outline_color", &"Title", Color("3b3552"))
	t.set_constant("outline_size", &"Title", 14)
	t.set_color("font_shadow_color", &"Title", Color(0.1, 0.05, 0.2, 0.35))
	t.set_constant("shadow_offset_y", &"Title", 5)
	t.set_type_variation(&"Heading", &"Label")
	t.set_font("font", &"Heading", font(600, true))
	t.set_font_size("font_size", &"Heading", 24)
	t.set_type_variation(&"Hint", &"Label")
	t.set_font("font", &"Hint", font(600))
	t.set_font_size("font_size", &"Hint", 15)
	t.set_color("font_color", &"Hint", INK_SOFT)
	# Text that floats over the 3D world.
	t.set_type_variation(&"WorldLabel", &"Label")
	t.set_color("font_color", &"WorldLabel", Color.WHITE)
	t.set_color("font_outline_color", &"WorldLabel", Color(0.1, 0.08, 0.2, 0.85))
	t.set_constant("outline_size", &"WorldLabel", 8)
	# Little keyboard hints such as "B".
	t.set_type_variation(&"KeyBadge", &"Label")
	t.set_font("font", &"KeyBadge", font(800))
	t.set_font_size("font_size", &"KeyBadge", 12)
	t.set_color("font_color", &"KeyBadge", Color.WHITE)
	t.set_stylebox("normal", &"KeyBadge", box(Color(INK, 0.85), 7, 0, Color.TRANSPARENT, Vector4(6, 1, 6, 2)))

	# Panels
	t.set_stylebox("panel", "PanelContainer", card_box())
	t.set_stylebox("panel", "Panel", card_box())
	t.set_type_variation(&"Card", &"PanelContainer")
	t.set_stylebox("panel", &"Card", card_box())
	t.set_type_variation(&"Well", &"PanelContainer")
	t.set_stylebox("panel", &"Well", box(PAPER_DIM, 18, 0, Color.TRANSPARENT, Vector4(10, 10, 10, 10)))
	t.set_type_variation(&"Bubble", &"PanelContainer")
	t.set_stylebox("panel", &"Bubble", box(Color(1, 1, 1, 0.92), 16, 0, Color.TRANSPARENT, Vector4(12, 6, 12, 7)))
	t.set_type_variation(&"Banner", &"PanelContainer")
	var banner := card_box(INK.darkened(0.1), 30, 0)
	banner.bg_color.a = 0.88
	banner.content_margin_left = 24
	banner.content_margin_right = 24
	banner.content_margin_top = 10
	banner.content_margin_bottom = 12
	t.set_stylebox("panel", &"Banner", banner)
	t.set_stylebox("panel", "PopupPanel", card_box(PAPER, 22, 14))
	t.set_stylebox("panel", "PopupMenu", card_box(PAPER, 18, 8))
	t.set_stylebox("panel", "TooltipPanel", box(INK, 10, 0, Color.TRANSPARENT, Vector4(10, 6, 10, 7)))
	t.set_color("font_color", "TooltipLabel", Color.WHITE)
	t.set_font("font", "TooltipLabel", font(700))
	t.set_font_size("font_size", "TooltipLabel", 15)

	# Buttons
	t.set_font("font", "Button", font(600, true))
	t.set_font_size("font_size", "Button", 20)
	t.set_constant("h_separation", "Button", 10)
	t.set_constant("icon_max_width", "Button", 36)
	_chunky(t, &"Button", Color.WHITE, INK)
	for v in [[&"PrimaryButton", GREEN], [&"BlueButton", BLUE], [&"PinkButton", PINK],
			[&"OrangeButton", ORANGE], [&"PurpleButton", PURPLE], [&"DangerButton", RED]]:
		t.set_type_variation(v[0], &"Button")
		_chunky(t, v[0], v[1], Color.WHITE)
	t.set_font_size("font_size", &"PrimaryButton", 28)
	t.set_constant("icon_max_width", &"PrimaryButton", 44)
	# Round icon-only buttons.
	t.set_type_variation(&"IconButton", &"Button")
	_chunky(t, &"IconButton", Color.WHITE, INK, 22, Vector4(10, 8, 10, 10))
	t.set_constant("icon_max_width", &"IconButton", 44)
	# Big tabs, small chips, and picture cards in a grid.
	t.set_type_variation(&"TabButton", &"Button")
	_toggle(t, &"TabButton", PAPER_DIM, BLUE, 18, Vector4(8, 8, 8, 8))
	t.set_font_size("font_size", &"TabButton", 15)
	t.set_constant("icon_max_width", &"TabButton", 40)
	t.set_type_variation(&"ChipButton", &"Button")
	_toggle(t, &"ChipButton", Color.WHITE, PURPLE, 20, Vector4(12, 6, 14, 8), Color.WHITE, 2)
	t.set_font("font", &"ChipButton", font(800))
	t.set_font_size("font_size", &"ChipButton", 16)
	t.set_constant("icon_max_width", &"ChipButton", 26)
	t.set_type_variation(&"CardButton", &"Button")
	_toggle(t, &"CardButton", Color.WHITE, BLUE, 18, Vector4(6, 6, 6, 6), Color.WHITE, 2)
	var picked := box(Color("e8f2ff"), 18, 4, BLUE, Vector4(6, 6, 6, 6))
	t.set_stylebox("pressed", &"CardButton", picked)
	t.set_stylebox("hover_pressed", &"CardButton", picked)
	t.set_color("font_pressed_color", &"CardButton", INK)
	t.set_color("font_hover_pressed_color", &"CardButton", INK)
	t.set_font("font", &"CardButton", font(700))
	t.set_font_size("font_size", &"CardButton", 14)
	t.set_type_variation(&"FlatButton", &"Button")
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		t.set_stylebox(state, &"FlatButton", StyleBoxEmpty.new())
	t.set_color("icon_hover_color", &"FlatButton", Color(1.15, 1.15, 1.15))

	# Inputs
	var field := box(Color.WHITE, 16, 2, LINE, Vector4(14, 8, 14, 8))
	var field_focus := box(Color.WHITE, 16, 3, BLUE, Vector4(14, 8, 14, 8))
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_stylebox("read_only", "LineEdit", field)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", INK_SOFT)
	t.set_color("caret_color", "LineEdit", BLUE)
	t.set_color("selection_color", "LineEdit", Color(BLUE, 0.3))
	t.set_stylebox("normal", "SpinBox", field)

	# Bars and sliders
	t.set_stylebox("background", "ProgressBar", box(Color(INK, 0.12), 8, 0, Color.TRANSPARENT, Vector4.ZERO))
	t.set_stylebox("fill", "ProgressBar", box(GREEN, 8, 0, Color.TRANSPARENT, Vector4.ZERO))
	var track := box(PAPER_DIM, 8, 0, Color.TRANSPARENT, Vector4(0, 6, 0, 6))
	t.set_stylebox("slider", "HSlider", track)
	var fill := box(BLUE, 8, 0, Color.TRANSPARENT, Vector4(0, 6, 0, 6))
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _dot_texture(30, BLUE))
	t.set_icon("grabber_highlight", "HSlider", _dot_texture(34, BLUE.lightened(0.15)))

	# Thick, rounded scroll bars that are easy to grab.
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, box(Color(INK, 0.06), 8, 0, Color.TRANSPARENT, Vector4(4, 4, 4, 4)))
		t.set_stylebox("grabber", bar, box(Color(INK, 0.3), 8, 0, Color.TRANSPARENT, Vector4(5, 5, 5, 5)))
		t.set_stylebox("grabber_highlight", bar, box(Color(INK, 0.45), 8, 0, Color.TRANSPARENT, Vector4(5, 5, 5, 5)))
		t.set_stylebox("grabber_pressed", bar, box(BLUE, 8, 0, Color.TRANSPARENT, Vector4(5, 5, 5, 5)))
	return t


## A white "play" triangle with rounded edges.
static func play_icon() -> Texture2D:
	if not _icons.has("@play"):
		var size := 64
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var tri := PackedVector2Array([Vector2(16, 10), Vector2(54, 32), Vector2(16, 54)])
		# Everything within 4 px of the triangle, which rounds its corners.
		for y in size:
			for x in size:
				var p := Vector2(x + 0.5, y + 0.5)
				var inside := Geometry2D.is_point_in_polygon(p, tri)
				var a := 1.0 if inside else clampf(5.0 - _distance_to_polygon(p, tri), 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_icons["@play"] = ImageTexture.create_from_image(img)
	return _icons["@play"]


static func _distance_to_polygon(p: Vector2, poly: PackedVector2Array) -> float:
	var best := INF
	for i in poly.size():
		var closest := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		best = minf(best, p.distance_to(closest))
	return best


## A filled circle, used for slider grabbers.
static func _dot_texture(size: int, color: Color) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var col := Color.WHITE if d < size / 2.0 - 4.0 else color
			col.a = clampf(size / 2.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


# --- Small builders shared by every screen --------------------------------------

static func label(text: String, variation := &"", size := 0, color := Color.TRANSPARENT) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	return l


## A button with an icon and optional text. Buttons never take keyboard focus,
## so the arrow keys and space keep moving the player.
static func button(text: String, icon_name := "", variation := &"", tooltip := "") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tooltip
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if icon_name != "":
		b.icon = icon(icon_name)
		# Icon-only buttons scale their icon to fit; with text, the theme's
		# icon_max_width sets its size so long words can't squeeze it.
		b.expand_icon = text == ""
	return b


## A square icon button with a tooltip, plus a keyboard hint in its corner.
static func icon_button(icon_name: String, tooltip: String, size := 64, key := "",
		variation := &"IconButton") -> Button:
	var b := button("", icon_name, variation, tooltip)
	b.custom_minimum_size = Vector2(size, size)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if key != "":
		add_key_badge(b, key)
	return b


## Badges hide while playing by touch (see TouchInput).
static func add_key_badge(control: Control, key: String) -> void:
	var badge := label(key, &"KeyBadge")
	badge.add_to_group(&"key_badges")
	badge.visible = not TouchInput.active
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.position = Vector2(4, -6)
	control.add_child(badge)


## An icon above a short caption, for docks and big tab rows.
static func stacked_button(text: String, icon_name: String, variation := &"TabButton", icon_size := 40,
		tooltip := "") -> Button:
	var b := button(text, icon_name, variation, tooltip)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_constant_override("icon_max_width", icon_size)
	return b


static func card(variation := &"Card") -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	return p


static func hbox(separation := 10) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	return b


static func vbox(separation := 10) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	return b


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func texture_rect(tex: Texture2D, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
