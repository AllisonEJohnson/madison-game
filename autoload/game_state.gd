extends Node
## Holds the local player's saved profile (name, avatar, pet, house, wallet,
## level) and registers input actions so the project file stays small. The
## level's own logic is in the Progress autoload.

## Fires when either currency balance or the membership changes.
signal wallet_changed
## Fires when something is bought or unlocked.
signal owned_changed
## Fires with the amount whenever currency is earned by playing, for the HUD.
signal earned(currency: String, amount: int)

const SAVE_PATH := "user://profile.json"
const MAX_FAVORITES := 300
const MAX_RECENT := 30
## The two currencies: Acorns are earned by playing; Stardust is the premium
## currency, bought with real money once payments exist (for now only the
## admin console grants it). Both live in this device's save until a game
## server holds them, which has to happen before real purchases go live.
const CURRENCIES := {
	"acorns": {"name": "Acorns", "icon": "chestnut"},
	"stardust": {"name": "Stardust", "icon": "shooting_star"},
}
const MAX_BALANCE := 9_999_999
const MAX_OWNED := 3000

var profile := {}


func _ready() -> void:
	_register_inputs()
	load_profile()


func default_profile() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return {
		"name_parts": SafeNames.random_name_parts(rng),
		"avatar": AvatarBuilder.default_config(),
		"pet": PetBuilder.default_config(),
		# The furniture in each home lived in, and the one lived in now (see Homes).
		"homes": HomeCatalog.new_save()["homes"],
		"home": HomeCatalog.STARTER,
		# Build-mode keys ("sofa:3"). Only this device sees them.
		"favorites": [],
		"recent": [],
		"acorns": 0,
		"stardust": 0,
		# Unix time the membership runs out; 0 means not a member.
		"member_until": 0,
		# Shop keys of things bought ("furniture:sofa:3", "avatar:hat:12").
		# Free things are owned without being listed (see ShopCatalog).
		"owned": [],
		# The most stars caught in one game of Star Chase.
		"chase_best": 0,
	}.merged(Levels.new_save())


func load_profile() -> void:
	profile = default_profile()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary:
		return
	profile["name_parts"] = SafeNames.clean_name_parts(data.get("name_parts"))
	profile["avatar"] = AvatarBuilder.sanitize(data.get("avatar"))
	# The pets waiting at home; the one with you is "pet" (see PetCollection).
	profile["pets"] = PetCollection.clean_save(data)
	var pet := PetBuilder.sanitize(data.get("pet"))
	if data.get("pet") is Dictionary:
		pet["fullness"] = float(data["pet"].get("fullness", 80.0))
		pet["happiness"] = float(data["pet"].get("happiness", 80.0))
	profile["pet"] = pet
	profile.merge(HomeCatalog.clean_save(data), true)
	profile["favorites"] = _clean_keys(data.get("favorites"), MAX_FAVORITES)
	profile["recent"] = _clean_keys(data.get("recent"), MAX_RECENT)
	for currency in CURRENCIES:
		profile[currency] = _clean_amount(data.get(currency))
	var member_until = data.get("member_until")
	profile["member_until"] = maxi(0, int(member_until)) if member_until is float else 0
	if data.has("owned"):
		profile["owned"] = _clean_owned(data.get("owned"))
	else:
		# Saved before the shop: keep everything already worn or placed.
		profile["owned"] = ShopCatalog.priced_keys_in(HomeCatalog.all_items(profile), profile["avatar"])
	profile["chase_best"] = _clean_amount(data.get("chase_best"))
	profile.merge(Levels.clean_save(data), true)


func save_profile() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(profile, "\t"))


func set_favorite(key: String, on: bool) -> void:
	var favorites: Array = profile["favorites"]
	favorites.erase(key)
	if on and favorites.size() < MAX_FAVORITES:
		favorites.append(key)
	save_profile()


## Moves `key` to the front of the recently used list.
func add_recent(key: String) -> void:
	var recent: Array = profile["recent"]
	recent.erase(key)
	recent.push_front(key)
	if recent.size() > MAX_RECENT:
		recent.resize(MAX_RECENT)
	save_profile()


# --- Wallet and membership ---------------------------------------------------------

func balance(currency: String) -> int:
	return int(profile.get(currency, 0))


## Adds (or, with a negative amount, takes away) currency, never going below 0.
func grant(currency: String, amount: int) -> void:
	if not CURRENCIES.has(currency):
		return
	profile[currency] = clampi(balance(currency) + amount, 0, MAX_BALANCE)
	save_profile()
	wallet_changed.emit()


