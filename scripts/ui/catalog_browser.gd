class_name CatalogBrowser
extends HBoxContainer
## Finds one thing among hundreds: a rail of category tabs, a row of group
## chips (say "Sofas" or "Lamps"), a search box, and a paged grid of pictures.
## "Favorites" and "Recent" tabs come first, so a player's go-to pieces are
## always one tap away. Build mode uses it with every furniture style as a card.
##
## Entries: {"key", "name", "category", "group", "thumb": Callable -> Texture2D,
## optional "tags"}. Categories: {"id", "name", "icon"}.

signal chosen(key: String)
signal favorite_toggled(key: String, on: bool)

const FAVORITES := "favorites"
const RECENT := "recent"

## Shows the Favorites and Recent tabs (and stars on cards). Set before setup().
var personal_tabs := true
## key -> true; the caller saves it when favorite_toggled fires.
var favorites := {}
## Keys, newest first.
var recent: Array = []

var _categories: Array = []
var _entries: Array = []
var _by_key := {}
var _names := {} # category id -> name
var _category := ""
var _group := ""
var _selected := ""
var _rail_buttons := {}
var _title: Label
var _chip_scroll: ScrollContainer
var _chips: HBoxContainer
var _search: LineEdit
var _grid: ItemGrid


func _init(card_size := Vector2(96, 96)) -> void:
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var rail_scroll := ScrollContainer.new()
	rail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(rail_scroll)
	var rail := GridContainer.new()
	rail.name = "Rail"
	rail.columns = 2
	rail.add_theme_constant_override("h_separation", 6)
	rail.add_theme_constant_override("v_separation", 6)
	rail_scroll.add_child(rail)

	var main := UiTheme.vbox(8)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(main)
	var header := UiTheme.hbox(10)
	main.add_child(header)
	_title = UiTheme.label("", &"Heading", 22)
	_title.custom_minimum_size.x = 150
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_title)
	_chip_scroll = ScrollContainer.new()
	_chip_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_chip_scroll.gui_input.connect(_on_chip_scroll_input)
	header.add_child(_chip_scroll)
	_chips = UiTheme.hbox(6)
	_chip_scroll.add_child(_chips)
	_search = LineEdit.new()
	_search.placeholder_text = "Search"
	_search.custom_minimum_size = Vector2(190, 42)
	_search.right_icon = UiTheme.small_icon("magnifying_glass_tilted_left", 22)
	_search.clear_button_enabled = true
	_search.add_theme_constant_override("minimum_character_width", 0)
	_search.text_changed.connect(func(_t): _refresh(false))
	# Enter or Escape gives the keyboard back to the game.
	_search.text_submitted.connect(func(_t): _search.release_focus())
	header.add_child(_search)
	_search.visible = not TouchInput.active
	TouchInput.mode_changed.connect(_on_touch_mode)

	_grid = ItemGrid.new()
	_grid.card_size = card_size
	_grid.favorites = favorites
	_grid.chosen.connect(func(key):
		_selected = key
		chosen.emit(key))
	_grid.favorite_toggled.connect(func(key, on):
		favorite_toggled.emit(key, on)
		if _category == FAVORITES:
			_refresh(true))
	main.add_child(_grid)


## A phone's own keyboard can't open for the browser game, so the search box
## hides while playing by touch (the category tabs and chips still find things).
func _on_touch_mode(on: bool) -> void:
	_search.visible = not on
	if on and _search.text != "":
		_search.text = ""
		_refresh(false)


