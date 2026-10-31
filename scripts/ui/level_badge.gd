class_name LevelBadge
extends HBoxContainer
## Your level on the player card: a star with the level number, an XP bar
## that fills as you play, and a "+3 XP" that pops up when you earn some.
## A lightning bolt shows while a Star Boost doubles your XP. Tap it to see
## what the next levels bring.

signal pressed

const BAR_WIDTH := 112.0
const GOLD := Color("ffbf1f")

var _number: Label
var _bar: ProgressBar
var _boost: TextureRect
var _gain: Label
var _gain_tween: Tween
var _fill_tween: Tween


func _init() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Your level. Tap to see what's next!"
	add_child(star(26.0, 13))
	_number = get_child(0).get_child(1)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(BAR_WIDTH, 12)
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.add_theme_stylebox_override("background", UiTheme.box(Color("ebe3f7"), 6, 0, Color.TRANSPARENT, Vector4.ZERO))
	_bar.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.PURPLE, 6, 0, Color.TRANSPARENT, Vector4.ZERO))
	_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_bar)
	_boost = UiTheme.texture_rect(UiTheme.icon("high_voltage"), 20)
	_boost.tooltip_text = "Star Boost: double XP!"
	_boost.mouse_filter = Control.MOUSE_FILTER_PASS
	_boost.visible = false
	add_child(_boost)
	# Shows on top of the bar, so it never widens the card or covers the wallet.
	_gain = UiTheme.label("", &"Heading", 15, Color.WHITE)
	_gain.add_theme_color_override("font_outline_color", UiTheme.PURPLE.darkened(0.2))
	_gain.add_theme_constant_override("outline_size", 6)
	_gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gain.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gain.offset_top = -8
	_gain.offset_bottom = 8
	_gain.modulate.a = 0.0
	_gain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(_gain)
	gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit())


func _ready() -> void:
	Progress.xp_changed.connect(_on_xp_changed)
	refresh(false)


## A gold star with a number on it, `size` pixels across. Its second child
## is the number's Label.
static func star(size: float, font_size: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size, size)
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon := UiTheme.texture_rect(UiTheme.icon("star"), size)
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.add_child(icon)
	var number := UiTheme.label("1", &"Heading", font_size, Color.WHITE)
	number.add_theme_color_override("font_outline_color", Color("b86e00"))
	number.add_theme_constant_override("outline_size", maxi(4, font_size / 3))
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Stars are drawn a little low in their square; lift the number to the middle.
	number.offset_top = size * 0.06
	number.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.add_child(number)
	return holder


func refresh(animate := true) -> void:
	var p := Progress.progress()
	_number.text = str(p["level"])
	var value := 1.0 if int(p["need"]) == 0 else float(p["into"]) / float(p["need"])
	if _fill_tween:
		_fill_tween.kill()
	_bar.max_value = 1.0
	_bar.step = 0.0
	if animate and value >= _bar.value:
		_fill_tween = create_tween()
		_fill_tween.tween_property(_bar, "value", value, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_bar.value = value
	_bar.tooltip_text = "Top level!" if int(p["need"]) == 0 else "%d of %d XP to level %d" % [p["into"], p["need"],
			int(p["level"]) + 1]
	_boost.visible = Progress.boost_seconds_left() > 0


func _on_xp_changed(gained: int) -> void:
	refresh()
	if gained <= 0:
		return
	_gain.text = "+%d XP" % gained
	if _gain_tween:
		_gain_tween.kill()
	_gain.modulate.a = 1.0
	_gain_tween = create_tween()
	_gain_tween.tween_interval(0.9)
	_gain_tween.tween_property(_gain, "modulate:a", 0.0, 0.6)


func _process(_delta: float) -> void:
	# The boost runs out on its own, without an XP change to say so.
	if _boost.visible and Progress.boost_seconds_left() <= 0:
		_boost.visible = false