## Pays `amount` if the balance covers it. Returns false (and changes nothing)
## when it doesn't.
func spend(currency: String, amount: int) -> bool:
	if not CURRENCIES.has(currency) or amount < 0 or balance(currency) < amount:
		return false
	profile[currency] = balance(currency) - amount
	save_profile()
	wallet_changed.emit()
	return true


## True when the item is free or has been bought.
func owns(key: String) -> bool:
	return ShopCatalog.is_free(key) or key in profile["owned"]


func can_afford(key: String) -> bool:
	var p := ShopCatalog.price(key)
	return p.is_empty() or balance(p["currency"]) >= int(p["amount"])


## Pays for an item and keeps it. Returns false (and changes nothing) when it
## is free, already owned, not a real item, needs a higher level, or the
## balance is too low.
func buy(key: String) -> bool:
	var p := ShopCatalog.price(key)
	if p.is_empty() or owns(key) or not ShopCatalog.is_item(key) or ShopCatalog.level_locked(key):
		return false
	# A room can only be added to a home you own.
	if not owns(HomeCatalog.requires(key)):
		return false
	if not spend(p["currency"], int(p["amount"])):
		return false
	unlock([key])
	return true


## Gives items without paying (admin console, tests).
func unlock(keys: Array) -> void:
	var owned: Array = profile["owned"]
	for key in keys:
		if ShopCatalog.is_item(key) and not ShopCatalog.is_free(key) and not (key in owned) and owned.size() < MAX_OWNED:
			owned.append(key)
	save_profile()
	owned_changed.emit()


## Takes back everything bought, except what is worn or placed right now and
## the home lived in.
func reset_owned() -> void:
	var home_keys := Homes.keys_in_use()
	profile["owned"] = ShopCatalog.priced_keys_in(HomeCatalog.all_items(profile), profile["avatar"]) + home_keys
	save_profile()
	owned_changed.emit()


## Currency earned by playing (acorns found, games won). Like grant(), plus
## the `earned` signal so the HUD can celebrate.
func earn(currency: String, amount: int) -> void:
	if amount <= 0:
		return
	grant(currency, amount)
	earned.emit(currency, amount)


## Keeps a best score (like "chase_best") and says whether `score` beat it.
func record_best(key: String, score: int) -> bool:
	if score <= int(profile.get(key, 0)):
		return false
	profile[key] = score
	save_profile()
	return true


func is_member() -> bool:
	return int(profile.get("member_until", 0)) > int(Time.get_unix_time_from_system())


## Days of membership left, rounded up; 0 when not a member.
func member_days_left() -> int:
	var left := int(profile.get("member_until", 0)) - int(Time.get_unix_time_from_system())
	return ceili(left / 86400.0) if left > 0 else 0


## Adds days to the membership (counting from now if it had run out). A
## negative or zero number of days ends it.
func grant_membership(days: int) -> void:
	var now := int(Time.get_unix_time_from_system())
	if days <= 0:
		profile["member_until"] = 0
	else:
		profile["member_until"] = maxi(int(profile.get("member_until", 0)), now) + days * 86400
	save_profile()
	wallet_changed.emit()


static func _clean_amount(data: Variant) -> int:
	return clampi(int(data), 0, MAX_BALANCE) if data is float or data is int else 0


static func _clean_owned(data: Variant) -> Array:
	var out := []
	if data is Array:
		var seen := {}
		for key in data:
			if key is String and not seen.has(key) and out.size() < MAX_OWNED and ShopCatalog.is_item(key) \
					and not ShopCatalog.is_free(key):
				seen[key] = true
				out.append(key)
	return out


static func _clean_keys(data: Variant, limit: int) -> Array:
	var out := []
	if data is Array:
		for key in data:
			if key is String and key.length() <= 64 and not (key in out) and out.size() < limit:
				out.append(key)
	return out


func display_name() -> String:
	return SafeNames.display_name(profile.get("name_parts"))


## The part of the profile other players are allowed to see.
func public_profile() -> Dictionary:
	return {
		"name_parts": profile["name_parts"],
		"avatar": profile["avatar"],
		"pet": PetBuilder.sanitize(profile["pet"]),
		"home": Homes.active(),
	}


func _register_inputs() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"pet_feed": [KEY_F],
		"pet_play": [KEY_G],
		"build_mode": [KEY_B],
		"build_rotate": [KEY_R],
		"build_style": [KEY_E],
		"go_home": [KEY_H],
		# Uses a shop or game you are standing at. E is also "next look" while decorating.
		"interact": [KEY_E],
		"quick_chat": [KEY_T],
		"menu": [KEY_ESCAPE],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)