func setup(categories: Array, entries: Array, start_category := "") -> void:
	_categories = categories
	_entries = entries
	_by_key.clear()
	for e in entries:
		_by_key[e["key"]] = e
	var rail := find_child("Rail", true, false) as GridContainer
	for child in rail.get_children():
		child.free()
	_rail_buttons.clear()
	_names = {FAVORITES: "Favorites", RECENT: "Recent"}
	var tabs := [{"id": FAVORITES, "name": "Favorites", "icon": "glowing_star"},
		{"id": RECENT, "name": "Recently used", "icon": "alarm_clock"}] if personal_tabs else []
	_grid.favorites = favorites if personal_tabs else null
	for c in categories:
		_names[c["id"]] = c["name"]
	for c in tabs + categories:
		var b := UiTheme.button("", c["icon"], &"TabButton", c["name"])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(54, 46)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 32)
		b.pressed.connect(show_category.bind(c["id"]))
		rail.add_child(b)
		_rail_buttons[c["id"]] = b
	show_category(start_category if _names.has(start_category) else categories[0]["id"])


## Draws the current page again, for example after prices or tags change.
func refresh() -> void:
	_refresh(true)


func set_favorites(favs: Dictionary) -> void:
	favorites = favs
	_grid.favorites = favs
	_refresh(true)


func set_recent(keys: Array) -> void:
	recent = keys
	if _category == RECENT:
		_refresh(true)


func current_category() -> String:
	return _category


func show_category(id: String) -> void:
	_category = id
	_group = ""
	_search.text = ""
	for key in _rail_buttons:
		_rail_buttons[key].set_pressed_no_signal(key == id)
	_build_chips()
	_refresh(false)


## Marks an entry as picked and shows its page if it is in the current list.
func select(key: String) -> void:
	_selected = key
	_grid.select(key)


func _build_chips() -> void:
	for child in _chips.get_children():
		child.free()
	var groups := []
	for e in _entries:
		if e["category"] == _category and not (e["group"] in groups):
			groups.append(e["group"])
	# The chip row keeps its space when empty, so search stays on the right.
	_chips.visible = groups.size() > 1
	if groups.size() <= 1:
		return
	for g in [""] + groups:
		var chip := UiTheme.button("All" if g == "" else g, "", &"ChipButton")
		chip.toggle_mode = true
		chip.set_pressed_no_signal(g == _group)
		chip.custom_minimum_size.y = 40
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.pressed.connect(func():
			_group = g
			for c in _chips.get_children():
				c.set_pressed_no_signal(c == chip)
			_refresh(false))
		_chips.add_child(chip)


func _refresh(keep_page: bool) -> void:
	var query := _search.text.strip_edges().to_lower()
	var items := []
	if query != "":
		_title.text = "Search"
		_grid.empty_text = "Nothing called \"%s\". Try another word!" % _search.text.strip_edges()
		_grid.empty_icon = "magnifying_glass_tilted_left"
		for e in _entries:
			if query in _search_text(e):
				items.append(e)
	elif _category == FAVORITES:
		_grid.empty_text = "Tap the star on anything you love, and it waits for you here."
		_grid.empty_icon = "glowing_star"
		for e in _entries:
			if favorites.has(e["key"]):
				items.append(e)
	elif _category == RECENT:
		_grid.empty_text = "Things you place show up here."
		_grid.empty_icon = "alarm_clock"
		for key in recent:
			if _by_key.has(key):
				items.append(_by_key[key])
	else:
		_grid.empty_text = "Nothing here yet!"
		_grid.empty_icon = "sparkles"
		for e in _entries:
			if e["category"] == _category and (_group == "" or e["group"] == _group):
				items.append(e)
	if query == "":
		_title.text = _names.get(_category, "")
	_chips.visible = query == "" and _chips.get_child_count() > 0
	_grid.select(_selected, false)
	_grid.set_items(items, keep_page)


func _search_text(e: Dictionary) -> String:
	if not e.has("_search"):
		e["_search"] = " ".join([e["name"], e["group"], _names.get(e["category"], ""),
				e.get("tags", "")]).to_lower()
	return e["_search"]


## The mouse wheel scrolls the chip row sideways.
func _on_chip_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var step := 0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			step = -60
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			step = 60
		if step != 0:
			_chip_scroll.scroll_horizontal += step
			accept_event()
