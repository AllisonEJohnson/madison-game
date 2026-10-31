class_name PetsPanel
extends PanelContainer
## My pets: every kind of pet, the ones you have and the ones still out in the
## wild. Picking a card shows it up close: bring one of yours along, see where
## a wild kind lives (and the level its land opens at), or get a kind that's
## for sale right away with Stardust (with a second tap to be sure, like every
## Stardust purchase). A few kinds can only be found, never bought.

signal closed
## Bring this pet along (one you have).
signal chosen(species: String)
## A kind was just bought with Stardust.
signal bought(species: String)
signal stardust_info

const CONFIRM_TIME := 4.0
const FILTERS := [
	{"id": "all", "name": "All", "icon": "paw_prints"},
	{"id": "mine", "name": "Mine", "icon": "red_heart"},
	{"id": "town", "name": "Hometown", "icon": "house_with_garden"},
	{"id": "glade", "name": "Starfall Glade", "icon": "sparkles"},
	{"id": "sky", "name": "Sky Garden", "icon": "rainbow"},
]

var _filter := "all"
var _filter_buttons := {}
var _selected := ""
var _found: Label
var _stardust: Label
var _grid: ItemGrid
var _pic: TextureRect
var _title: Label
var _kind: Label
var _where: Label
var _where_row: HBoxContainer
var _price_row: HBoxContainer
var _price: Label
var _bring: Button
var _with_you: Label
var _get: Button
var _hint: Label
var _detail: VBoxContainer
var _confirm_time := 0.0


func _init() -> void:
	theme_type_variation = &"Card"
	custom_minimum_size = Vector2(1000, 0)
	var box := UiTheme.vbox(12)
	add_child(box)
	var head := UiTheme.hbox(12)
	box.add_child(head)
	head.add_child(UiTheme.texture_rect(UiTheme.icon("paw_prints"), 44))
	var words := UiTheme.vbox(0)
	head.add_child(words)
	words.add_child(UiTheme.label("My pets", &"Heading", 30))
	_found = UiTheme.label("", &"Hint", 16)
	words.add_child(_found)
	head.add_child(UiTheme.spacer())
	var wallet := UiTheme.card(&"Well")
	wallet.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PAPER_DIM, 18, 0, Color.TRANSPARENT,
			Vector4(12, 6, 12, 6)))
	head.add_child(wallet)
	var coins := UiTheme.hbox(8)
	wallet.add_child(coins)
	coins.add_child(UiTheme.texture_rect(UiTheme.icon(ShopCatalog.currency_icon(ShopCatalog.STARDUST)), 28))
	_stardust = UiTheme.label("0", &"Heading", 21)
	_stardust.tooltip_text = "Stardust"
	_stardust.mouse_filter = Control.MOUSE_FILTER_PASS
	coins.add_child(_stardust)
	var get_more := UiTheme.icon_button("plus", "Get more Stardust", 46)
	get_more.add_theme_constant_override("icon_max_width", 26)
	get_more.pressed.connect(func(): stardust_info.emit())
	coins.add_child(get_more)
	var close := UiTheme.icon_button("cross_mark", "Close", 48, "Esc")
	close.add_theme_constant_override("icon_max_width", 22)
	close.pressed.connect(func(): closed.emit())
	head.add_child(close)

	var chips := UiTheme.hbox(8)
	box.add_child(chips)
	for f in FILTERS:
		var chip := UiTheme.button(f["name"], f["icon"], &"ChipButton")
		chip.toggle_mode = true
		chip.custom_minimum_size.y = 44
		chip.pressed.connect(show_filter.bind(f["id"]))
		chips.add_child(chip)
		_filter_buttons[f["id"]] = chip

	var body := UiTheme.hbox(14)
	body.custom_minimum_size.y = 400
	box.add_child(body)
	_grid = ItemGrid.new()
	_grid.card_size = Vector2(110, 116)
	_grid.card_sizes = [Vector2(110, 116)]
	_grid.show_names = true
	_grid.chosen.connect(pick)
	body.add_child(_grid)
	body.add_child(VSeparator.new())
	_detail = UiTheme.vbox(8)
	_detail.custom_minimum_size.x = 270
	body.add_child(_detail)
	_build_detail()
	GameState.wallet_changed.connect(_refresh_wallet)
	Progress.xp_changed.connect(func(_gained):
		if visible:
			refresh())
	_refresh_wallet()


