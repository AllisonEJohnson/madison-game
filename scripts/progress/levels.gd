class_name Levels
extends RefCounted
## The rules of leveling up: how much XP each level takes, what playing is
## worth, and what every level brings. The Progress autoload keeps the
## player's XP and hands out the rewards; everything here is plain data and
## math, so it is easy to tune and to test.
##
## There is one player level (no skill tracks). XP comes from playing:
## picking up acorns, Star Chase, caring for your pet, making friends with
## wild pets, decorating, exploring a land for the first time, and coming back
## each day. Each new level pays some
## Acorns, and many also open something: a land, new things in the shop, or a
## gift. Shop items gated by level are listed in ShopCatalog (its "level" key).

const MAX_LEVEL := 50

## What playing is worth. "xp" per time (or per star); "cooldown" is seconds
## before the same thing pays again; "daily" caps how many times a day it pays.
## "how" and "icon" describe it in the level card.
const SOURCES := {
	"acorn": {"xp": 3, "icon": "chestnut", "how": "Pick up an acorn"},
	"golden_acorn": {"xp": 10, "icon": "chestnut", "how": "Find a golden acorn"},
	"star": {"xp": 2, "icon": "glowing_star", "how": "Catch a star in Star Chase"},
	"feed_pet": {"xp": 4, "cooldown": 60.0, "icon": "meat_on_bone", "how": "Feed your pet"},
	"play_pet": {"xp": 4, "cooldown": 60.0, "icon": "tennis", "how": "Play with your pet"},
	"adopt_pet": {"xp": 40, "icon": "paw_prints", "how": "Make friends with a wild pet"},
	"decorate": {"xp": 2, "daily": 20, "icon": "couch_and_lamp", "how": "Put something in your home"},
	"explore": {"xp": 40, "icon": "compass", "how": "Visit a new place"},
	"daily": {"xp": 25, "daily": 1, "icon": "sunflower", "how": "Come play each day"},
}
## The order the level card lists them in (golden acorns are a surprise).
const SOURCE_ORDER := ["acorn", "star", "feed_pet", "play_pet", "adopt_pet", "decorate", "explore", "daily"]

## Places that open at a level. Each is reached through a portal (see World).
const AREAS := {
	"glade": {"name": "Starfall Glade", "level": 2, "icon": "sparkles"},
	"sky": {"name": "Sky Garden", "level": 5, "icon": "rainbow"},
}

## Things given for free on reaching a level, as shop keys. A gift that isn't
## a real item (say, the shape avatar's clothes when the art is missing) is
## skipped. Giving away things that cost Acorns makes them feel special.
const GIFTS := {
	3: ["furniture:toy_box:1"],
	5: ["avatar:costume:1"], # Bunny
	7: ["furniture:pet_bed:1"],
	10: ["avatar:costume:6"], # Penguin
	12: ["furniture:piano:0"],
	15: ["avatar:costume:14"], # Pirate
	20: ["furniture:arcade:0"],
	25: ["avatar:costume:11"], # Explorer
}

## Star Boost: twice the XP for a while, bought with Stardust. Premium makes
## you level faster; it never buys levels or random prizes.
const BOOST_COST := 30
const BOOST_MINUTES := 30
const BOOST_MULTIPLIER := 2
## Buying more boosts adds time, up to this much in total.
const BOOST_MAX_MINUTES := 240


## XP needed to go from `level` to the next one: 50, then 25 more each level.
static func xp_to_next(level: int) -> int:
	return 50 + 25 * (clampi(level, 1, MAX_LEVEL) - 1)


## Total XP at the start of a level (0 for level 1).
static func xp_at(level: int) -> int:
	var n := clampi(level, 1, MAX_LEVEL) - 1
	# Sum of 50 + 25 * k for k in 0..n-1.
	return 50 * n + 25 * n * (n - 1) / 2


static func max_xp() -> int:
	return xp_at(MAX_LEVEL)


static func level_for(xp: int) -> int:
	var level := 1
	while level < MAX_LEVEL and xp >= xp_at(level + 1):
		level += 1
	return level


## {level, into (XP into this level), need (XP this level takes, 0 at the top)}.
static func progress(xp: int) -> Dictionary:
	var level := level_for(xp)
	if level >= MAX_LEVEL:
		return {"level": level, "into": 0, "need": 0}
	return {"level": level, "into": xp - xp_at(level), "need": xp_to_next(level)}


## Acorns paid for reaching a level.
static func reward_acorns(level: int) -> int:
	return 20 + 5 * level


