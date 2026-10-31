class_name Hud
extends CanvasLayer
## In-world interface: your name card with your wallet, your pet's card with
## Feed and Play buttons, a dock of big actions (chat, decorate, shop, home,
## help, leave), chat bubbles, build mode's catalog, the shop, the card that
## offers a nearby shop or game, and Star Chase's timer. Every action also has
## a key, shown on its button, so the keyboard and the mouse both work.

signal phrase_chosen(index: int)
signal entry_chosen(id: String, style: int)
signal color_changed(color: Color)
signal style_stepped(step: int)
signal rotate_pressed
signal erase_toggled(on: bool)
signal build_toggled
signal home_pressed
signal pet_action(feed: bool)
signal leave_confirmed
## The button on the "nearby" card (or E) was pressed.
signal zone_used
## Shop buttons: place a bought piece, or put on bought clothes.
signal shop_decorate(id: String, style: int)
signal shop_wear(option: String, index: int)
signal chase_again

## Icons for the preset chat phrases (see SafeNames.CHAT_PHRASES).
const PHRASE_ICONS := {
	"Hi!": "waving_hand", "Bye!": "waving_hand", "Nice house!": "house_with_garden",
	"I love your pet!": "red_heart", "Want to be friends?": "hugging_face", "Follow me!": "footprints",
	"Come visit my house!": "house", "Cool outfit!": "t-shirt", "Thank you!": "smiling_face_with_hearts",
	"Yes!": "check_mark_button", "No thanks!": "cross_mark", "Good game!": "trophy",
	"Let's explore!": "compass", "Wait for me!": "stopwatch", "Haha!": "grinning_squinting_face",
	"Wow!": "star-struck",
}
const HELP := [
	["W A S D", "footprints", "Walk around"], ["Space", "sparkles", "Jump"],
	["Right-drag", "eye", "Look around"], ["Wheel", "magnifying_glass_tilted_left", "Zoom in and out"],
	["F", "meat_on_bone", "Feed your pet"], ["G", "tennis", "Play with your pet"],
	["T", "speech_balloon", "Say something"], ["B", "couch_and_lamp", "Decorate your home"],
	["H", "house", "Go to your home"], ["E", "shopping_bags", "Use a shop or game nearby"],
	["Walk", "chestnut", "Pick up acorns to spend"], ["Esc", "door", "Leave"],
]
## Paints for furniture made from shapes (pieces without model styles).
const HOUSE_COLORS := ["f1e7d6", "ffffff", "f7d9c4", "ffe8a3", "cdeac0", "bfe0f5", "d9c8f0", "f5c6d6",
		"c9a77c", "9a6b42", "6b4a32", "b8b2a7", "3f4a5a", "e07a5f", "6fa8dc"]
const CHAT_LINES := 6
const CHAT_FADE := 30.0

var _root: Control
var _scrim: ColorRect
var _player_card: PanelContainer
var _player_pic: TextureRect
var _player_name: Label
var _status: Label
var _wallet_labels := {} # currency -> Label
var _member_badge: Control
var _pet_card: PanelContainer
var _pet_pic: TextureRect
var _pet_name: Label
var _pet_kind: Label
var _fullness: ProgressBar
var _happiness: ProgressBar
var _dock: PanelContainer
var _chat_box: VBoxContainer
var _toast: PanelContainer
var _toast_label: Label
var _toast_time := 0.0
var _phrases: PanelContainer
var _help: PanelContainer
var _leave: PanelContainer
var _build_bar: PanelContainer
var _drawer: PanelContainer
## Shown instead of the drawer while it is tucked away.
var _peek: PanelContainer
var _tucked := false
var _browser: CatalogBrowser
var _pick_pic: TextureRect
var _pick_name: Label
var _look_row: HBoxContainer
var _look_label: Label
var _paint: VBoxContainer
var _palette: SwatchRow
var _erase: Button
var _buy_row: HBoxContainer
var _buy_button: Button
var _tools: HBoxContainer
var _entries := {} # key -> entry
var _shop: ShopPanel
var _prompt: PanelContainer
var _prompt_icon: TextureRect
var _prompt_title: Label
var _prompt_hint: Label
var _prompt_button: Button
var _game_bar: PanelContainer
var _game_label: Label
var _game_time: Label
var _result: PanelContainer
var _result_stars: Label
var _result_reward: Label
var _result_best: Control
var _gain: Label
var _gain_tween: Tween
## Kept for the smoke test, which prints the chat.
var _chat_lines: Array[String] = []


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.theme()
	add_child(_root)
	_build_player_card()
	_build_pet_card()
	_build_dock()
	_build_chat()
	_build_toast()
	# Dims the world behind a centered card; a click on it closes the card.
	_scrim = ColorRect.new()
	_scrim.color = Color(0.1, 0.07, 0.2, 0.35)
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.visible = false
	_scrim.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			close_popups())
	_root.add_child(_scrim)
	_phrases = _build_phrases()
	_help = _build_help()
	_leave = _build_leave()
	_result = _build_result()
	_build_shop()
	_build_prompt()
	_build_game_bar()
	_build_build_mode()
	GameState.earned.connect(_on_earned)
	GameState.owned_changed.connect(_refresh_prices)