func _build_detail() -> void:
	var well := UiTheme.card(&"Well")
	well.add_theme_stylebox_override("panel", UiTheme.box(Color("e8f2ff"), 20, 0, Color.TRANSPARENT,
			Vector4(6, 6, 6, 6)))
	well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail.add_child(well)
	_pic = UiTheme.texture_rect(null, 150)
	well.add_child(_pic)
	_title = UiTheme.label("", &"Heading", 26)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_child(_title)
	_kind = UiTheme.label("", &"Hint", 16)
	_kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_child(_kind)
	_where_row = UiTheme.hbox(6)
	_where_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_detail.add_child(_where_row)
	_where_row.add_child(UiTheme.texture_rect(UiTheme.icon("compass"), 26))
	_where = UiTheme.label("", &"", 17)
	_where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_where.custom_minimum_size.x = 220
	_where_row.add_child(_where)
	_price_row = UiTheme.hbox(6)
	_price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_detail.add_child(_price_row)
	_price_row.add_child(UiTheme.texture_rect(UiTheme.icon("shooting_star"), 30))
	_price = UiTheme.label("", &"Heading", 26)
	_price_row.add_child(_price)
	_with_you = UiTheme.label("With you now!", &"Heading", 21, UiTheme.GREEN)
	_with_you.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_child(_with_you)
	_bring = UiTheme.button("Bring along", "paw_prints", &"PrimaryButton")
	_bring.custom_minimum_size.y = 58
	_bring.add_theme_font_size_override("font_size", 23)
	_bring.add_theme_constant_override("icon_max_width", 32)
	_bring.pressed.connect(func(): chosen.emit(_selected))
	_detail.add_child(_bring)
	_get = UiTheme.button("Get now", "shooting_star", &"PurpleButton")
	_get.custom_minimum_size.y = 58
	_get.add_theme_font_size_override("font_size", 22)
	_get.add_theme_constant_override("icon_max_width", 30)
	_get.pressed.connect(_on_get)
	_detail.add_child(_get)
	_hint = UiTheme.label("", &"Hint", 15)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 240
	_detail.add_child(_hint)


## Shows the panel's list again (say, after making a new friend) and keeps
## the picked pet, or picks the one with you.
func refresh() -> void:
	var found := PetCollection.found_count()
	var total := PetCollection.wild_kinds().size()
	_found.text = "You found %d of %d wild pets" % [found, total] if found < total \
			else "You found all %d wild pets. Amazing!" % total
	show_filter(_filter)
	pick(_selected if _selected != "" else PetCollection.active_species())
	# Fits the panel to its contents and keeps it in the middle of the screen.
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH


func show_filter(id: String) -> void:
	_filter = id
	for key in _filter_buttons:
		_filter_buttons[key].set_pressed_no_signal(key == id)
	var items := []
	for species in PetBuilder.SPECIES:
		var info := PetBuilder.info(species)
		var show := true
		match id:
			"mine":
				show = PetCollection.owns(species)
			"town", "glade", "sky":
				show = info.get("land", "") == id or (id == "town" and info.get("home", false))
		if show:
			items.append(card_item(species))
	_grid.set_items(items, true)
	_grid.select(_selected, false)


