class_name AdminPanel
extends PanelContainer
## The admin commands as big buttons, for makers on a tablet or phone where the
## ` key console is out of reach. It opens from the Help card while
## AdminConsole.enabled(). Numbers are picked with - and + (hold to go faster)
## instead of typed. Every button runs the console's own command
## (AdminConsole.run), so the two always agree, and its answer shows at the
## bottom. Buttons that start something over take a second tap.

signal closed

## Seconds a "start over" button waits for its second tap.
const CONFIRM_TIME := 3.0
## Holding - or + steps again after HOLD_DELAY, then every HOLD_REPEAT.
const HOLD_DELAY := 0.4
const HOLD_REPEAT := 0.07

## One tile per command. A tile with "values" has a number to step through
## ("start" is the first one shown, "unit" how it reads). Each button is
## [text, icon, style, command, needs a second tap]; in a command, N is the
## picked number.
const TILES := [
	{"id": "stardust", "title": "Stardust", "icon": "shooting_star",
		"values": [10, 50, 100, 500, 1000, 5000, 10000], "start": 100, "unit": "%d",
		"buttons": [["Give", "wrapped_gift", &"PurpleButton", "stardust N", false],
			["Take", "wastebasket", &"", "stardust -N", false]]},
	{"id": "level", "title": "Level", "icon": "star",
		"values": "levels", "start": 1, "unit": "Level %d",
		"buttons": [["Set", "check_mark_button", &"PurpleButton", "level N", false],
			["Start over", "counterclockwise_arrows_button", &"", "level reset", true]]},
	{"id": "acorns", "title": "Acorns", "icon": "chestnut",
		"values": [10, 50, 100, 500, 1000, 5000, 10000], "start": 500, "unit": "%d",
		"buttons": [["Give", "wrapped_gift", &"OrangeButton", "acorns N", false],
			["Take", "wastebasket", &"", "acorns -N", false]]},
	{"id": "xp", "title": "XP", "icon": "sparkles",
		"values": [10, 25, 50, 100, 250, 500, 1000, 5000], "start": 50, "unit": "%d XP",
		"buttons": [["Give", "wrapped_gift", &"PurpleButton", "xp N", false],
			["Take", "wastebasket", &"", "xp -N", false]]},
	{"id": "member", "title": "Membership", "icon": "crown",
		"values": [1, 7, 30, 90, 365], "start": 30, "unit": "%d days",
		"buttons": [["Add", "wrapped_gift", &"BlueButton", "member N", false],
			["End", "cross_mark", &"", "member 0", false]]},
	{"id": "boost", "title": "Star Boost", "icon": "high_voltage",
		"values": [15, 30, 60, 120, 240], "start": 30, "unit": "%d min",
		"buttons": [["Give", "wrapped_gift", &"PurpleButton", "boost N", false],
			["End", "cross_mark", &"", "boost 0", false]]},
	{"id": "unlock", "title": "Shop things", "icon": "shopping_bags",
		"buttons": [["Unlock all", "unlocked", &"PrimaryButton", "unlock all", false],
			["Take back", "counterclockwise_arrows_button", &"", "unlock reset", true]]},
	{"id": "pets", "title": "Wild pets", "icon": "paw_prints",
		"buttons": [["Find all", "paw_prints", &"PrimaryButton", "pets all", false],
			["Forget all", "counterclockwise_arrows_button", &"", "pets reset", true]]},
]

## Per tile id: {values, index, value label, status label}.
var _tiles := {}
## Buttons waiting for their second tap, with seconds left.
var _confirming := {}
var _answer: Label
## The - or + being held: {button, tile, step, wait}.
var _held := {}


