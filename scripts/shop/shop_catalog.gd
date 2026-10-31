class_name ShopCatalog
extends RefCounted
## What the shop sells and what everything costs.
##
## Every furniture look and clothing choice has a key: "furniture:<id>:<style>"
## (say "furniture:sofa:3") or "avatar:<option key>:<index>" (say "avatar:hat:12").
## Most things cost Acorns, the currency earned by playing; a few special ones cost
## Stardust, the premium currency. Anything not for sale is free and always owned:
## one look of most furniture, the starter home, a good set of basic clothes, and
## everything about a body (face, skin, ears, height) and every color.
##
## Prices are rules per item kind rather than a list per item, so new styles and
## clothes get a price without anyone writing one down. To change what something
## costs, change its rule here.

const ACORNS := "acorns"
const STARDUST := "stardust"

## Furniture kinds for sale. "price" is in Acorns for every look of the item;
## "free" is how many of its first looks are free (1 when left out); "stardust"
## sells some looks for Stardust instead ({look: amount}). Kinds not listed, and
## items without looks, are free.
## "level" is the player level needed to buy the Acorn looks (1 when left
## out); Stardust looks can be bought at any level, because premium is for
## getting ahead faster. See Levels for what each level brings.
const FURNITURE := {
	"chair": {"price": 20},
	"table": {"price": 35},
	"armchair": {"price": 45, "level": 2},
	"sofa": {"price": 80, "stardust": {6: 20}, "level": 2},
	"bed": {"price": 90, "stardust": {6: 25}, "level": 3},
	"wardrobe": {"price": 70, "level": 3},
	"bookshelf": {"price": 60, "level": 3},
	"lamp": {"price": 25},
	"plant": {"price": 15},
	"fridge": {"price": 70, "level": 4},
	"stove": {"price": 70, "level": 4},
	"bathtub": {"price": 90, "level": 4},
	"toilet": {"price": 40, "level": 4},
	"piano": {"price": 180, "free": 0, "stardust": {1: 30}, "level": 6},
	"arcade": {"price": 220, "free": 0, "stardust": {4: 35}, "level": 9},
	"toy_box": {"price": 30, "stardust": {9: 15}},
	"pet_bed": {"price": 40, "stardust": {3: 15}},
}

## Clothing for sale, by avatar option key. "free" means choices below that
## number are free (choice 0 is always "None"); "for_sale" instead lists the
## only choices that cost anything. The choice a new character starts with is
## always free. Keys not listed (face, ears, skin, height, colors) are free.
## Numbers are positions in CharacterParts.lists() (or the shape avatar's
## OPTIONS when the art isn't installed).
## "level" works as for furniture.
const CLOTHES := {
	# Hair is part of who you are, so most styles are free and only the fancy ones cost.
	"hair": {"price": 40, "for_sale": [2, 10, 11, 12, 20, 22, 23, 24, 28, 29], "stardust": {18: 15, 19: 15}},
	"top": {"price": 35, "free": 13, "stardust": {44: 20, 51: 20}},
	"bottom": {"price": 30, "free": 7},
	"outfit": {"price": 60, "free": 1, "stardust": {9: 20}, "level": 4},
	"shoes": {"price": 25, "free": 6},
	"socks": {"price": 15, "free": 2},
	"gloves": {"price": 20, "free": 3, "level": 3},
	"hat": {"price": 40, "free": 9, "stardust": {25: 15, 40: 15, 52: 15}, "level": 2},
	"glasses": {"price": 30, "free": 6, "level": 2},
	"face_extra": {"price": 20, "free": 4, "level": 3},
	"costume": {"price": 250, "free": 1, "stardust": {3: 40, 5: 40, 9: 40, 12: 40}, "level": 8},
	# The shape avatar's back items, used only without the licensed art.
	"back": {"price": 40, "free": 2, "level": 2},
}

