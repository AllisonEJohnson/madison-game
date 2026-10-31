class_name LevelCard
extends PanelContainer
## The card behind the level badge: how far you are into this level, what the
## next levels bring, the ways to earn XP, and the Star Boost, which doubles
## XP for a while for Stardust (with a second tap to be sure, like every
## Stardust purchase).

signal closed

const CONFIRM_TIME := 4.0

var _star: Control
var _title: Label
var _bar: ProgressBar
var _bar_text: Label
var _to_go: Label
var _coming: VBoxContainer
var _boost_text: Label
var _boost_button: Button
var _confirm_time := 0.0


func _init() -> void:
	theme_type_variation = &"Card"
	var box := UiTheme.vbox(14)
	add_child(box)
	var head := UiTheme.hbox(12)
	box.add_child(head)
	_star = LevelBadge.star(52.0, 24)
	head.add_child(_star)
	_title = UiTheme.label("", &"Heading", 28)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close := UiTheme.icon_button("cross_mark", "Close", 44)
	close.add_theme_constant_override("icon_max_width", 22)
	close.pressed.connect(func(): closed.emit())
	head.add_child(close)

	var bar_row := UiTheme.hbox(10)
	box.add_child(bar_row)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.custom_minimum_size = Vector2(0, 22)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.add_theme_stylebox_override("background", UiTheme.box(Color("ebe3f7"), 11, 0, Color.TRANSPARENT, Vector4.ZERO))
	_bar.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.PURPLE, 11, 0, Color.TRANSPARENT, Vector4.ZERO))
	bar_row.add_child(_bar)
	_bar_text = UiTheme.label("", &"Heading", 18)
	_bar_text.custom_minimum_size.x = 110
	_bar_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar_row.add_child(_bar_text)
	_to_go = UiTheme.label("", &"Hint", 16)
	box.add_child(_to_go)

	var columns := UiTheme.hbox(22)
	box.add_child(columns)
	var left := UiTheme.vbox(8)
	left.custom_minimum_size.x = 360
	columns.add_child(left)
	left.add_child(UiTheme.label("Coming up", &"Heading", 20))
	_coming = UiTheme.vbox(10)
	left.add_child(_coming)
	columns.add_child(VSeparator.new())
	var right := UiTheme.vbox(6)
	right.custom_minimum_size.x = 300
	columns.add_child(right)
	right.add_child(UiTheme.label("Ways to earn XP", &"Heading", 20))
	for source in Levels.SOURCE_ORDER:
		var rule: Dictionary = Levels.SOURCES[source]
		var row := UiTheme.hbox(10)
		right.add_child(row)
		row.add_child(UiTheme.texture_rect(UiTheme.icon(rule["icon"]), 28))
		var how := UiTheme.label(rule["how"], &"", 16)
		how.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(how)
		var worth := UiTheme.label("+%d" % int(rule["xp"]), &"Heading", 17, UiTheme.PURPLE)
		row.add_child(worth)

	box.add_child(HSeparator.new())
	var boost := UiTheme.hbox(12)
	box.add_child(boost)
	boost.add_child(UiTheme.texture_rect(UiTheme.icon("high_voltage"), 40))
	var boost_words := UiTheme.vbox(0)
	boost_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boost_words.alignment = BoxContainer.ALIGNMENT_CENTER
	boost.add_child(boost_words)
	boost_words.add_child(UiTheme.label("Star Boost", &"Heading", 20))
	_boost_text = UiTheme.label("", &"Hint", 15)
	boost_words.add_child(_boost_text)
	_boost_button = UiTheme.button("", "shooting_star", &"PurpleButton")
	_boost_button.custom_minimum_size = Vector2(150, 54)
	_boost_button.add_theme_font_size_override("font_size", 20)
	_boost_button.add_theme_constant_override("icon_max_width", 28)
	_boost_button.pressed.connect(_on_boost)
	boost.add_child(_boost_button)


func _ready() -> void:
	# Only kept up to date while open; opening it refreshes it.
	Progress.xp_changed.connect(func(_gained):
		if visible:
			refresh())
	GameState.wallet_changed.connect(func():
		if visible:
			refresh())
	visibility_changed.connect(func():
		_confirm_time = 0.0
		refresh())
	refresh()


func refresh() -> void:
	var p := Progress.progress()
	var level: int = p["level"]
	(_star.get_child(1) as Label).text = str(level)
	_title.text = "Level %d" % level
	if int(p["need"]) == 0:
		_bar.value = 1.0
		_bar_text.text = "Top level!"
		_to_go.text = "You reached the very top. Amazing!"
	else:
		_bar.value = float(p["into"]) / float(p["need"])
		_bar_text.text = "%d / %d XP" % [p["into"], p["need"]]
		_to_go.text = "%d more XP to reach level %d!" % [int(p["need"]) - int(p["into"]), level + 1]
	for child in _coming.get_children():
		child.free()
	var upcoming := Levels.upcoming(level, 3)
	if upcoming.is_empty():
		_coming.add_child(UiTheme.label("Every level still gives you Acorns!", &"Hint", 16))
	for step in upcoming:
		var row := UiTheme.hbox(10)
		_coming.add_child(row)
		var badge := LevelBadge.star(38.0, 17)
		(badge.get_child(1) as Label).text = str(step["level"])
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(badge)
		var lines := UiTheme.vbox(2)
		lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lines)
		for reward in step["rewards"]:
			lines.add_child(reward_line(reward, 24, 16))
	_show_boost()


## One reward as a picture and words, for this card and the level-up card.
static func reward_line(reward: Dictionary, icon_size: float, font_size: int) -> HBoxContainer:
	var line := UiTheme.hbox(8)
	line.add_child(UiTheme.texture_rect(UiTheme.icon(reward["icon"]), icon_size))
	var text := UiTheme.label(reward["text"], &"", font_size)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size.x = 200
	line.add_child(text)
	return line


func _show_boost() -> void:
	var left := Progress.boost_seconds_left()
	if left > 0:
		var minutes := ceili(left / 60.0)
		_boost_text.text = "Double XP for %d more minute%s!" % [minutes, "" if minutes == 1 else "s"]
	else:
		_boost_text.text = "Double XP for %d minutes." % Levels.BOOST_MINUTES
	var short := Levels.BOOST_COST - GameState.balance(ShopCatalog.STARDUST)
	_boost_button.disabled = short > 0 or not Progress.can_add_boost()
	if _confirm_time > 0.0:
		_boost_button.text = "Spend %d?" % Levels.BOOST_COST
	else:
		_boost_button.text = ("Add  %d" if left > 0 else "Boost  %d") % Levels.BOOST_COST
	if short > 0:
		_boost_button.tooltip_text = "You need %d more Stardust. The Stardust store is coming soon!" % short
	elif not Progress.can_add_boost():
		_boost_button.tooltip_text = "That's as much boost as you can have at once."
	else:
		_boost_button.tooltip_text = "Spend %d Stardust for double XP" % Levels.BOOST_COST


func _on_boost() -> void:
	# Stardust will cost real money one day, so spending it takes a second tap.
	if _confirm_time <= 0.0:
		_confirm_time = CONFIRM_TIME
		_show_boost()
		return
	_confirm_time = 0.0
	Progress.buy_boost()
	_show_boost()


func _process(delta: float) -> void:
	if not visible:
		return
	if _confirm_time > 0.0:
		_confirm_time -= delta
		if _confirm_time <= 0.0:
			_show_boost()
	# Keeps the minutes left up to date while the card is open.
	if Engine.get_process_frames() % 60 == 0:
		_show_boost()