func _init() -> void:
	theme_type_variation = &"Card"
	var box := UiTheme.vbox(12)
	add_child(box)
	var head := UiTheme.hbox(10)
	box.add_child(head)
	head.add_child(UiTheme.texture_rect(UiTheme.icon("hammer_and_wrench"), 40))
	var words := UiTheme.vbox(0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(words)
	words.add_child(UiTheme.label("Admin tools", &"Heading", 26))
	words.add_child(UiTheme.label("For makers while the game is being built. Changes this device's save only.",
			&"Hint", 15))
	var close := UiTheme.icon_button("cross_mark", "Close", 44)
	close.add_theme_constant_override("icon_max_width", 22)
	close.pressed.connect(func(): closed.emit())
	head.add_child(close)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for tile in TILES:
		grid.add_child(_build_tile(tile))

	var well := UiTheme.card(&"Well")
	box.add_child(well)
	# One line, so a long answer can't stretch the card.
	_answer = UiTheme.label("Pick a number, then tap a button.", &"", 16)
	_answer.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_answer.custom_minimum_size.x = 100
	well.add_child(_answer)


func _build_tile(tile: Dictionary) -> Control:
	var well := UiTheme.card(&"Well")
	well.custom_minimum_size.x = 470
	var box := UiTheme.vbox(6)
	well.add_child(box)
	var top := UiTheme.hbox(8)
	box.add_child(top)
	top.add_child(UiTheme.texture_rect(UiTheme.icon(tile["icon"]), 28))
	top.add_child(UiTheme.label(tile["title"], &"Heading", 18))
	var status := UiTheme.label("", &"Hint", 15)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.clip_text = true
	top.add_child(status)
	var row := UiTheme.hbox(8)
	box.add_child(row)
	var state := {"status": status, "values": [], "index": 0, "value": null}
	_tiles[tile["id"]] = state
	if tile.has("values"):
		var values: Array = range(1, Levels.MAX_LEVEL + 1) if tile["values"] is String else tile["values"]
		state["values"] = values
		state["index"] = maxi(values.find(tile["start"]), 0)
		row.add_child(_step_button(tile["id"], -1))
		var value := UiTheme.label("", &"Heading", 19)
		value.custom_minimum_size = Vector2(104, 48)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var value_box := PanelContainer.new()
		value_box.add_theme_stylebox_override("panel", UiTheme.box(Color.WHITE, 14, 0, Color.TRANSPARENT, Vector4.ZERO))
		value_box.add_child(value)
		row.add_child(value_box)
		row.add_child(_step_button(tile["id"], 1))
		state["value"] = value
		state["unit"] = tile["unit"]
	row.add_child(UiTheme.spacer())
	for spec in tile["buttons"]:
		var b := UiTheme.button(spec[0], spec[1], spec[2])
		b.custom_minimum_size = Vector2(0, 52)
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_constant_override("icon_max_width", 24)
		b.set_meta("text", spec[0])
		b.pressed.connect(_on_button.bind(b, tile["id"], spec[3], spec[4]))
		row.add_child(b)
	_show_value(tile["id"])
	return well


func _step_button(id: String, step: int) -> Button:
	var b := UiTheme.icon_button("plus" if step > 0 else "minus", "More" if step > 0 else "Less", 48)
	b.add_theme_constant_override("icon_max_width", 22)
	b.button_down.connect(func():
		_step(id, step)
		_held = {"button": b, "tile": id, "step": step, "wait": HOLD_DELAY})
	return b


func _step(id: String, step: int) -> void:
	var state: Dictionary = _tiles[id]
	state["index"] = clampi(state["index"] + step, 0, state["values"].size() - 1)
	_show_value(id)


func _show_value(id: String) -> void:
	var state: Dictionary = _tiles[id]
	if state["value"]:
		state["value"].text = state["unit"] % picked(id)


## The number picked on a tile (0 for tiles without one).
func picked(id: String) -> int:
	var state: Dictionary = _tiles[id]
	return int(state["values"][state["index"]]) if not state["values"].is_empty() else 0


## Picks a number on a tile, if it is one of its stops. For tests and screenshots.
func pick(id: String, value: int) -> void:
	var state: Dictionary = _tiles[id]
	var index: int = state["values"].find(value)
	if index >= 0:
		state["index"] = index
		_show_value(id)


func _on_button(b: Button, id: String, command: String, confirm: bool) -> void:
	if confirm and not _confirming.has(b):
		_confirming[b] = CONFIRM_TIME
		b.text = "Sure?"
		return
	if _confirming.has(b):
		_confirming.erase(b)
		b.text = b.get_meta("text")
	var words := command.replace("N", str(picked(id))).split(" ", false)
	_answer.text = AdminConsole.run(words)
	refresh()


## Updates every tile's status line, and starts the level picker at your level.
func refresh() -> void:
	var p := Progress.progress()
	var days := GameState.member_days_left()
	var boost := Progress.boost_seconds_left()
	var status := {
		"stardust": "You have %d" % GameState.balance("stardust"),
		"acorns": "You have %d" % GameState.balance("acorns"),
		"level": "Level %d, %s" % [p["level"],
				"top level" if int(p["need"]) == 0 else "%d / %d XP" % [p["into"], p["need"]]],
		"xp": "%d XP in all" % Progress.xp(),
		"member": "%d day%s left" % [days, "" if days == 1 else "s"] if days > 0 else "Not a member",
		"boost": "%d min left" % ceili(boost / 60.0) if boost > 0 else "Off",
		"unlock": "You own %d" % GameState.profile.get("owned", []).size(),
		"pets": "Found %d of %d" % [PetCollection.found_count(), PetCollection.wild_kinds().size()],
	}
	for id in status:
		_tiles[id]["status"].text = status[id]


func _ready() -> void:
	visibility_changed.connect(func():
		if visible:
			pick("level", Progress.level())
			refresh()
			# Built before the theme reached it, so it starts too big: shrink to fit, centered.
			set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
		else:
			_held.clear()
			for b in _confirming:
				b.text = b.get_meta("text")
			_confirming.clear())
	refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	for b in _confirming.keys():
		_confirming[b] -= delta
		if _confirming[b] <= 0.0:
			_confirming.erase(b)
			b.text = b.get_meta("text")
	if not _held.is_empty():
		if not _held["button"].is_pressed():
			_held.clear()
		else:
			_held["wait"] -= delta
			if _held["wait"] <= 0.0:
				_held["wait"] = HOLD_REPEAT
				_step(_held["tile"], _held["step"])
	# Keeps the boost minutes up to date while open.
	if Engine.get_process_frames() % 60 == 0:
		refresh()
