class_name ShopPanel
extends PanelContainer
## The shop: furniture for your home and clothes for your character, each in
## its own section with category tabs, a picture of everything for sale and
## its price. Picking a card shows it up close beside the catalog with a Buy
## button; once bought, "Decorate" or "Wear it" puts it to use right away.
## Things you already own stay listed with a check mark.

signal closed
signal decorate(id: String, style: int)
signal wear(option: String, index: int)
signal stardust_info

const SECTIONS := [
	{"id": "home", "name": "Home", "icon": "couch_and_lamp"},
	{"id": "clothes", "name": "Clothes", "icon": "t-shirt"},
]

var _section := ""
var _section_buttons := {}
var _wallet_labels := {}
var _browser: CatalogBrowser
var _card: BuyCard
var _empty: Label
var _entries := {} # key -> entry, for the section on screen


func _init() -> void:
	theme_type_variation = &"Card"
	custom_minimum_size = Vector2(1120, 0)
	var box := UiTheme.vbox(12)
	add_child(box)
	var head := UiTheme.hbox(12)
	box.add_child(head)
	head.add_child(UiTheme.texture_rect(UiTheme.icon("shopping_bags"), 44))
	head.add_child(UiTheme.label("Shop", &"Heading", 30))
	head.add_child(UiTheme.spacer())
	for s in SECTIONS:
		var b := UiTheme.button(s["name"], s["icon"], &"TabButton")
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(150, 52)
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_constant_override("icon_max_width", 32)
		b.pressed.connect(show_section.bind(s["id"]))
		head.add_child(b)
		_section_buttons[s["id"]] = b
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
	var close := UiTheme.icon_button("cross_mark", "Close the shop", 48, "Esc")
	close.add_theme_constant_override("icon_max_width", 22)
	close.pressed.connect(func(): closed.emit())
	head.add_child(close)

	var body := UiTheme.hbox(14)
	body.custom_minimum_size.y = 440
	box.add_child(body)
	_browser = CatalogBrowser.new(Vector2(104, 104))
	_browser.personal_tabs = false
	_browser.chosen.connect(_on_chosen)
	body.add_child(_browser)
	body.add_child(VSeparator.new())
	var side := UiTheme.vbox(0)
	side.custom_minimum_size.x = 250
	body.add_child(side)
	_empty = UiTheme.label("Tap anything to see it up close.", &"Hint", 17)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	side.add_child(_empty)
	_card = BuyCard.new(128)
	_card.visible = false
	_card.bought.connect(_on_bought)
	_card.action_pressed.connect(_on_action)
	side.add_child(_card)
	GameState.wallet_changed.connect(_show_wallet)
	_show_wallet()


## Opens a section ("home" or "clothes"), rebuilding its list so the clothes
## pictures show the character as they look now.
func show_section(id: String) -> void:
	_section = id
	for key in _section_buttons:
		_section_buttons[key].set_pressed_no_signal(key == id)
	_entries.clear()
	var list := _furniture_entries() if id == "home" else _clothes_entries()
	for e in list:
		_entries[e["key"]] = e
	_browser.setup(FurnitureCatalog.CATEGORIES if id == "home" else ShopCatalog.CLOTHES_CATEGORIES, list)
	_card.visible = false
	_empty.visible = true


func current_section() -> String:
	return _section


func show_category(id: String) -> void:
	_browser.show_category(id)


## Shows one item up close, as if its card was picked.
func pick(key: String) -> void:
	if _entries.has(key):
		_browser.select(key)
		_on_chosen(key)


func _furniture_entries() -> Array:
	var out := []
	for item in ShopCatalog.furniture_for_sale():
		var id: String = item["id"]
		var style: int = item["style"]
		var key := ShopCatalog.furniture_key(id, style)
		out.append({"key": key, "name": FurnitureCatalog.ITEMS[id]["name"], "category": item["category"],
			"group": FurnitureCatalog.ITEMS[id]["name"], "tags": id.replace("_", " "), "id": id, "style": style,
			"thumb": func(): return furniture_thumb(id, style), "tag": BuyCard.price_tag(key, true)})
	return out


func _clothes_entries() -> Array:
	var out := []
	var avatar: Dictionary = GameState.profile["avatar"]
	for item in ShopCatalog.clothes_for_sale():
		var option: String = item["option"]
		var index: int = item["index"]
		var key := ShopCatalog.clothes_key(option, index)
		var view := ShopCatalog.clothes_view(option)
		var config := ShopCatalog.try_on(avatar, option, index)
		out.append({"key": key, "name": ShopCatalog.clothes_name(option, index), "category": item["category"],
			"group": ShopCatalog.clothes_group(option, index), "option": option, "index": index,
			"thumb": func(): return avatar_thumb(config, view), "tag": BuyCard.price_tag(key, true)})
	return out


func _on_chosen(key: String) -> void:
	var e: Dictionary = _entries.get(key, {})
	if e.is_empty():
		return
	_empty.visible = false
	_card.visible = true
	_card.show_item(key, e["name"], e["thumb"].call())
	_update_action()


func _update_action() -> void:
	var e: Dictionary = _entries.get(_card.key, {})
	if e.is_empty():
		return
	if e.has("id"):
		_card.set_action("Decorate", "couch_and_lamp")
	elif int(GameState.profile["avatar"].get(e["option"], -1)) == e["index"]:
		_card.set_action("Wearing it", "check_mark_button", false)
	else:
		_card.set_action("Wear it", "t-shirt")


func _on_bought(key: String) -> void:
	var e: Dictionary = _entries.get(key, {})
	if not e.is_empty():
		e["tag"] = BuyCard.price_tag(key, true)
		_browser.refresh()
	_update_action()


func _on_action(key: String) -> void:
	var e: Dictionary = _entries.get(key, {})
	if e.has("id"):
		decorate.emit(e["id"], e["style"])
	elif e.has("option"):
		wear.emit(e["option"], e["index"])
		_update_action()


func _show_wallet() -> void:
	for currency in _wallet_labels:
		(_wallet_labels[currency] as Label).text = str(GameState.balance(currency))


static func furniture_thumb(id: String, style: int) -> Texture2D:
	var art := FurnitureCatalog.has_art(id)
	var key := "furniture:%s:%d:%s" % [id, style, FurnitureCatalog.style_path(id, style) if art else "shape"]
	return Thumbs.texture(key, func(): return FurnitureCatalog.build(id, "", false, style), "item", art)


## The same pictures (and picture keys) the character creator uses.
static func avatar_thumb(config: Dictionary, view: String) -> Texture2D:
	var thumb_key := "avatar:%s:%s" % [view, JSON.stringify(config).md5_text()]
	return Thumbs.texture(thumb_key, func(): return AvatarBuilder.build(config), view)
