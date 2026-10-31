class_name PetCollection
extends RefCounted
## The local player's pets: which kinds they have, the one that comes along,
## and what each of the others was called and how it was doing.
##
## Cats, dogs and birds are everyone's from the start. Every other kind is
## found in the wild (see WildPets) and joins you when you make friends with
## it; most kinds can also be had at once for Stardust. One pet of each kind:
## each keeps its own name, coat and needs while it waits at home.
##
## Saved in GameState.profile: "pet" is the pet with you (as before), and
## "pets" maps each other kind you have to its saved state,
## {"fox": {"species": "fox", "coat": 0, "name": "Rusty", ..., "fullness": 80.0}}.
## Like the wallet, this lives in the device's save until a game server holds
## profiles; a server should then check adoptions and Stardust buys.

## Names of the lands where wild pets live, as said in a sentence.
const LANDS := {"town": "Hometown", "glade": "Starfall Glade", "sky": "the Sky Garden"}
## The XP source for making friends with a wild pet (see Levels.SOURCES).
const ADOPT_XP := "adopt_pet"


static func _pets() -> Dictionary:
	if not GameState.profile.get("pets") is Dictionary:
		GameState.profile["pets"] = {}
	return GameState.profile["pets"]


static func active_species() -> String:
	return PetBuilder.species_id(GameState.profile.get("pet", {}))


static func owns(species: String) -> bool:
	return PetBuilder.SPECIES.has(species) and (PetBuilder.is_home(species) or _pets().has(species)
			or species == active_species())


## Every kind the player has, in the catalog's order.
static func owned() -> Array:
	return PetBuilder.SPECIES.keys().filter(owns)


## How many wild kinds have been found, and how many there are.
static func found_count() -> int:
	return wild_kinds().filter(owns).size()


static func wild_kinds() -> Array:
	return PetBuilder.SPECIES.keys().filter(func(s): return not PetBuilder.is_home(s))


## The saved config of a kind you have (the one with you, or the one waiting
## at home), or a fresh one in its own colors.
static func config_of(species: String) -> Dictionary:
	if species == active_species():
		return GameState.profile["pet"]
	var saved = _pets().get(species)
	if saved is Dictionary:
		return saved
	return PetBuilder.new_config(species, 0, _default_name(species))


## What the pet of a kind is called ("" when you don't have one yet).
static func name_of(species: String) -> String:
	return str(config_of(species)["name"]) if owns(species) else ""


## The land a wild kind lives in, in words ("Starfall Glade"), or "".
static func where(species: String) -> String:
	return LANDS.get(PetBuilder.info(species).get("land", ""), "")


## The level that opens a wild kind's land (1 for Hometown).
static func land_level(species: String) -> int:
	return Levels.area_level(PetBuilder.info(species).get("land", ""))


## Makes friends with a wild pet. Returns false (and changes nothing) when
## you already have that kind or it isn't a real one.
static func adopt(species: String, pet_name: String, coat := 0) -> bool:
	if not PetBuilder.SPECIES.has(species) or owns(species):
		return false
	var config := PetBuilder.new_config(species, coat, pet_name)
	config["fullness"] = 80.0
	config["happiness"] = 100.0
	_pets()[species] = config
	GameState.save_profile()
	return true


## Pays Stardust for a kind that's for sale. Returns false (and changes
## nothing) when it's owned, wild-only, or there isn't enough Stardust.
## Like other premium things, it needs no level: Stardust is for getting ahead.
static func buy(species: String) -> bool:
	var price := PetBuilder.stardust_price(species)
	if price <= 0 or owns(species) or GameState.balance(ShopCatalog.STARDUST) < price:
		return false
	if not GameState.spend(ShopCatalog.STARDUST, price):
		return false
	return adopt(species, random_name())


## Brings another of your pets along. `current` is the state of the pet with
## you now (Pet.save_state()), which waits at home with its needs. Returns the
## new pet's config, or {} when you don't have that kind.
static func switch_to(species: String, current: Dictionary) -> Dictionary:
	if not owns(species):
		return {}
	var here := PetBuilder.species_id(current)
	if here != species:
		_pets()[here] = _with_needs(current)
	var next := config_of(species).duplicate()
	_pets().erase(species)
	GameState.profile["pet"] = _with_needs(next)
	GameState.save_profile()
	return GameState.profile["pet"]


## Renames or restyles a pet you have (from the character creator).
static func update(config: Dictionary) -> void:
	var species := PetBuilder.species_id(config)
	if species == active_species():
		GameState.profile["pet"] = _with_needs(config)
	elif owns(species):
		_pets()[species] = _with_needs(config)
	GameState.save_profile()


static func random_name(rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	return SafeNames.PET_NAMES[rng.randi() % SafeNames.PET_NAMES.size()]


## A home pet you've never brought along still needs a name: one picked from
## its kind, so it stays the same until you change it.
static func _default_name(species: String) -> String:
	return SafeNames.PET_NAMES[absi(species.hash()) % SafeNames.PET_NAMES.size()]


static func _with_needs(config: Dictionary) -> Dictionary:
	var out := PetBuilder.sanitize(config)
	out["fullness"] = clampf(float(config.get("fullness", 80.0)), 0.0, 100.0)
	out["happiness"] = clampf(float(config.get("happiness", 80.0)), 0.0, 100.0)
	return out


## For the admin console and tests: forgets every wild pet (the one with you
## goes back to being a cat if it was wild).
static func reset() -> void:
	GameState.profile["pets"] = {}
	if not PetBuilder.is_home(active_species()):
		GameState.profile["pet"] = _with_needs(PetBuilder.default_config())
	GameState.save_profile()


# --- Saved data -------------------------------------------------------------------

## The "pets" of a loaded save, checked: only real kinds, each sanitized.
## (A save from before wild pets with a bunny or a dragon along keeps it as
## the kind it turned into, see PetBuilder.LEGACY: the pet with you is always
## yours, so no one loses a pet.)
static func clean_save(data: Dictionary) -> Dictionary:
	var out := {}
	var saved = data.get("pets")
	if saved is Dictionary:
		for species in saved:
			if species is String and PetBuilder.SPECIES.has(species) and saved[species] is Dictionary:
				var config: Dictionary = saved[species].duplicate()
				config["species"] = species
				out[species] = _with_needs(config)
	return out


## A picture of a pet for cards and buttons. Its name doesn't change the
## picture, so it isn't part of the key; pictures of licensed models are kept
## on disk.
static func thumb(config: Dictionary) -> Texture2D:
	var c := PetBuilder.sanitize(config)
	var key := "pet:%s:%d:%s:%s:%s" % [c["species"], c["coat"], c["color"], c["accent"], c["collar"]]
	return Thumbs.texture(key, func(): return PetBuilder.build(c), "pet", PetBuilder.has_art(c))