## A grid card for a kind: your pet's name, or the kind with a tag saying how
## to get it (its Stardust price, "Wild" for find-only kinds, or the level its
## land opens at). The pet with you has a paw tag.
static func card_item(species: String) -> Dictionary:
	var owned := PetCollection.owns(species)
	var config := PetCollection.config_of(species)
	var item := {"key": species, "name": config["name"] if owned else PetBuilder.SPECIES[species]["name"],
		"thumb": func(): return PetCollection.thumb(config), "tooltip": PetBuilder.SPECIES[species]["name"]}
	if species == PetCollection.active_species():
		item["tag"] = {"icon": "paw_prints", "color": BuyCard.OWNED_TAG}
	elif not owned:
		var level := PetCollection.land_level(species)
		var price := PetBuilder.stardust_price(species)
		if level > Progress.level() and price <= 0:
			item["tag"] = {"icon": "locked", "text": "Lv %d" % level, "color": BuyCard.LOCKED_TAG}
		elif price > 0:
			item["tag"] = {"icon": "shooting_star", "text": str(price), "color": BuyCard.STARDUST_TAG}
		else:
			item["tag"] = {"icon": "magnifying_glass_tilted_left", "text": "Wild", "color": BuyCard.ACORN_TAG}
	return item


## Shows one kind up close.
func pick(species: String) -> void:
	if not PetBuilder.SPECIES.has(species):
		return
	_selected = species
	_grid.select(species, false)
	_confirm_time = 0.0
	var owned := PetCollection.owns(species)
	var config := PetCollection.config_of(species)
	var kind: String = PetBuilder.SPECIES[species]["name"]
	_pic.texture = PetCollection.thumb(config)
	_title.text = config["name"] if owned else kind
	_kind.text = ("Your " + kind.to_lower()) if owned else "Not found yet"
	var home := PetBuilder.is_home(species)
	_where_row.visible = not home
	if not home:
		var level := PetCollection.land_level(species)
		_where.text = "Lives in %s" % PetCollection.where(species)
		if level > Progress.level():
			_where.text += " (opens at level %d)" % level
	var active := species == PetCollection.active_species()
	var price := PetBuilder.stardust_price(species)
	_with_you.visible = active
	_bring.visible = owned and not active
	_price_row.visible = not owned and price > 0
	_price.text = str(price)
	_get.visible = not owned and price > 0
	_get.disabled = GameState.balance(ShopCatalog.STARDUST) < price
	_show_confirm(false)
	if owned and home and not active:
		_hint.text = "%s is waiting at home." % config["name"]
	elif owned and not active:
		_hint.text = "%s is waiting at home. You made friends in %s." % [config["name"], PetCollection.where(species)]
	elif active:
		_hint.text = "Feed and play with %s to keep them happy." % config["name"]
	elif price <= 0:
		_hint.text = "This one can only be found in the wild. Look for the sparkle that says New!"
	elif GameState.balance(ShopCatalog.STARDUST) < price:
		_hint.text = "Find one in the wild, or get one with %d Stardust. The Stardust store is coming soon!" % price
	else:
		_hint.text = "Find one in the wild for free, or get one now. Tap, then tap again to be sure."


## Where to find a kind you don't have, in a sentence.
static func where_text(species: String) -> String:
	var kind: String = PetBuilder.SPECIES[species]["name"].to_lower()
	var text := "Find a wild %s in %s and make friends!" % [kind, PetCollection.where(species)]
	var level := PetCollection.land_level(species)
	if level > Progress.level():
		text = "Find a wild %s in %s, which opens at level %d!" % [kind, PetCollection.where(species), level]
	if PetBuilder.stardust_price(species) > 0:
		text += " Or get one with Stardust from My pets while you play."
	return text


func _on_get() -> void:
	if _confirm_time <= 0.0:
		_confirm_time = CONFIRM_TIME
		_show_confirm(true)
		return
	_confirm_time = 0.0
	var species := _selected
	if PetCollection.buy(species):
		bought.emit(species)
		refresh()


func _show_confirm(on: bool) -> void:
	if on:
		_get.text = "Spend %d Stardust?" % PetBuilder.stardust_price(_selected)
	else:
		_get.text = "Get now"


func _process(delta: float) -> void:
	if _confirm_time > 0.0:
		_confirm_time -= delta
		if _confirm_time <= 0.0:
			_show_confirm(false)


func _refresh_wallet() -> void:
	_stardust.text = str(GameState.balance(ShopCatalog.STARDUST))
	if visible and _selected != "":
		pick(_selected)
