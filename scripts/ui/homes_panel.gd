class_name HomesPanel
extends PanelContainer
## Your homes: every home you own (move into any of them; your plot shows the
## one you live in, and each keeps its own furniture), new homes to buy, and
## rooms to add to the homes you have. Picking a card shows it up close beside
## the catalog, with what it holds and a Buy, Move in or Go see it button.

signal closed
## Move into a home you own (or go to the one you live in).
signal home_chosen(type: String)
signal stardust_info

const CATEGORIES := [
	{"id": "homes", "name": "Homes", "icon": "house_with_garden"},
	{"id": "rooms", "name": "Rooms", "icon": "door"},
]
const HERE_TAG := Color("cfe6ff")

var _browser: CatalogBrowser
var _card: BuyCard
var _about: Label
var _empty: Label
var _wallet_labels := {}
var _entries := {} # key -> entry


func _init() -> void:
	theme_type_variation = &"Card"
	custom_minimum_size = Vector2(1120, 0)
	var box := UiTheme.vbox(12)
	add_child(box)
	var head := UiTheme.hbox(12)
	box.add_child(head)
	head.add_child(UiTheme.texture_rect(UiTheme.icon("house_with_garden"), 44))
	head.add_child(UiTheme.label("Homes", &"Heading", 30))
	var hint := UiTheme.label("Own as many as you like. Your plot shows the one you live in.", &"Hint", 16)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hint)
	head.add_child(UiTheme.spacer())
	var wallet := UiTheme.card(&"Well")
	wallet.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PAPER_DIM, 18, 0, Color.TRANSPARENT,
			Vector4(12, 6, 12, 6)))
	head.add_child(wallet)
	var coins := UiTheme.hbox(8)
	wallet.add_child(coins)
	for currency in GameState.CURRENCIES:
		var info: Dictionary = GameState.CURRENCIES[currency]
		coins.add_child(UiTheme.texture_rect(UiTheme.icon(info["icon"]), 28))
		var amount := UiTheme.label("0", &"Heading", 21)
		amount.tooltip_text = info["name"]
		amount.mouse_filter = Control.MOUSE_FILTER_PASS
		coins.add_child(amount)
		_wallet_labels[currency] = amount
	var get_more := UiTheme.icon_button("plus", "Get more Stardust", 46)
	get_more.add_theme_constant_override("icon_max_width", 26)
	get_more.pressed.connect(func(): stardust_info.emit())
	coins.add_child(get_more)
	var close := UiTheme.icon_button("cross_mark", "Close", 48, "Esc")
	close.add_theme_constant_override("icon_max_width", 22)
	close.pressed.connect(func(): closed.emit())
	head.add_child(close)

	var body := UiTheme.hbox(14)
	body.custom_minimum_size.y = 440
	box.add_child(body)
	_browser = CatalogBrowser.new(Vector2(172, 150))
	_browser.personal_tabs = false
	_browser._grid.show_names = true
	_browser.chosen.connect(_on_chosen)
	body.add_child(_browser)
	body.add_child(VSeparator.new())
	var side := UiTheme.vbox(6)
	side.custom_minimum_size.x = 260
	body.add_child(side)
	_empty = UiTheme.label("Tap a home or a room to see it up close.", &"Hint", 17)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	side.add_child(_empty)
	_card = BuyCard.new(150)
	_card.visible = false
	_card.bought.connect(_on_bought)
	_card.action_pressed.connect(_on_action)
	side.add_child(_card)
	_about = UiTheme.label("", &"Hint", 15)
	_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_about.custom_minimum_size.x = 240
	_about.visible = false
	side.add_child(_about)
	GameState.wallet_changed.connect(_show_wallet)
	_show_wallet()


## Lists everything again (homes owned may have changed) and opens a tab:
## "homes" or "rooms" ("" keeps the one open).
func open(category := "") -> void:
	var start := category if category != "" else _browser.current_category()
	var list := _home_entries() + _room_entries()
	_entries.clear()
	for e in list:
		_entries[e["key"]] = e
	_browser.setup(CATEGORIES, list, start)
	_card.visible = false
	_about.visible = false
	_empty.visible = true


