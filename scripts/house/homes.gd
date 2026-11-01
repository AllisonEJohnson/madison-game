class_name Homes
extends RefCounted
## The local player's homes: which they own, which one they live in (the one on
## their plot, which everyone sees), the rooms added to each, and the furniture
## in each. Kept in GameState's profile:
##   "homes": {type: [furniture]}   every home lived in so far, as left
##   "home": type                    the home lived in now
## Owning a home or a room means owning its shop key (see HomeCatalog), so they
## are bought with GameState.buy() like everything else.


static func owns_home(type: String) -> bool:
	return HomeCatalog.HOMES.has(type) and GameState.owns(HomeCatalog.home_key(type))


## The homes owned, in catalog order.
static func owned() -> Array:
	return HomeCatalog.types().filter(func(t): return owns_home(t))


## The home lived in now.
static func current() -> String:
	var type := str(GameState.profile.get("home", HomeCatalog.STARTER))
	return type if owns_home(type) else HomeCatalog.STARTER


## The add-ons built in a home.
static func rooms(type: String) -> Array:
	return HomeCatalog.addons(type).map(func(r): return r["id"]).filter(
			func(id): return GameState.owns(HomeCatalog.room_key(type, id)))


## The furniture in a home (what it comes with, before moving in).
static func items(type: String) -> Array:
	var all: Dictionary = GameState.profile.get("homes", {})
	return all[type] if all.has(type) else HomeCatalog.starter_items(type)


static func capacity(type: String) -> int:
	return HomeCatalog.capacity(type, rooms(type))


## The home lived in now, as it is sent to everyone: {"type", "rooms", "items"}.
static func active() -> Dictionary:
	var type := current()
	return {"type": type, "rooms": rooms(type), "items": items(type).duplicate(true)}


## Moves into an owned home. Its furniture is just as it was left.
static func move_in(type: String) -> bool:
	if not owns_home(type):
		return false
	var all: Dictionary = GameState.profile.get("homes", {})
	if not all.has(type):
		all[type] = HomeCatalog.starter_items(type)
	GameState.profile["homes"] = all
	GameState.profile["home"] = type
	GameState.save_profile()
	return true


## Keeps the furniture placed in the home lived in now.
static func set_items(list: Array) -> void:
	var type := current()
	var all: Dictionary = GameState.profile.get("homes", {})
	all[type] = HomeCatalog.clean_items(type, list)
	GameState.profile["homes"] = all
	GameState.save_profile()


## Shop keys that stay owned when the admin console takes back what was bought:
## the home lived in now and its rooms, so nobody is left without a home.
static func keys_in_use() -> Array:
	var type := current()
	var out := []
	if not HomeCatalog.price(HomeCatalog.home_key(type)).is_empty():
		out.append(HomeCatalog.home_key(type))
	for id in rooms(type):
		out.append(HomeCatalog.room_key(type, id))
	return out


## Labels for the outlines of rooms not built yet: add-on id -> "Garden Room\n300 Acorns".
static func plan_labels(type: String) -> Dictionary:
	var out := {}
	for r in HomeCatalog.addons(type):
		var key := HomeCatalog.room_key(type, r["id"])
		var p := ShopCatalog.price(key)
		var line := "Opens at level %d" % ShopCatalog.level_needed(key) if ShopCatalog.level_locked(key) \
				else "%s %s" % [ShopCatalog.amount_text(p), ShopCatalog.currency_name(p.get("currency", ""))]
		out[r["id"]] = "%s\n%s" % [r["name"], line]
	return out
