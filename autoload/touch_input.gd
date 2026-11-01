extends Node
## Touch screens. Says whether touch controls should show (`active`), and
## smooths over what phones need:
##
## - Touch mode is on from the start on phones and tablets. On any other screen
##   it turns on with the first touch (say, a touch-screen laptop), and a key
##   press turns it off again, so what's on screen matches how you're playing.
##   Key badges hide while it's on.
## - A phone held upright gets a card asking to turn it sideways, because the
##   game's windows are made for a wide screen (it can be waved away).
## - `fill_screen()` makes the game fill the screen and stay sideways, where
##   the browser allows it (Android does; iPhones don't).

signal mode_changed(on: bool)

## How far a finger can move, in screen points, and still count as a tap.
const TAP_POINTS := 12.0
## Screens narrower than this on their short side, in points, are phones.
const PHONE_POINTS := 600.0

var active := false

var _turn_layer: CanvasLayer
var _turn_root: Control
var _turn_icon: TextureRect
var _turn_dismissed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	active = _starts_on()
	get_tree().root.size_changed.connect(_update_turn_card)
	_update_turn_card.call_deferred()


func _starts_on() -> bool:
	var args := OS.get_cmdline_user_args()
	if "--touch" in args:
		return true
	if not DisplayServer.is_touchscreen_available():
		return false
	# iPads say they're Macs, but Macs don't have touch screens.
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") \
			or OS.has_feature("web_macos")


func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	get_tree().call_group("key_badges", "set_visible", not on)
	_update_turn_card()
	mode_changed.emit(on)


## Screen points (CSS pixels in a browser) per unit of the game's 2D layout.
## Touch controls use it to stay the size of a thumb on any screen.
func points_per_unit() -> float:
	var layout := get_viewport().get_visible_rect().size.y
	return float(get_window().size.y) / maxf(layout, 1.0) / maxf(DisplayServer.screen_get_scale(), 1.0)


## The window's size in screen points.
func screen_points() -> Vector2:
	return Vector2(get_window().size) / maxf(DisplayServer.screen_get_scale(), 1.0)


## How far a finger may move and still tap, in layout units.
func tap_slop() -> float:
	return TAP_POINTS / points_per_unit()


## Fills the screen and turns it sideways, on touch screens in a browser that
## allows it. Call it from a button press: browsers only allow it right after one.
func fill_screen() -> void:
	if not active or not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""(function () {
		var root = document.documentElement;
		if (document.fullscreenElement || !root.requestFullscreen) return;
		root.requestFullscreen({navigationUI: 'hide'}).then(function () {
			if (screen.orientation && screen.orientation.lock) screen.orientation.lock('landscape').catch(function () {});
		}).catch(function () {});
	})()""", true)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		set_active(true)
	elif event is InputEventKey and event.pressed and not event.echo and active:
		# Typing in a text box (with a phone's own keyboard) isn't a switch to keys.
		var focus := get_viewport().gui_get_focus_owner()
		if not (focus is LineEdit or focus is TextEdit):
			set_active(false)


# --- "Turn your phone sideways" ---------------------------------------------------

func _update_turn_card() -> void:
	var pts := screen_points()
	var upright_phone := active and pts.y > pts.x and pts.x < PHONE_POINTS
	var show := upright_phone and not _turn_dismissed
	if show and _turn_layer == null:
		_build_turn_card()
	if _turn_layer:
		_turn_layer.visible = show
		if show:
			_fit_turn_card()


func _build_turn_card() -> void:
	_turn_layer = CanvasLayer.new()
	_turn_layer.layer = 100
	add_child(_turn_layer)
	_turn_root = Control.new()
	_turn_root.theme = UiTheme.theme()
	_turn_layer.add_child(_turn_root)
	var scrim := ColorRect.new()
	scrim.color = Color(0.1, 0.07, 0.2, 0.82)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_turn_root.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_turn_root.add_child(center)
	var card := UiTheme.card()
	center.add_child(card)
	var box := UiTheme.vbox(14)
	box.custom_minimum_size.x = 420
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(box)
	# The phone tips over onto its side, again and again.
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(120, 120)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(holder)
	_turn_icon = UiTheme.texture_rect(UiTheme.icon("mobile_phone"), 110)
	_turn_icon.position = Vector2(5, 5)
	_turn_icon.pivot_offset = Vector2(55, 55)
	holder.add_child(_turn_icon)
	var tween := _turn_icon.create_tween().set_loops()
	tween.tween_interval(0.6)
	tween.tween_property(_turn_icon, "rotation", -PI / 2, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.2)
	tween.tween_property(_turn_icon, "rotation", 0.0, 0.4)
	var title := UiTheme.label("Turn your phone sideways!", &"Heading", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var text := UiTheme.label("Hometown Pals fits your screen best that way.", &"Hint", 18)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	var keep := UiTheme.button("Play this way", "", &"", "Keep playing with your phone upright")
	keep.custom_minimum_size = Vector2(220, 56)
	keep.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	keep.add_theme_font_size_override("font_size", 20)
	keep.pressed.connect(func():
		_turn_dismissed = true
		_update_turn_card())
	box.add_child(keep)


## An upright phone squeezes the wide layout into a narrow screen, so this
## card is scaled up to stay readable: about 330 points wide.
func _fit_turn_card() -> void:
	var view := get_viewport().get_visible_rect().size
	var grow := clampf(330.0 / (460.0 * points_per_unit()), 1.0, 4.0)
	_turn_layer.scale = Vector2(grow, grow)
	_turn_root.position = Vector2.ZERO
	_turn_root.size = view / grow