## The shop's clothing tabs: which option keys each shows.
const CLOTHES_CATEGORIES := [
	{"id": "hair", "name": "Hair", "icon": "person_getting_haircut", "keys": ["hair"]},
	{"id": "tops", "name": "Tops", "icon": "t-shirt", "keys": ["top"]},
	{"id": "bottoms", "name": "Bottoms", "icon": "jeans", "keys": ["bottom"]},
	{"id": "outfits", "name": "Outfits", "icon": "dress", "keys": ["outfit"]},
	{"id": "shoes", "name": "Shoes & socks", "icon": "running_shoe", "keys": ["shoes", "socks"]},
	{"id": "hats", "name": "Hats", "icon": "top_hat", "keys": ["hat"]},
	{"id": "extras", "name": "Glasses & extras", "icon": "glasses", "keys": ["glasses", "face_extra", "gloves", "back"]},
	{"id": "costumes", "name": "Costumes", "icon": "party_popper", "keys": ["costume"]},
]
## Group chip names for each option key. Bottoms and shoes are split by their
## own names instead ("Pants", "Shorts", "Sandals", "Sneakers").
const KEY_NAMES := {"hair": "Hair", "top": "Tops", "bottom": "Bottoms", "outfit": "Outfits",
	"shoes": "Shoes", "socks": "Socks", "gloves": "Gloves", "hat": "Hats", "glasses": "Glasses",
	"face_extra": "Face extras", "costume": "Costumes", "back": "On your back"}
const SPLIT_BY_NAME := ["bottom", "shoes"]

static var _starter := {}
static var _defaults := {}
static var _views := {}


## {"currency", "amount"} for a key, or {} when it is free or not a real item.
static func price(key: String) -> Dictionary:
	var parts := key.split(":")
	if parts.size() != 3 or not parts[2].is_valid_int():
		return {}
	var index := int(parts[2])
	match parts[0]:
		"furniture":
			return _furniture_price(parts[1], index)
		"avatar":
			return _clothes_price(parts[1], index)
	return {}


static func is_free(key: String) -> bool:
	return price(key).is_empty()


## The player level needed to buy something: its kind's "level" for Acorn
## prices, and 1 for free things and Stardust looks.
static func level_needed(key: String) -> int:
	var p := price(key)
	if p.is_empty() or p["currency"] != ACORNS:
		return 1
	var parts := key.split(":")
	var rules: Dictionary = FURNITURE if parts[0] == "furniture" else CLOTHES
	return maxi(int(rules.get(parts[1], {}).get("level", 1)), 1)


## True when the player's level is too low to buy it yet.
static func level_locked(key: String) -> bool:
	return level_needed(key) > Progress.level()


## The kinds of things the shop starts selling at a level, as words for the
## level-up card: ["sofas", "armchairs", "hats"].
static func unlocked_at(level: int) -> Array:
	var out := []
	for id in FURNITURE:
		if int(FURNITURE[id].get("level", 1)) == level and FurnitureCatalog.ITEMS.has(id):
			out.append(_plural(str(FurnitureCatalog.ITEMS[id]["name"]).to_lower()))
	for option in CLOTHES:
		if int(CLOTHES[option].get("level", 1)) == level and AvatarBuilder.options(option).size() > 1:
			out.append(str(KEY_NAMES.get(option, option)).to_lower())
	return out


static func _plural(word: String) -> String:
	if word.ends_with("s"):
		return word
	if word.ends_with("shelf"):
		return word.trim_suffix("f") + "ves"
	if word.ends_with("sh") or word.ends_with("ch") or word.ends_with("x"):
		return word + "es"
	return word + "s"


## True for keys that name something that exists, free or not.
static func is_item(key: String) -> bool:
	var parts := key.split(":")
	if parts.size() != 3 or not parts[2].is_valid_int() or int(parts[2]) < 0:
		return false
	var index := int(parts[2])
	match parts[0]:
		"furniture":
			return FurnitureCatalog.ITEMS.has(parts[1]) and index < maxi(FurnitureCatalog.style_count(parts[1]), 1)
		"avatar":
			return index < AvatarBuilder.options(parts[1]).size()
	return false


static func furniture_key(id: String, style: int) -> String:
	return "furniture:%s:%d" % [id, style]


static func clothes_key(option: String, index: int) -> String:
	return "avatar:%s:%d" % [option, index]


static func _furniture_price(id: String, style: int) -> Dictionary:
	if not FURNITURE.has(id) or not FurnitureCatalog.ITEMS.has(id):
		return {}
	var looks := maxi(FurnitureCatalog.style_count(id), 1)
	if style < 0 or style >= looks or _starter_furniture().has(furniture_key(id, style)):
		return {}
	var rule: Dictionary = FURNITURE[id]
	if rule.get("stardust", {}).has(style):
		return {"currency": STARDUST, "amount": int(rule["stardust"][style])}
	if style < int(rule.get("free", 1)):
		return {}
	return {"currency": ACORNS, "amount": int(rule["price"])}