# --- Cards ---------------------------------------------------------------------

func _build_player_card() -> void:
	_player_card = _place(UiTheme.card(), Control.PRESET_TOP_LEFT, Vector2(14, 14))
	var row := UiTheme.hbox(12)
	_player_card.add_child(row)
	_player_pic = _portrait(row)
	var words := UiTheme.vbox(0)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(words)
	_player_name = UiTheme.label("", &"Heading", 21)
	words.add_child(_player_name)
	_status = UiTheme.label("", &"Hint", 14)
	words.add_child(_status)
	# Balances of both currencies, and a crown while the membership lasts.
	var wallet := UiTheme.hbox(6)
	words.add_child(wallet)
	for currency in GameState.CURRENCIES:
		var info: Dictionary = GameState.CURRENCIES[currency]
		var icon := UiTheme.texture_rect(UiTheme.icon(info["icon"]), 24)
		icon.tooltip_text = info["name"]
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		wallet.add_child(icon)
		var amount := UiTheme.label("0", &"", 17)
		amount.tooltip_text = info["name"]
		amount.mouse_filter = Control.MOUSE_FILTER_PASS
		amount.custom_minimum_size.x = 34
		wallet.add_child(amount)
		_wallet_labels[currency] = amount
	_member_badge = UiTheme.texture_rect(UiTheme.icon("crown"), 24)
	_member_badge.mouse_filter = Control.MOUSE_FILTER_PASS
	_member_badge.visible = false
	wallet.add_child(_member_badge)
	# "+5" flies up beside the wallet when you earn something.
	_gain = UiTheme.label("", &"Heading", 20, Color("b8741a"))
	_gain.add_theme_color_override("font_outline_color", Color.WHITE)
	_gain.add_theme_constant_override("outline_size", 6)
	_gain.modulate.a = 0.0
	wallet.add_child(_gain)
	# Tapping the wallet opens the shop.
	wallet.mouse_filter = Control.MOUSE_FILTER_STOP
	wallet.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	wallet.tooltip_text = "Open the shop"
	wallet.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			open_shop())
	set_wallet()


func _build_pet_card() -> void:
	_pet_card = _place(UiTheme.card(), Control.PRESET_TOP_RIGHT, Vector2(-14, 14))
	var box := UiTheme.vbox(8)
	box.custom_minimum_size.x = 250
	_pet_card.add_child(box)
	var top := UiTheme.hbox(12)
	box.add_child(top)
	_pet_pic = _portrait(top)
	var words := UiTheme.vbox(0)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(words)
	_pet_name = UiTheme.label("", &"Heading", 21)
	words.add_child(_pet_name)
	_pet_kind = UiTheme.label("", &"Hint", 14)
	words.add_child(_pet_kind)
	_fullness = _need_bar(box, "meat_on_bone", "Fullness", UiTheme.ORANGE)
	_happiness = _need_bar(box, "red_heart", "Happiness", UiTheme.PINK)
	var buttons := UiTheme.hbox(8)
	box.add_child(buttons)
	for pair in [[true, "Feed", "meat_on_bone", &"OrangeButton", "F"], [false, "Play", "tennis", &"PinkButton", "G"]]:
		var b := UiTheme.button(pair[1], pair[2], pair[3], "%s your pet" % pair[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 50
		b.add_theme_constant_override("icon_max_width", 28)
		b.pressed.connect(func(): pet_action.emit(pair[0]))
		UiTheme.add_key_badge(b, pair[4])
		buttons.add_child(b)


func _need_bar(parent: Control, icon_name: String, tooltip: String, color: Color) -> ProgressBar:
	var row := UiTheme.hbox(8)
	row.tooltip_text = tooltip
	parent.add_child(row)
	row.add_child(UiTheme.texture_rect(UiTheme.icon(icon_name), 26))
	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size.y = 16
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("fill", UiTheme.box(color, 8, 0, Color.TRANSPARENT, Vector4.ZERO))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	return bar


func _portrait(parent: Control) -> TextureRect:
	var well := UiTheme.card(&"Well")
	well.add_theme_stylebox_override("panel", UiTheme.box(Color("dcefff"), 18, 0, Color.TRANSPARENT,
			Vector4(2, 2, 2, 2)))
	parent.add_child(well)
	var pic := UiTheme.texture_rect(null, 60)
	well.add_child(pic)
	return pic


# --- Dock, chat and notices ------------------------------------------------------

func _build_dock() -> void:
	_dock = _place(UiTheme.card(), Control.PRESET_CENTER_BOTTOM, Vector2(0, -14))
	_dock.add_theme_stylebox_override("panel", UiTheme.card_box(UiTheme.PAPER, 30, 12))
	var row := UiTheme.hbox(10)
	_dock.add_child(row)
	var actions := [
		["Chat", "speech_balloon", "T", open_quick_chat],
		["Decorate", "couch_and_lamp", "B", func(): build_toggled.emit()],
		["Shop", "shopping_bags", "", func(): open_shop()],
		["Home", "house", "H", func(): home_pressed.emit()],
		["Help", "red_question_mark", "", func(): _show_only(_help)],
		["Leave", "door", "Esc", ask_leave],
	]
	for a in actions:
		var b := UiTheme.stacked_button(a[0], a[1], &"Button", 40)
		b.custom_minimum_size = Vector2(104, 84)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(a[3])
		if a[2] != "":
			UiTheme.add_key_badge(b, a[2])
		row.add_child(b)


func _build_chat() -> void:
	_chat_box = UiTheme.vbox(6)
	_chat_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_chat_box.position = Vector2(14, -120)
	_chat_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_chat_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_chat_box)


func _build_toast() -> void:
	_toast = _place(UiTheme.card(&"Banner"), Control.PRESET_CENTER_TOP, Vector2(0, 110))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = UiTheme.label("", &"Heading", 21, Color.WHITE)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)
	_toast.visible = false