## What reaching a level brings, for the level-up card and the level card:
## [{kind: "acorns" | "area" | "gift" | "shop", icon, text, key?, amount?, area?}].
static func rewards(level: int) -> Array:
	var out := []
	if level < 2 or level > MAX_LEVEL:
		return out
	for area in AREAS:
		if int(AREAS[area]["level"]) == level:
			out.append({"kind": "area", "area": area, "icon": AREAS[area]["icon"],
				"text": "%s is open!" % AREAS[area]["name"]})
			var pets := PetBuilder.wild_in(area).map(func(s): return PetBuilder.SPECIES[s]["name"].to_lower())
			if not pets.is_empty():
				out.append({"kind": "pets", "icon": "paw_prints", "text": "Wild pets to find: %s" % _list(pets)})
	for key in GIFTS.get(level, []):
		if ShopCatalog.is_item(key):
			out.append({"kind": "gift", "key": key, "icon": "wrapped_gift", "text": "A gift: %s" % item_name(key)})
	var shop := ShopCatalog.unlocked_at(level)
	if not shop.is_empty():
		out.append({"kind": "shop", "icon": "shopping_bags", "text": "New in the shop: %s" % _list(shop)})
	out.append({"kind": "acorns", "amount": reward_acorns(level), "icon": "chestnut",
		"text": "%d Acorns" % reward_acorns(level)})
	return out


## The next few levels that open something more than Acorns, for "Coming up".
## [{level, rewards}].
static func upcoming(from_level: int, count := 3) -> Array:
	var out := []
	for level in range(from_level + 1, MAX_LEVEL + 1):
		var list := rewards(level).filter(func(r): return r["kind"] != "acorns")
		if not list.is_empty():
			out.append({"level": level, "rewards": list})
			if out.size() >= count:
				break
	return out


## The level a place opens at (1 when it is always open).
static func area_level(area: String) -> int:
	return int(AREAS.get(area, {}).get("level", 1))


## A shop item's name for a reward line: "Toys" or "Bunny costume".
static func item_name(key: String) -> String:
	var parts := key.split(":")
	if parts.size() != 3:
		return key
	if parts[0] == "furniture":
		return str(FurnitureCatalog.ITEMS.get(parts[1], {}).get("name", parts[1]))
	var name := ShopCatalog.clothes_name(parts[1], int(parts[2]))
	return "%s costume" % name if parts[1] == "costume" else name


## "a, b and c".
static func _list(words: Array) -> String:
	if words.size() <= 1:
		return "".join(words)
	return ", ".join(words.slice(0, words.size() - 1)) + " and " + str(words[-1])


## Today's date as text, for daily limits.
static func today() -> String:
	return Time.get_date_string_from_system()


# --- Saved data -------------------------------------------------------------------

## The profile keys leveling adds, for a new player.
static func new_save() -> Dictionary:
	return {
		"xp": 0,
		# The highest level whose rewards were given, so they're never given twice.
		"rewarded_level": 1,
		# Lands and places visited, for the first-visit XP.
		"visited": [],
		# Daily limits: {"date": "2026-10-31", "counts": {"decorate": 3}}.
		"xp_today": {"date": "", "counts": {}},
		# Unix time the Star Boost runs out.
		"boost_until": 0,
	}


## The leveling keys of a loaded save, checked and clamped.
static func clean_save(data: Dictionary) -> Dictionary:
	var out := new_save()
	var xp = data.get("xp")
	out["xp"] = clampi(int(xp), 0, max_xp()) if xp is float or xp is int else 0
	var rewarded = data.get("rewarded_level")
	# Saves from before levels: nothing has been given yet, so start from level 1.
	out["rewarded_level"] = clampi(int(rewarded), 1, MAX_LEVEL) if rewarded is float or rewarded is int else 1
	var visited = data.get("visited")
	if visited is Array:
		for place in visited:
			if place is String and AREAS.has(place) and not (place in out["visited"]):
				out["visited"].append(place)
	var today_data = data.get("xp_today")
	if today_data is Dictionary and today_data.get("date") is String and today_data.get("counts") is Dictionary:
		var counts := {}
		for source in today_data["counts"]:
			var n = today_data["counts"][source]
			if SOURCES.has(source) and (n is float or n is int):
				counts[source] = clampi(int(n), 0, 1000)
		out["xp_today"] = {"date": str(today_data["date"]).left(10), "counts": counts}
	var boost = data.get("boost_until")
	if boost is float or boost is int:
		# Never more than the longest boost from now, in case the clock was changed.
		out["boost_until"] = clampi(int(boost), 0, int(Time.get_unix_time_from_system()) + BOOST_MAX_MINUTES * 60)
	return out