static func _clothes_price(option: String, index: int) -> Dictionary:
	if not CLOTHES.has(option) or index <= 0 or index >= AvatarBuilder.options(option).size():
		return {}
	if _defaults.is_empty():
		_defaults = AvatarBuilder.default_config()
	if int(_defaults.get(option, -1)) == index:
		return {}
	var rule: Dictionary = CLOTHES[option]
	if rule.get("stardust", {}).has(index):
		return {"currency": STARDUST, "amount": int(rule["stardust"][index])}
	if rule.has("for_sale"):
		if not (index in rule["for_sale"]):
			return {}
	elif index < int(rule.get("free", 1)):
		return {}
	return {"currency": ACORNS, "amount": int(rule["price"])}


## Furniture looks the starter home uses, which every player gets free.
static func _starter_furniture() -> Dictionary:
	if _starter.is_empty():
		for item in FurnitureCatalog.starter_layout():
			_starter[furniture_key(item["id"], int(item.get("s", 0)))] = true
	return _starter


## The keys of everything a layout and an avatar use that costs something,
## so profiles saved before the shop keep what they already had.
static func priced_keys_in(layout: Array, avatar: Dictionary) -> Array:
	var out := []
	for item in layout:
		var key := furniture_key(item["id"], int(item.get("s", 0)))
		if not is_free(key) and not (key in out):
			out.append(key)
	for option in CLOTHES:
		var key := clothes_key(option, int(avatar.get(option, 0)))
		if avatar.has(option) and not is_free(key):
			out.append(key)
	return out


## The avatar with one choice put on, taking off whatever would hide it (an
## outfit hides tops and bottoms; a costume hides almost everything).
static func try_on(avatar: Dictionary, option: String, index: int) -> Dictionary:
	var out := avatar.duplicate()
	out[option] = index
	if index > 0:
		match option:
			"top", "bottom":
				out["outfit"] = 0
				out["costume"] = 0
			"outfit", "shoes", "socks", "gloves", "hat", "hair":
				out["costume"] = 0
	return out


## The name of a clothing choice, such as "Hat 12" or "Astronaut".
static func clothes_name(option: String, index: int) -> String:
	var names := AvatarBuilder.options(option)
	return str(names[index]) if index >= 0 and index < names.size() else ""


## The chip a clothing choice is grouped under in the shop.
static func clothes_group(option: String, index: int) -> String:
	if option in SPLIT_BY_NAME:
		# "Pants 3" -> "Pants", "Sneakers 12" -> "Sneakers".
		var words := clothes_name(option, index).split(" ")
		if words.size() > 1 and words[-1].is_valid_int():
			words.resize(words.size() - 1)
		return " ".join(words)
	return KEY_NAMES.get(option, option.capitalize())


## The picture angle for a clothing option key, as the character creator uses it.
static func clothes_view(option: String) -> String:
	if _views.is_empty():
		for tab in AvatarBuilder.tabs():
			for row in tab["rows"]:
				_views[row["key"]] = row.get("view", tab.get("view", "body"))
	return _views.get(option, "body")


## Every clothing choice the shop sells, for the current kind of avatar:
## [{option, index, category}], in the order the shop shows them.
static func clothes_for_sale() -> Array:
	var out := []
	for category in CLOTHES_CATEGORIES:
		for option in category["keys"]:
			for index in AvatarBuilder.options(option).size():
				if not is_free(clothes_key(option, index)):
					out.append({"option": option, "index": index, "category": category["id"]})
	return out


## Every furniture look the shop sells: [{id, style, category}].
static func furniture_for_sale() -> Array:
	var out := []
	for id in FurnitureCatalog.ITEMS:
		var item: Dictionary = FurnitureCatalog.ITEMS[id]
		if not item.has("category"):
			continue
		var looks := FurnitureCatalog.style_count(id) if FurnitureCatalog.has_art(id) else 1
		for style in looks:
			if not is_free(furniture_key(id, style)):
				out.append({"id": id, "style": style, "category": item["category"]})
	return out


## "40" for a price, for price tags.
static func amount_text(p: Dictionary) -> String:
	return str(int(p.get("amount", 0)))


static func currency_icon(currency: String) -> String:
	return GameState.CURRENCIES.get(currency, {}).get("icon", "sparkles")


static func currency_name(currency: String) -> String:
	return GameState.CURRENCIES.get(currency, {}).get("name", currency.capitalize())