## A card in the middle of the screen with a title and a close button.
func _dialog(title: String, icon_name: String, closable := true) -> VBoxContainer:
	var card := _place(UiTheme.card(), Control.PRESET_CENTER, Vector2.ZERO)
	card.visible = false
	var box := UiTheme.vbox(14)
	card.add_child(box)
	var head := UiTheme.hbox(10)
	box.add_child(head)
	head.add_child(UiTheme.texture_rect(UiTheme.icon(icon_name), 40))
	var label := UiTheme.label(title, &"Heading", 26)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(label)
	if closable:
		var close := UiTheme.icon_button("cross_mark", "Close", 44)
		close.add_theme_constant_override("icon_max_width", 22)
		close.pressed.connect(func(): _show_only(null))
		head.add_child(close)
	return box


func _build_phrases() -> PanelContainer:
	var box := _dialog("Say something!", "speech_balloon")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for i in SafeNames.CHAT_PHRASES.size():
		var text: String = SafeNames.CHAT_PHRASES[i]
		var b := UiTheme.button(text, PHRASE_ICONS.get(text, "speech_balloon"))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(200, 54)
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_constant_override("icon_max_width", 28)
		b.pressed.connect(func():
			_show_only(null)
			phrase_chosen.emit(i))
		grid.add_child(b)
	var hint := UiTheme.label("Everyone sees these friendly phrases. Press T to open this any time.", &"Hint")
	box.add_child(hint)
	return box.get_parent()


func _build_help() -> PanelContainer:
	var box := _dialog("How to play", "red_question_mark")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for row in HELP:
		var line := UiTheme.hbox(10)
		line.custom_minimum_size.x = 300
		var key := UiTheme.label(row[0], &"KeyBadge", 15)
		key.custom_minimum_size.x = 96
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(key)
		line.add_child(UiTheme.texture_rect(UiTheme.icon(row[1]), 30))
		line.add_child(UiTheme.label(row[2]))
		grid.add_child(line)
	var ok := UiTheme.button("Got it!", "thumbs_up", &"PrimaryButton")
	ok.add_theme_font_size_override("font_size", 22)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func(): _show_only(null))
	box.add_child(ok)
	return box.get_parent()


func _build_leave() -> PanelContainer:
	var box := _dialog("Leave the neighborhood?", "door", false)
	box.add_child(UiTheme.label("Your home and your pet are saved for next time."))
	var row := UiTheme.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var stay := UiTheme.button("Stay", "house")
	stay.custom_minimum_size = Vector2(150, 56)
	stay.pressed.connect(func(): _show_only(null))
	row.add_child(stay)
	var go := UiTheme.button("Leave", "door", &"DangerButton")
	go.custom_minimum_size = Vector2(150, 56)
	go.pressed.connect(func(): leave_confirmed.emit())
	row.add_child(go)
	return box.get_parent()


# --- Shop, nearby things and Star Chase ---------------------------------------

