class_name BuyCard
extends VBoxContainer
## One item up close: a big picture, its name and price, how much you have,
## and a Buy button. Once you own it, a second button can put it to use
## ("Wear it", "Decorate"). The shop's side panel and the character creator's
## "Get this?" card are both one of these.
##
## Stardust will cost real money one day, so spending it takes a second tap.

signal bought(key: String)
signal action_pressed(key: String)

const ACORN_TAG := Color("ffe9c7")
const STARDUST_TAG := Color("eadcff")
const OWNED_TAG := Color("d4f4dd")
const CONFIRM_TIME := 4.0

var key := ""
var _title: Label
var _pic: TextureRect
var _price_row: HBoxContainer
var _price_icon: TextureRect
var _price_label: Label
var _have: Label
var _buy: Button
var _action: Button
var _hint: Label
var _action_text := ""
var _confirm_time := 0.0


## `picture_size` sets the size of the picture well.
func _init(picture_size := 150.0) -> void:
	add_theme_constant_override("separation", 8)
	var well := UiTheme.card(&"Well")
	well.add_theme_stylebox_override("panel", UiTheme.box(Color("e8f2ff"), 20, 0, Color.TRANSPARENT,
			Vector4(6, 6, 6, 6)))
	well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(well)
	_pic = UiTheme.texture_rect(null, picture_size)
	well.add_child(_pic)
	_title = UiTheme.label("", &"Heading", 22)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_title)
	_price_row = UiTheme.hbox(6)
	_price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_price_row)
	_price_icon = UiTheme.texture_rect(null, 30)
	_price_row.add_child(_price_icon)
	_price_label = UiTheme.label("", &"Heading", 26)
	_price_row.add_child(_price_label)
	_have = UiTheme.label("", &"Hint", 15)
	_have.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_have)
	_buy = UiTheme.button("Buy", "shopping_bags", &"PrimaryButton")
	_buy.custom_minimum_size.y = 58
	_buy.add_theme_font_size_override("font_size", 24)
	_buy.add_theme_constant_override("icon_max_width", 32)
	_buy.pressed.connect(_on_buy)
	add_child(_buy)
	_action = UiTheme.button("", "", &"BlueButton")
	_action.custom_minimum_size.y = 54
	_action.add_theme_font_size_override("font_size", 21)
	_action.add_theme_constant_override("icon_max_width", 30)
	_action.pressed.connect(func(): action_pressed.emit(key))
	add_child(_action)
	_hint = UiTheme.label("", &"Hint", 15)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 200
	add_child(_hint)
	GameState.wallet_changed.connect(refresh)
	GameState.owned_changed.connect(refresh)


## Shows an item. `action` is the label of the button shown once it's owned
## ("" for none), with `action_icon` on it.
func show_item(item_key: String, title: String, picture: Texture2D, action := "", action_icon := "") -> void:
	key = item_key
	_title.text = title
	_pic.texture = picture
	_action_text = action
	_action.icon = UiTheme.icon(action_icon) if action_icon != "" else null
	_confirm_time = 0.0
	refresh()


## Changes the picture only (say, after the avatar changes).
func set_picture(picture: Texture2D) -> void:
	_pic.texture = picture


func set_action(action: String, action_icon := "", enabled := true) -> void:
	_action_text = action
	_action.icon = UiTheme.icon(action_icon) if action_icon != "" else null
	_action.disabled = not enabled
	refresh()


func refresh() -> void:
	if key == "":
		return
	var price := ShopCatalog.price(key)
	var owned := GameState.owns(key)
	var currency: String = price.get("currency", ShopCatalog.ACORNS)
	_price_row.visible = not price.is_empty()
	_price_icon.texture = UiTheme.icon(ShopCatalog.currency_icon(currency))
	_price_label.text = ShopCatalog.amount_text(price)
	_have.visible = not owned
	_have.text = "You have %d %s" % [GameState.balance(currency), ShopCatalog.currency_name(currency)]
	_buy.visible = not owned
	_action.visible = owned and _action_text != ""
	_action.text = _action_text
	var short := int(price.get("amount", 0)) - GameState.balance(currency)
	_buy.disabled = short > 0
	_hint.visible = true
	if owned:
		_price_row.visible = false
		_hint.text = "It's yours!" if not price.is_empty() else "Free for everyone!"
	elif short > 0:
		_hint.text = _need_text(currency, short)
	elif currency == ShopCatalog.STARDUST:
		_hint.text = "Stardust is special. Tap Buy, then tap again to be sure."
	else:
		_hint.visible = false
	_show_confirm(_confirm_time > 0.0)


func _need_text(currency: String, short: int) -> String:
	if currency == ShopCatalog.STARDUST:
		return "You need %d more Stardust. The Stardust store is coming soon!" % short
	return "You need %d more Acorns. Find acorns around town, or play Star Chase in Starfall Glade!" % short


func _on_buy() -> void:
	var price := ShopCatalog.price(key)
	if price.get("currency", "") == ShopCatalog.STARDUST and _confirm_time <= 0.0:
		_confirm_time = CONFIRM_TIME
		_show_confirm(true)
		return
	_confirm_time = 0.0
	if GameState.buy(key):
		bought.emit(key)
	refresh()


func _show_confirm(on: bool) -> void:
	if on:
		_buy.text = "Spend %s Stardust?" % ShopCatalog.amount_text(ShopCatalog.price(key))
		_buy.theme_type_variation = &"PurpleButton"
		_buy.icon = UiTheme.icon("shooting_star")
	else:
		_buy.text = "Buy"
		_buy.theme_type_variation = &"PrimaryButton"
		_buy.icon = UiTheme.icon("shopping_bags")


func _process(delta: float) -> void:
	if _confirm_time > 0.0:
		_confirm_time -= delta
		if _confirm_time <= 0.0:
			_show_confirm(false)


## The little corner label for a catalog card: the price of something not
## owned yet, a check on something bought (with `show_owned`), or {} for free.
static func price_tag(item_key: String, show_owned := false) -> Dictionary:
	var price := ShopCatalog.price(item_key)
	if price.is_empty():
		return {}
	if GameState.owns(item_key):
		return {"icon": "check_mark_button", "color": OWNED_TAG} if show_owned else {}
	var stardust: bool = price["currency"] == ShopCatalog.STARDUST
	return {"icon": ShopCatalog.currency_icon(price["currency"]), "text": ShopCatalog.amount_text(price),
		"color": STARDUST_TAG if stardust else ACORN_TAG}