## Shows one home or room up close, as if its card was picked.
func pick(key: String) -> void:
	if _entries.has(key):
		_browser.show_category(_entries[key]["category"])
		_browser.select(key)
		_on_chosen(key)


func _home_entries() -> Array:
	var out := []
	for type in HomeCatalog.types():
		var key := HomeCatalog.home_key(type)
		var owned := Homes.owns_home(type)
		var tag := BuyCard.price_tag(key, true)
		if type == Homes.current():
			tag = {"icon": "key", "text": "Home", "color": HERE_TAG}
		out.append({"key": key, "type": type, "name": HomeCatalog.home_name(type), "category": "homes",
			"group": "Yours" if owned else "For sale", "tags": type.replace("_", " "), "tag": tag,
			"thumb": func(): return home_thumb(type)})
	return out


func _room_entries() -> Array:
	var out := []
	for type in Homes.owned():
		for r in HomeCatalog.addons(type):
			var key := HomeCatalog.room_key(type, r["id"])
			var id: String = r["id"]
			out.append({"key": key, "type": type, "room": id, "name": r["name"], "category": "rooms",
				"group": HomeCatalog.home_name(type), "tags": "room " + HomeCatalog.home_name(type).to_lower(),
				"tag": BuyCard.price_tag(key, true), "thumb": func(): return room_thumb(type, id)})
	return out


func _on_chosen(key: String) -> void:
	var e: Dictionary = _entries.get(key, {})
	if e.is_empty():
		return
	_empty.visible = false
	_card.visible = true
	_about.visible = true
	_card.show_item(key, e["name"], e["thumb"].call())
	_update_details()


## The words under the card and its second button, which change once bought.
func _update_details() -> void:
	var e: Dictionary = _entries.get(_card.key, {})
	if e.is_empty():
		return
	var type: String = e["type"]
	var all := HomeCatalog.addons(type).map(func(r): return r["id"])
	if e.has("room"):
		var r := HomeCatalog.room(type, e["room"])
		_about.text = "A room for your %s. It fits %d more things." % [HomeCatalog.home_name(type), int(r.get("capacity", 0))]
		_card.set_action("Go see it", "house")
	elif Homes.owns_home(type):
		var built := Homes.rooms(type)
		_about.text = "%s\nRooms added: %d of %d. Holds %d things." % [HomeCatalog.info(type)["about"],
				built.size(), all.size(), HomeCatalog.capacity(type, built)]
		if type == Homes.current():
			_card.set_action("Go home", "house")
		else:
			_card.set_action("Move in", "key")
	else:
		_about.text = "%s\nComes with %d rooms, and %d more can be added. Holds %d things to start." % [
				HomeCatalog.info(type)["about"], HomeCatalog.base_rooms(type).size(), all.size(),
				HomeCatalog.capacity(type, [])]
		_card.set_action("Move in", "key")


func _on_bought(_key: String) -> void:
	# A new home brings its rooms into the list; tags change from prices to checks.
	var key := _card.key
	open()
	pick(key)


func _on_action(key: String) -> void:
	var e: Dictionary = _entries.get(key, {})
	if not e.is_empty():
		home_chosen.emit(e["type"])


func _show_wallet() -> void:
	for currency in _wallet_labels:
		(_wallet_labels[currency] as Label).text = str(GameState.balance(currency))


## A picture of a home: as you have it, or as it comes when it's new.
static func home_thumb(type: String) -> Texture2D:
	var rooms := Homes.rooms(type) if Homes.owns_home(type) else []
	var items := Homes.items(type) if Homes.owns_home(type) else HomeCatalog.starter_items(type)
	var key := "home:%s:%s" % [type, JSON.stringify([rooms, items]).md5_text()]
	return Thumbs.texture(key, func(): return HomeShell.preview(type, rooms, items), "home")


## A picture of a room, lit up in its home with every room you have.
static func room_thumb(type: String, id: String) -> Texture2D:
	var rooms := Homes.rooms(type)
	if not (id in rooms):
		rooms = rooms + [id]
	return Thumbs.texture("room:%s:%s:%s" % [type, id, ",".join(rooms)],
			func(): return HomeShell.preview(type, rooms, [], id), "home")