func _build_shop() -> void:
	_shop = _place(ShopPanel.new(), Control.PRESET_CENTER, Vector2.ZERO)
	_shop.visible = false
	_shop.closed.connect(func(): _show_only(null))
	_shop.decorate.connect(func(id, style):
		_show_only(null)
		shop_decorate.emit(id, style))
	_shop.wear.connect(func(option, index): shop_wear.emit(option, index))
	_shop.stardust_info.connect(func():
		toast("The Stardust store is coming soon! A grown-up will help you get Stardust there."))


## A card above the dock that offers what's nearby, like a shop or a game.
func _build_prompt() -> void:
	_prompt = _place(UiTheme.card(), Control.PRESET_CENTER_BOTTOM, Vector2(0, -124))
	_prompt.add_theme_stylebox_override("panel", UiTheme.card_box(UiTheme.PAPER, 26, 12))
	_prompt.visible = false
	var row := UiTheme.hbox(12)
	_prompt.add_child(row)
	_prompt_icon = UiTheme.texture_rect(null, 46)
	row.add_child(_prompt_icon)
	var words := UiTheme.vbox(0)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(words)
	_prompt_title = UiTheme.label("", &"Heading", 22)
	words.add_child(_prompt_title)
	_prompt_hint = UiTheme.label("", &"Hint", 15)
	words.add_child(_prompt_hint)
	_prompt_button = UiTheme.button("", "", &"PrimaryButton")
	_prompt_button.custom_minimum_size = Vector2(130, 56)
	_prompt_button.add_theme_font_size_override("font_size", 22)
	_prompt_button.add_theme_constant_override("icon_max_width", 30)
	_prompt_button.pressed.connect(func(): zone_used.emit())
	UiTheme.add_key_badge(_prompt_button, "E")
	row.add_child(_prompt_button)


## Star Chase's banner: stars caught and time left.
func _build_game_bar() -> void:
	_game_bar = _place(UiTheme.card(&"Banner"), Control.PRESET_CENTER_TOP, Vector2(0, 14))
	_game_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_bar.visible = false
	var row := UiTheme.hbox(14)
	_game_bar.add_child(row)
	row.add_child(UiTheme.texture_rect(UiTheme.icon("glowing_star"), 40))
	_game_label = UiTheme.label("", &"Heading", 26, Color.WHITE)
	row.add_child(_game_label)
	row.add_child(UiTheme.texture_rect(UiTheme.icon("stopwatch"), 34))
	_game_time = UiTheme.label("", &"Heading", 26, Color("ffe066"))
	_game_time.custom_minimum_size.x = 62
	row.add_child(_game_time)


func _build_result() -> PanelContainer:
	var box := _dialog("Time's up!", "glowing_star")
	box.custom_minimum_size.x = 420
	_result_stars = UiTheme.label("", &"Heading", 30)
	_result_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_stars)
	var reward := UiTheme.hbox(8)
	reward.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(reward)
	reward.add_child(UiTheme.texture_rect(UiTheme.icon("chestnut"), 40))
	_result_reward = UiTheme.label("", &"Heading", 34, Color("b8741a"))
	reward.add_child(_result_reward)
	var best := UiTheme.hbox(8)
	best.alignment = BoxContainer.ALIGNMENT_CENTER
	best.add_child(UiTheme.texture_rect(UiTheme.icon("trophy"), 30))
	best.add_child(UiTheme.label("New best!", &"Heading", 22, UiTheme.PURPLE))
	box.add_child(best)
	_result_best = best
	var bonus := UiTheme.label("Catch %d stars for a bonus of %d Acorns!" % [StarChase.BONUS_AT, StarChase.BONUS],
			&"Hint", 15)
	bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(bonus)
	var row := UiTheme.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var again := UiTheme.button("Play again", "glowing_star", &"PurpleButton")
	again.custom_minimum_size = Vector2(180, 56)
	again.pressed.connect(func():
		_show_only(null)
		chase_again.emit())
	row.add_child(again)
	var done := UiTheme.button("Done", "check_mark_button", &"PrimaryButton")
	done.custom_minimum_size = Vector2(150, 56)
	done.add_theme_font_size_override("font_size", 22)
	done.pressed.connect(func(): _show_only(null))
	row.add_child(done)
	return box.get_parent()


## Opens the shop on a section ("home" or "clothes"; the last one by default).
## The list is rebuilt each time, so the clothes pictures show you as you are now.
func open_shop(section := "") -> void:
	if section == "":
		section = _shop.current_section() if _shop.current_section() != "" else "home"
	_shop.show_section(section)
	if not _shop.visible:
		_show_only(_shop)


func shop_open() -> bool:
	return _shop.visible


## Shows what a nearby zone offers, or hides the card for null.
func show_prompt(zone: InteractZone) -> void:
	_prompt.visible = zone != null and not _build_bar.visible
	if zone == null:
		return
	_prompt_icon.texture = UiTheme.icon(zone.icon)
	_prompt_title.text = zone.title
	_prompt_hint.text = zone.hint
	_prompt_button.text = zone.button_text
	_prompt.reset_size()


func show_game(countdown: float, caught: int, time_left: float) -> void:
	_game_bar.visible = true
	if countdown > 0.0:
		_game_label.text = "Get ready... %d" % ceili(countdown)
		_game_time.text = ""
	else:
		_game_label.text = "%d star%s" % [caught, "" if caught == 1 else "s"]
		_game_time.text = "%d" % ceili(time_left)
	_game_bar.reset_size()


func show_game_result(caught: int, reward: int, new_best: bool) -> void:
	_game_bar.visible = false
	_result_stars.text = "You caught %d star%s!" % [caught, "" if caught == 1 else "s"]
	_result_reward.text = "+%d" % reward
	_result_best.visible = new_best and caught > 0
	_show_only(_result)


func _on_earned(_currency: String, amount: int) -> void:
	_gain.text = "+%d" % amount
	if _gain_tween:
		_gain_tween.kill()
	_gain.modulate.a = 1.0
	_gain_tween = create_tween()
	_gain_tween.tween_interval(0.9)
	_gain_tween.tween_property(_gain, "modulate:a", 0.0, 0.6)


# --- Build mode -------------------------------------------------------------------

func _build_build_mode() -> void:
	_build_bar = _place(UiTheme.card(&"Banner"), Control.PRESET_CENTER_TOP, Vector2(0, 14))
	var bar := UiTheme.hbox(14)
	_build_bar.add_child(bar)
	bar.add_child(UiTheme.texture_rect(UiTheme.icon("couch_and_lamp"), 34))
	bar.add_child(UiTheme.label("Decorating your home", &"Heading", 22, Color.WHITE))
	for tip in [["Click", "place"], ["Right-click", "remove"], ["R", "turn"], ["E", "next look"]]:
		var pair := UiTheme.hbox(5)
		var key := UiTheme.label(tip[0], &"KeyBadge", 13)
		key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		key.add_theme_stylebox_override("normal", UiTheme.box(Color(1, 1, 1, 0.22), 7, 0, Color.TRANSPARENT,
				Vector4(7, 2, 7, 3)))
		pair.add_child(key)
		pair.add_child(UiTheme.label(tip[1], &"", 16, Color(1, 1, 1, 0.85)))
		bar.add_child(pair)
	_build_bar.visible = false

	_drawer = UiTheme.card()
	_drawer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_drawer.offset_left = 12
	_drawer.offset_right = -12
	_drawer.offset_bottom = -12
	_drawer.offset_top = -318
	_drawer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_drawer.add_theme_stylebox_override("panel", UiTheme.card_box(UiTheme.PAPER, 26, 14))
	_drawer.visible = false
	_root.add_child(_drawer)
	var row := UiTheme.hbox(14)
	_drawer.add_child(row)
	_browser = CatalogBrowser.new(Vector2(88, 88))
	_browser.chosen.connect(_on_entry_chosen)
	_browser.favorite_toggled.connect(func(key, on): GameState.set_favorite(key, on))
	row.add_child(_browser)
	row.add_child(VSeparator.new())
	row.add_child(_build_pick_panel())
	_build_peek()

	var entries := FurnitureCatalog.entries()
	for e in entries:
		var id: String = e["id"]
		var style: int = e["style"]
		var key: String = e["key"]
		e["thumb"] = func(): return _item_thumb(id, style)
		e["shop_key"] = ShopCatalog.furniture_key(id, style)
		e["tag"] = BuyCard.price_tag(e["shop_key"])
		e["tooltip"] = e["name"] if FurnitureCatalog.style_count(id) <= 1 or not FurnitureCatalog.has_art(id) \
				else "%s, look %d of %d" % [e["name"], style + 1, FurnitureCatalog.style_count(id)]
		_entries[key] = e
	var favs := {}
	for key in GameState.profile.get("favorites", []):
		favs[key] = true
	_browser.set_favorites(favs)
	_browser.recent = GameState.profile.get("recent", [])
	_browser.setup(FurnitureCatalog.CATEGORIES, entries)


## The picked item: a bigger picture, its looks, paints and tools.
func _build_pick_panel() -> Control:
	var side := UiTheme.vbox(8)
	side.custom_minimum_size.x = 236
	var top := UiTheme.hbox(10)
	side.add_child(top)
	var well := UiTheme.card(&"Well")
	well.add_theme_stylebox_override("panel", UiTheme.box(Color("e8f2ff"), 18, 0, Color.TRANSPARENT,
			Vector4(4, 4, 4, 4)))
	top.add_child(well)
	_pick_pic = UiTheme.texture_rect(null, 72)
	well.add_child(_pick_pic)
	var words := UiTheme.vbox(4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(words)
	_pick_name = UiTheme.label("", &"Heading", 21)
	_pick_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_pick_name)
	var tuck := UiTheme.icon_button("down_arrow", "Hide the catalog to see more of your home", 40)
	tuck.add_theme_constant_override("icon_max_width", 20)
	tuck.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tuck.pressed.connect(_tuck.bind(true))
	top.add_child(tuck)
	_look_row = UiTheme.hbox(4)
	words.add_child(_look_row)
	for step in [-1, 1]:
		var arrow := UiTheme.icon_button("left_arrow" if step < 0 else "right_arrow",
				"Previous look" if step < 0 else "Next look (E)", 36)
		arrow.add_theme_constant_override("icon_max_width", 18)
		arrow.pressed.connect(func(): style_stepped.emit(step))
		_look_row.add_child(arrow)
		if step < 0:
			_look_label = UiTheme.label("", &"Hint", 15)
			_look_label.custom_minimum_size.x = 64
			_look_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_look_row.add_child(_look_label)

	_paint = UiTheme.vbox(4)
	side.add_child(_paint)
	_paint.add_child(UiTheme.label("Paint", &"Hint"))
	_palette = SwatchRow.new(HOUSE_COLORS, "")
	_palette.add_theme_constant_override("h_separation", 5)
	_palette.add_theme_constant_override("v_separation", 5)
	for swatch in _palette.get_children():
		swatch.custom_minimum_size = Vector2(24, 24)
	_palette.color_chosen.connect(func(hex): color_changed.emit(Color.html(hex)))
	_paint.add_child(_palette)
	side.add_child(UiTheme.spacer())

	# Shown instead of the tools for a look you haven't bought yet.
	_buy_row = UiTheme.hbox(8)
	_buy_row.visible = false
	side.add_child(_buy_row)
	_buy_button = UiTheme.button("Buy", "chestnut", &"PrimaryButton", "Buy this look")
	_buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy_button.custom_minimum_size.y = 54
	_buy_button.add_theme_font_size_override("font_size", 22)
	_buy_button.add_theme_constant_override("icon_max_width", 28)
	_buy_button.pressed.connect(_buy_picked)
	_buy_row.add_child(_buy_button)
	var done_buying := UiTheme.icon_button("check_mark_button", "Stop decorating (B)", 54)
	done_buying.pressed.connect(func(): build_toggled.emit())
	_buy_row.add_child(done_buying)

	var tools := UiTheme.hbox(8)
	_tools = tools
	side.add_child(tools)
	var turn := UiTheme.icon_button("counterclockwise_arrows_button", "Turn it", 54, "R")
	turn.pressed.connect(func(): rotate_pressed.emit())
	tools.add_child(turn)
	_erase = UiTheme.icon_button("wastebasket", "Remove things: click a piece to take it away", 54)
	_erase.toggle_mode = true
	_erase.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.RED.lightened(0.55), 22, 3, UiTheme.RED,
			Vector4(10, 8, 10, 10)))
	_erase.add_theme_stylebox_override("hover_pressed", _erase.get_theme_stylebox("pressed"))
	_erase.toggled.connect(func(on): erase_toggled.emit(on))
	tools.add_child(_erase)
	var done := UiTheme.button("Done", "check_mark_button", &"PrimaryButton", "Stop decorating (B)")
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.add_theme_font_size_override("font_size", 22)
	done.add_theme_constant_override("icon_max_width", 28)
	done.pressed.connect(func(): build_toggled.emit())
	tools.add_child(done)
	return side


## A small bar with the picked item and Done, for building with the catalog tucked away.
func _build_peek() -> void:
	_peek = _place(UiTheme.card(), Control.PRESET_CENTER_BOTTOM, Vector2(0, -14))
	_peek.add_theme_stylebox_override("panel", UiTheme.card_box(UiTheme.PAPER, 30, 10))
	_peek.visible = false
	var row := UiTheme.hbox(10)
	_peek.add_child(row)
	var reopen := UiTheme.button("Catalog", "up_arrow", &"BlueButton", "Show the catalog again")
	reopen.custom_minimum_size.y = 56
	reopen.add_theme_constant_override("icon_max_width", 26)
	reopen.pressed.connect(_tuck.bind(false))
	row.add_child(reopen)
	var turn := UiTheme.icon_button("counterclockwise_arrows_button", "Turn it", 56, "R")
	turn.pressed.connect(func(): rotate_pressed.emit())
	row.add_child(turn)
	var done := UiTheme.button("Done", "check_mark_button", &"PrimaryButton", "Stop decorating (B)")
	done.custom_minimum_size.y = 56
	done.add_theme_font_size_override("font_size", 22)
	done.add_theme_constant_override("icon_max_width", 28)
	done.pressed.connect(func(): build_toggled.emit())
	row.add_child(done)


func _tuck(on: bool) -> void:
	_tucked = on
	_drawer.visible = _build_bar.visible and not on
	_peek.visible = _build_bar.visible and on


func _item_thumb(id: String, style: int) -> Texture2D:
	return ShopPanel.furniture_thumb(id, style)


## Price tags change when something is bought.
func _refresh_prices() -> void:
	for key in _entries:
		var e: Dictionary = _entries[key]
		e["tag"] = BuyCard.price_tag(e["shop_key"])
	_browser.refresh()
	if _build_bar.visible:
		_show_buy(_pick_key())


## The shop key of the look picked in the build catalog.
func _pick_key() -> String:
	return _browser.get_meta("pick_key", "")


func _show_buy(shop_key: String) -> void:
	var price := ShopCatalog.price(shop_key)
	var owned := shop_key == "" or GameState.owns(shop_key)
	_buy_row.visible = not owned
	_tools.visible = owned
	if owned:
		return
	_buy_button.text = "Buy  %s" % ShopCatalog.amount_text(price)
	_buy_button.icon = UiTheme.icon(ShopCatalog.currency_icon(price["currency"]))
	_buy_button.theme_type_variation = &"PurpleButton" if price["currency"] == ShopCatalog.STARDUST else &"PrimaryButton"
	_buy_button.disabled = not GameState.can_afford(shop_key)
	_buy_button.tooltip_text = "Buy this look" if GameState.can_afford(shop_key) \
			else "You need more %s" % ShopCatalog.currency_name(price["currency"])


## Buys the look picked in build mode. Stardust looks open the shop instead,
## where spending it takes a second tap.
func _buy_picked() -> void:
	var shop_key := _pick_key()
	var price := ShopCatalog.price(shop_key)
	if price.is_empty():
		return
	if price["currency"] == ShopCatalog.STARDUST:
		_shop.show_section("home")
		_show_only(_shop)
		_shop.pick(shop_key)
		return
	if GameState.buy(shop_key):
		toast("It's yours! Click your home to place it.")


## Called when placing something not bought yet.
func need_purchase(id: String, style: int) -> void:
	var shop_key := ShopCatalog.furniture_key(id, style if FurnitureCatalog.has_art(id) else 0)
	var price := ShopCatalog.price(shop_key)
	if price.is_empty():
		return
	if GameState.can_afford(shop_key):
		toast("Tap Buy to get this look first!")
	else:
		toast("This look costs %s %s. Find more acorns to get it!" % [ShopCatalog.amount_text(price),
				ShopCatalog.currency_name(price["currency"])])


func _on_entry_chosen(key: String) -> void:
	var e: Dictionary = _entries.get(key, {})
	if not e.is_empty():
		entry_chosen.emit(e["id"], e["style"])


# --- Helpers ----------------------------------------------------------------------

## Anchors a control to a corner or edge so it grows away from that edge.
func _place(control: Control, preset: int, offset: Vector2) -> Control:
	control.set_anchors_preset(preset)
	if preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT]:
		control.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	elif preset in [Control.PRESET_CENTER_TOP, Control.PRESET_CENTER_BOTTOM, Control.PRESET_CENTER]:
		control.grow_horizontal = Control.GROW_DIRECTION_BOTH
	if preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM]:
		control.grow_vertical = Control.GROW_DIRECTION_BEGIN
	elif preset == Control.PRESET_CENTER:
		control.grow_vertical = Control.GROW_DIRECTION_BOTH
	control.position += offset
	_root.add_child(control)
	return control


## Shows one centered card and hides the others (or hides all for null).
func _show_only(card: Control) -> void:
	for c in _cards():
		c.visible = c == card and not c.visible
	_scrim.visible = _cards().any(func(c): return c.visible)


func _cards() -> Array:
	return [_phrases, _help, _leave, _result, _shop]


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time * 2.0, 0.0, 1.0)
		_toast.visible = _toast_time > 0.0
	for bubble in _chat_box.get_children():
		var age: float = bubble.get_meta("age") + delta
		bubble.set_meta("age", age)
		bubble.modulate.a = clampf((CHAT_FADE - age) / 3.0, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	# Clicking the world gives the keyboard back to the game after searching.
	if event is InputEventMouseButton and event.pressed:
		var focus := _root.get_viewport().gui_get_focus_owner()
		if focus:
			focus.release_focus()


# --- Called by the world ----------------------------------------------------------

func set_status(text: String) -> void:
	if _status:
		_status.text = text


func set_player(display_name: String, avatar: Dictionary) -> void:
	_player_name.text = display_name
	_player_pic.texture = Thumbs.texture("portrait:" + JSON.stringify(avatar),
			func(): return AvatarBuilder.build(avatar), "portrait")


## Shows the current balances and membership from GameState.
func set_wallet() -> void:
	for currency in _wallet_labels:
		(_wallet_labels[currency] as Label).text = _short_number(GameState.balance(currency))
	var days := GameState.member_days_left()
	_member_badge.visible = days > 0
	_member_badge.tooltip_text = "Member: %d day%s left" % [days, "" if days == 1 else "s"]


static func _short_number(n: int) -> String:
	if n >= 1_000_000:
		return "%.1fM" % (n / 1_000_000.0)
	if n >= 10_000:
		return "%dk" % (n / 1000)
	return str(n)


func toast(text: String) -> void:
	_toast_label.text = text
	_toast_time = 4.0
	_toast.visible = true
	_toast.reset_size()


func set_pet(pet_name: String, species: String, config := {}) -> void:
	_pet_name.text = pet_name
	_pet_kind.text = "Your " + species.to_lower()
	if not config.is_empty():
		_pet_pic.texture = Thumbs.texture("pet:" + JSON.stringify(PetBuilder.sanitize(config)),
				func(): return PetBuilder.build(config), "pet")


func set_pet_needs(fullness: float, happiness: float) -> void:
	_fullness.value = fullness
	_happiness.value = happiness


func add_chat(speaker: String, text: String) -> void:
	_chat_lines.append("%s: %s" % [speaker, text])
	while _chat_lines.size() > CHAT_LINES:
		_chat_lines.pop_front()
	var bubble := UiTheme.card(&"Bubble")
	bubble.set_meta("age", 0.0)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := RichTextLabel.new()
	line.bbcode_enabled = true
	line.fit_content = true
	line.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.scroll_active = false
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_color_override("default_color", UiTheme.INK)
	line.add_theme_font_size_override("normal_font_size", 17)
	line.add_theme_font_override("bold_font", UiTheme.font(800))
	line.add_theme_font_size_override("bold_font_size", 17)
	if speaker == "*":
		line.text = "[color=#%s]%s[/color]" % [UiTheme.INK_SOFT.to_html(false), text]
	else:
		var hue := float(speaker.hash() % 360) / 360.0
		var color := Color.from_hsv(hue, 0.7, 0.75).to_html(false)
		line.text = "[b][color=#%s]%s[/color][/b]  %s" % [color, speaker, text]
	bubble.add_child(line)
	_chat_box.add_child(bubble)
	while _chat_box.get_child_count() > CHAT_LINES:
		_chat_box.get_child(0).free()


func open_quick_chat() -> void:
	_show_only(_phrases)


func ask_leave() -> void:
	_show_only(_leave)


## Closes whichever centered card is open. Returns false when none was.
func close_popups() -> bool:
	var any := _cards().any(func(c): return c.visible)
	_show_only(null)
	return any


func show_build(active: bool) -> void:
	_build_bar.visible = active
	_tuck(_tucked)
	for card in [_dock, _pet_card, _player_card, _chat_box]:
		card.visible = not active
	if active:
		_prompt.visible = false
	_erase.set_pressed_no_signal(false)
	if active:
		_browser.set_recent(GameState.profile.get("recent", []))


func refresh_recent() -> void:
	_browser.set_recent(GameState.profile.get("recent", []))


func set_build_selection(id: String, color: Color, style := 0, erasing := false) -> void:
	var key := "%s:%d" % [id, style if FurnitureCatalog.has_art(id) else 0]
	_browser.select(key)
	var shop_key := ShopCatalog.furniture_key(id, style if FurnitureCatalog.has_art(id) else 0)
	_browser.set_meta("pick_key", shop_key)
	_show_buy(shop_key)
	_erase.set_pressed_no_signal(erasing)
	_pick_name.text = FurnitureCatalog.ITEMS[id]["name"]
	_pick_pic.texture = _item_thumb(id, style if FurnitureCatalog.has_art(id) else 0)
	var styled := FurnitureCatalog.has_art(id)
	var looks := FurnitureCatalog.style_count(id)
	_look_row.visible = styled and looks > 1
	_look_label.text = "%d of %d" % [style + 1, looks]
	_paint.visible = not styled
	_palette.set_color(color.to_html(false))
