class_name HomeCatalog
extends RefCounted
## The homes players can own. Every home is ready-built: it starts with a few
## rooms, and more rooms can be added later. Players never place walls or
## floors; they make a home theirs with furniture (see FurnitureCatalog).
##
## Rooms are rectangles on the plot's 12x12 grid, [x, z, width, depth], with z
## growing toward the street. Walls go around every room. Where two rooms meet,
## the wall gets a doorway at the "link" edge (or in the middle of the shared
## wall when neither room names one). A "deck" is an open-air room: a floor with
## railings instead of walls, and "gaps" in the railing for a gate. A "tent"
## gets a ridge pole and canvas ends above its walls. An edge is [x, z, side],
## side being n, w, s or e of that cell.
##
## In town you only see a home from outside. Its front doors (a room's "door"
## that opens onto the yard) and its gates are entrances: walking into one takes
## you inside, to a space of its own (see House), and walking into it from
## inside takes you back out.
##
## Rooms with a "price" are add-ons, bought one by one; the rest come with the
## home. Prices are {"acorns": n, "level": l} (Acorns, once you reach level l)
## or {"stardust": n} (Stardust, at any level, because premium is for getting
## ahead faster). Each home holds "capacity" pieces of furniture, and each room
## added makes room for its own "capacity" more.
##
## Shop keys: "home:<type>:0" for a home and "room:<type>:<n>" for its n-th
## add-on; ShopCatalog asks this file for their prices. This file must not use
## the autoloads, because the web build's art pruning loads it without them.

const STARTER := "sprout_cottage"
const PLOT := 12
const SIDES := {"n": 0, "w": 1, "s": 2, "e": 3}
## Cell steps toward each side.
const STEPS := {"n": Vector2i(0, -1), "w": Vector2i(-1, 0), "s": Vector2i(0, 1), "e": Vector2i(1, 0)}
const FANTASY := "Fantasy/prefabs/assets/"
const SAVANNA := "Animals/prefabs/assets/assets/savanna_assets/"
## The signpost in front of every plot.
const SIGNPOST := FANTASY + "prop/pointer_001"

## Fixed things around a home ("decor"): a model on the cells it covers
## [x, z, width, depth], scaled to "height" meters. Nothing can be placed on
## those cells. "shape" names the stand-in drawn when the art isn't installed.
const HOMES := {
	"sprout_cottage": {
		"name": "Sprout Cottage", "icon": "house_with_garden",
		"about": "A cozy cottage with a sunny front porch. Everyone starts here.",
		"wall": "f1e7d6", "trim": "e07a5f", "roof": "c8553d", "floor": "c9a77c", "deck": "d8b98a", "path": "b8b2a7",
		"height": 2.6, "capacity": 40,
		"rooms": [
			{"id": "main", "name": "Main Room", "rect": [3, 3, 6, 6], "door": [5, 8, "s"],
				"windows": [[3, 5, "w"], [8, 6, "e"], [3, 8, "s"], [8, 8, "s"]]},
			{"id": "porch", "name": "Front Porch", "rect": [3, 9, 6, 2], "deck": true, "gaps": [[5, 10, "s"]]},
			{"id": "garden", "name": "Garden Room", "rect": [9, 3, 3, 6], "link": [8, 6, "e"], "floor": "cfe3bf",
				"windows": [[10, 3, "n"], [11, 4, "e"], [11, 5, "e"], [11, 6, "e"], [11, 7, "e"], [10, 8, "s"]],
				"price": {"acorns": 300, "level": 3}, "capacity": 20},
			{"id": "bedroom", "name": "Bedroom", "rect": [0, 3, 3, 6], "link": [3, 5, "w"], "floor": "d9b48c",
				"windows": [[1, 3, "n"], [0, 5, "w"], [0, 6, "w"], [1, 8, "s"]],
				"price": {"acorns": 450, "level": 4}, "capacity": 20},
			{"id": "playroom", "name": "Playroom", "rect": [3, 0, 6, 3], "link": [6, 3, "n"], "floor": "f0d48e",
				"windows": [[4, 0, "n"], [7, 0, "n"], [3, 1, "w"], [8, 1, "e"]],
				"price": {"stardust": 30}, "capacity": 25},
		],
		"walk": [[5, 11]],
		"decor": [],
	},
	"oak_lookout": {
		"name": "Oak Lookout", "icon": "deciduous_tree",
		"about": "A log cabin under a giant oak, with a deck up by its branches.",
		"wall": "c58f5c", "trim": "4f8a3c", "roof": "5e8f45", "floor": "a47548", "deck": "b98c5c", "path": "a89f8f",
		"height": 2.6, "capacity": 45, "price": {"acorns": 1500, "level": 6},
		"rooms": [
			{"id": "den", "name": "Den", "rect": [1, 4, 6, 5], "door": [4, 8, "s"],
				"windows": [[1, 5, "w"], [1, 7, "w"], [2, 8, "s"], [6, 8, "s"], [2, 4, "n"]]},
			{"id": "kitchen", "name": "Oak Kitchen", "rect": [7, 4, 3, 5], "link": [6, 6, "e"], "floor": "b88a5c",
				"windows": [[9, 5, "e"], [9, 7, "e"], [8, 8, "s"]]},
			{"id": "deck", "name": "Lookout Deck", "rect": [7, 0, 4, 4], "deck": true, "link": [9, 4, "n"],
				"price": {"acorns": 500, "level": 6}, "capacity": 15},
			{"id": "loft", "name": "Loft Bedroom", "rect": [1, 1, 5, 3], "link": [4, 4, "n"], "floor": "b5875a",
				"windows": [[2, 1, "n"], [4, 1, "n"], [1, 2, "w"], [5, 2, "e"]],
				"price": {"acorns": 700, "level": 7}, "capacity": 20},
			{"id": "nook", "name": "Reading Nook", "rect": [10, 4, 2, 4], "link": [9, 6, "e"], "floor": "8f6a48",
				"windows": [[11, 5, "e"], [11, 6, "e"]],
				"price": {"stardust": 35}, "capacity": 15},
		],
		"walk": [[4, 9], [4, 10], [4, 11]],
		"decor": [
			{"model": FANTASY + "vegetation/big_fabulous_tree_003", "cells": [8, 1, 2, 2], "height": 7.5, "shape": "tree"},
			{"model": FANTASY + "prop/barrel_001", "cells": [0, 9, 1, 1], "height": 0.8, "shape": "barrel"},
			{"model": FANTASY + "prop/log_002", "cells": [6, 10, 2, 1], "height": 0.5, "shape": "log", "turn": 1},
		],
		"starter": [["sofa", 1, 4, 0, 0], ["lamp", 3, 4, 0, 0], ["bookshelf", 6, 4, 0, 0], ["rug", 2, 5, 0, 0],
			["armchair", 3, 6, 2, 0], ["plant", 1, 8, 0, 0], ["fridge", 7, 4, 0, 0], ["stove", 8, 4, 0, 0],
			["table", 8, 6, 0, 0], ["chair", 9, 6, 3, 0], ["chair", 8, 7, 2, 0]],
	},
	"safari_camp": {
		"name": "Sunpatch Safari Camp", "icon": "camping",
		"about": "Canvas tents around a crackling campfire, with a platform for spotting animals.",
		"wall": "ecdcb4", "trim": "d9822b", "roof": "d9c49a", "floor": "d8c49a", "deck": "b48a5c", "path": "d6c08f",
		"height": 2.1, "capacity": 45, "price": {"acorns": 2500, "level": 9},
		"rooms": [
			{"id": "big_tent", "name": "Big Tent", "rect": [1, 5, 4, 4], "door": [4, 6, "e"], "tent": true,
				"windows": [[1, 6, "w"], [2, 8, "s"], [2, 5, "n"]]},
			{"id": "cook_tent", "name": "Cook Tent", "rect": [8, 5, 3, 4], "door": [8, 6, "w"], "floor": "cdb88c", "tent": true,
				"windows": [[10, 6, "e"], [9, 8, "s"]]},
			{"id": "sleep_tent", "name": "Sleeping Tent", "rect": [1, 1, 4, 3], "door": [3, 3, "s"], "floor": "e0cfa8", "tent": true,
				"windows": [[1, 2, "w"], [2, 1, "n"]],
				"price": {"acorns": 600, "level": 9}, "capacity": 15},
			{"id": "explorer_tent", "name": "Explorer Tent", "rect": [8, 9, 3, 3], "door": [8, 10, "w"], "tent": true,
				"floor": "cfc29a", "windows": [[10, 10, "e"]],
				"price": {"acorns": 800, "level": 10}, "capacity": 15},
			{"id": "platform", "name": "Lookout Platform", "rect": [7, 1, 4, 3], "deck": true, "gaps": [[8, 3, "s"]],
				"price": {"stardust": 40}, "capacity": 10},
		],
		"walk": [[6, 8], [6, 9], [6, 10], [6, 11]],
		"decor": [
			{"model": FANTASY + "prop/bonfire_002", "cells": [6, 6, 1, 1], "height": 0.6, "shape": "fire", "light": "ffa040"},
			{"model": FANTASY + "prop/log_002", "cells": [5, 7, 1, 1], "height": 0.45, "shape": "log"},
			{"model": FANTASY + "prop/log_002", "cells": [7, 5, 1, 1], "height": 0.45, "shape": "log"},
			{"model": SAVANNA + "savanna_tree_02", "cells": [0, 10, 1, 1], "height": 4.5, "shape": "tree"},
			{"model": SAVANNA + "savanna_tree_04", "cells": [11, 0, 1, 1], "height": 4.0, "shape": "tree"},
		],
		"starter": [["sofa", 1, 5, 0, 0], ["rug", 2, 6, 0, 0], ["lamp", 3, 5, 0, 0], ["plant", 1, 8, 0, 0],
			["stove", 9, 5, 0, 0], ["fridge", 10, 5, 0, 0], ["table", 9, 7, 0, 0], ["chair", 10, 7, 3, 0]],
	},
	"toadstool_hollow": {
		"name": "Toadstool Hollow", "icon": "mushroom",
		"about": "A magical hideaway among giant mushrooms and glowing lamps.",
		"wall": "e9d8f4", "trim": "e2504c", "roof": "e2504c", "roof_spots": true, "floor": "a5c983", "deck": "b9d98f", "path": "c9bfdf",
		"height": 2.6, "capacity": 50, "price": {"stardust": 120},
		"rooms": [
			{"id": "cap_room", "name": "Cap Room", "rect": [2, 4, 6, 5], "door": [4, 8, "s"],
				"windows": [[2, 5, "w"], [2, 7, "w"], [6, 8, "s"], [3, 4, "n"], [7, 4, "n"]]},
			{"id": "moss_nook", "name": "Mossy Nook", "rect": [8, 4, 2, 4], "link": [7, 5, "e"], "floor": "94bd74",
				"windows": [[9, 5, "e"], [9, 6, "e"]]},
			{"id": "glow_garden", "name": "Glow Garden", "rect": [8, 8, 4, 3], "deck": true, "link": [8, 7, "s"],
				"gaps": [[10, 10, "s"]], "price": {"acorns": 400, "level": 3}, "capacity": 15},
			{"id": "spore_loft", "name": "Spore Loft", "rect": [3, 1, 5, 3], "link": [5, 4, "n"], "floor": "b7d398",
				"windows": [[4, 1, "n"], [6, 1, "n"], [3, 2, "w"], [7, 2, "e"]],
				"price": {"stardust": 40}, "capacity": 20},
		],
		"walk": [[4, 9], [4, 10], [4, 11]],
		"decor": [
			{"model": FANTASY + "vegetation/fabulous_mushroom_041", "cells": [0, 0, 2, 2], "height": 4.2, "shape": "mushroom", "turn": 1},
			{"model": FANTASY + "vegetation/fabulous_mushroom_041", "cells": [10, 0, 2, 2], "height": 3.0, "shape": "mushroom"},
			{"model": FANTASY + "prop/lamp_magic_001", "cells": [3, 9, 1, 1], "height": 1.8, "shape": "lamp", "light": "c9a2ff"},
			{"model": FANTASY + "prop/lamp_magic_001", "cells": [5, 9, 1, 1], "height": 1.8, "shape": "lamp", "light": "c9a2ff"},
		],
		"starter": [["bed", 2, 4, 0, 0], ["lamp", 4, 4, 0, 0], ["rug", 4, 6, 0, 0], ["armchair", 6, 6, 3, 0],
			["plant", 7, 8, 0, 0], ["plant", 2, 8, 0, 0], ["bookshelf", 8, 4, 0, 0], ["toy_box", 9, 7, 0, 0]],
	},
}


static func types() -> Array:
	return HOMES.keys()


static func info(type: String) -> Dictionary:
	return HOMES.get(type, {})


static func home_name(type: String) -> String:
	return str(info(type).get("name", type.capitalize()))


## The rooms that come with a home.
static func base_rooms(type: String) -> Array:
	return info(type).get("rooms", []).filter(func(r): return not r.has("price"))


## The rooms that can be added, in shop order (their index is in the shop key).
static func addons(type: String) -> Array:
	return info(type).get("rooms", []).filter(func(r): return r.has("price"))


static func room(type: String, id: String) -> Dictionary:
	for r in info(type).get("rooms", []):
		if r["id"] == id:
			return r
	return {}


static func addon_index(type: String, id: String) -> int:
	var list := addons(type)
	for i in list.size():
		if list[i]["id"] == id:
			return i
	return -1


# --- Shop keys and prices -----------------------------------------------------------

static func home_key(type: String) -> String:
	return "home:%s:0" % type


static func room_key(type: String, id: String) -> String:
	return "room:%s:%d" % [type, addon_index(type, id)]


## {kind: "home" | "room", type, room (the add-on's id, for rooms)}, or {} when
## the key isn't a real home or room.
static func parse_key(key: String) -> Dictionary:
	var parts := key.split(":")
	if parts.size() != 3 or not HOMES.has(parts[1]) or not parts[2].is_valid_int():
		return {}
	var n := int(parts[2])
	if parts[0] == "home" and n == 0:
		return {"kind": "home", "type": parts[1]}
	var list := addons(parts[1])
	if parts[0] == "room" and n >= 0 and n < list.size():
		return {"kind": "room", "type": parts[1], "room": list[n]["id"]}
	return {}


static func is_item(key: String) -> bool:
	return not parse_key(key).is_empty()


static func _price_rule(key: String) -> Dictionary:
	var k := parse_key(key)
	if k.is_empty():
		return {}
	return info(k["type"]).get("price", {}) if k["kind"] == "home" else room(k["type"], k["room"]).get("price", {})


## {"currency", "amount"} like ShopCatalog.price(), or {} when free.
static func price(key: String) -> Dictionary:
	var rule := _price_rule(key)
	if rule.has("stardust"):
		return {"currency": "stardust", "amount": int(rule["stardust"])}
	if rule.has("acorns"):
		return {"currency": "acorns", "amount": int(rule["acorns"])}
	return {}


## The level needed to buy it with Acorns (1 for free and Stardust things).
static func level(key: String) -> int:
	var rule := _price_rule(key)
	return maxi(int(rule.get("level", 1)), 1) if rule.has("acorns") else 1


## What has to be owned before buying this: a room needs its home. "" for none.
static func requires(key: String) -> String:
	var k := parse_key(key)
	return home_key(k["type"]) if k.get("kind") == "room" else ""


## "Oak Lookout" or "Garden Room".
static func item_name(key: String) -> String:
	var k := parse_key(key)
	if k.is_empty():
		return ""
	return home_name(k["type"]) if k["kind"] == "home" else str(room(k["type"], k["room"])["name"])


## Every home and room key, homes first.
static func all_keys() -> Array:
	var out := []
	for type in HOMES:
		out.append(home_key(type))
	for type in HOMES:
		for r in addons(type):
			out.append(room_key(type, r["id"]))
	return out


## Homes and rooms that can be bought from a level on, as lines for the level
## cards: {"icon", "text": "New home: Oak Lookout"}.
static func unlocked_at(at_level: int) -> Array:
	var out := []
	for key in all_keys():
		if price(key).get("currency") == "acorns" and level(key) == at_level:
			var k := parse_key(key)
			out.append({"icon": info(k["type"])["icon"], "text": "New home: %s" % home_name(k["type"])
					if k["kind"] == "home" else "New room for the %s: %s" % [home_name(k["type"]), item_name(key)]})
	return out


# --- One home ----------------------------------------------------------------------

## The rooms a home has with these add-ons built, base rooms first.
static func built_rooms(type: String, addon_ids: Array) -> Array:
	return info(type).get("rooms", []).filter(func(r): return not r.has("price") or r["id"] in addon_ids)


## How many pieces of furniture fit with these add-ons built.
static func capacity(type: String, addon_ids: Array) -> int:
	var total := int(info(type).get("capacity", 40))
	for r in addons(type):
		if r["id"] in addon_ids:
			total += int(r.get("capacity", 0))
	return total


## Cells covered by decor, where nothing can be placed: Vector2i -> true.
static func blocked(type: String) -> Dictionary:
	var out := {}
	for d in info(type).get("decor", []):
		var c: Array = d["cells"]
		for x in range(c[0], c[0] + c[2]):
			for z in range(c[1], c[1] + c[3]):
				out[Vector2i(x, z)] = true
	return out


## The furniture a home comes with. Every look is free, so moving in never
## hands out things that cost something.
static func starter_items(type: String) -> Array:
	if type == STARTER:
		return FurnitureCatalog.starter_layout().filter(func(i): return FurnitureCatalog.layer(i["id"]) == "object")
	var out := []
	for s in info(type).get("starter", []):
		out.append({"id": s[0], "x": s[1], "z": s[2], "r": s[3], "c": FurnitureCatalog.ITEMS[s[0]]["color"], "s": s[4]})
	return out


## Checks a home sent by a player (or loaded from a save): a real type, real
## add-ons, and furniture that fits the plot and stays off the decor.
## {"type", "rooms": [add-on ids], "items": [furniture]}.
static func sanitize(data: Variant) -> Dictionary:
	var d: Dictionary = data if data is Dictionary else {}
	var type := str(d.get("type", STARTER))
	if not HOMES.has(type):
		type = STARTER
	var rooms := []
	if d.get("rooms") is Array:
		for id in d["rooms"]:
			if id is String and addon_index(type, id) >= 0 and not (id in rooms):
				rooms.append(id)
	return {"type": type, "rooms": rooms, "items": clean_items(type, d.get("items"))}


## Furniture only (no walls or floors: those belong to the home), kept off decor.
static func clean_items(type: String, items: Variant) -> Array:
	var stop := blocked(type)
	return House.sanitize_layout(items).filter(func(item):
		if FurnitureCatalog.layer(item["id"]) != "object":
			return false
		for cell in FurnitureCatalog.cells(item["id"], item["x"], item["z"], item["r"]):
			if stop.has(cell):
				return false
		return true)


# --- The plan: floors, walls and railings ---------------------------------------------

## Everything the builder draws for a home with these add-ons built:
## {"floors": [{rect, color, deck, id}], "edges": [{key, x, z, side, kind, room, entrance, outside}],
##  "walk": [[x, z]], "decor": [...]}. Edge kinds are "wall", "window",
## "door", "rail" and "gate"; each edge appears once, seen from the room on its
## (x, z) cell, facing `side`. A door between two rooms is an open doorway; a
## door or gate onto the yard is an `entrance`. `outside` edges can be seen
## from town (the far side is the yard or a deck).
static func plan(type: String, addon_ids: Array) -> Dictionary:
	var home := info(type)
	var rooms := built_rooms(type, addon_ids)
	var owner := {} # Vector2i -> room
	for r in rooms:
		for cell in room_cells(r):
			owner[cell] = r
	# Doorways: every built room's link, plus each room's own front door.
	var openings := {}
	for r in rooms:
		if r.has("link"):
			openings[edge_key(r["link"])] = true
	var floors := []
	for r in rooms:
		floors.append({"id": r["id"], "rect": r["rect"], "deck": r.get("deck", false), "tent": r.get("tent", false),
			"color": r.get("floor", home["deck"] if r.get("deck", false) else home["floor"])})
	var edges := {} # key -> edge
	var shared := {} # "a|b" -> [keys], walls between two rooms
	for r in rooms:
		var deck: bool = r.get("deck", false)
		var doors := [edge_key(r["door"])] if r.has("door") else []
		var windows: Array = r.get("windows", []).map(func(w): return edge_key(w))
		var gaps: Array = r.get("gaps", []).map(func(g): return edge_key(g))
		for cell in room_cells(r):
			for side in SIDES:
				var other: Dictionary = owner.get(cell + STEPS[side], {})
				if other.get("id") == r["id"]:
					continue
				var key := edge_key([cell.x, cell.y, side])
				if edges.has(key):
					continue
				var kind := ""
				if deck:
					# Railings only toward the open yard; rooms draw their own walls.
					if other.is_empty():
						kind = "gate" if key in gaps else "rail"
				elif other.is_empty() or other.get("deck", false):
					kind = "door" if key in doors or openings.has(key) else ("window" if key in windows else "wall")
				else:
					kind = "door" if openings.has(key) else "wall"
					var pair := [r["id"], other["id"]]
					pair.sort()
					var list: Array = shared.get("|".join(pair), [])
					list.append(key)
					shared["|".join(pair)] = list
				if kind != "":
					edges[key] = {"key": key, "x": cell.x, "z": cell.y, "side": side, "kind": kind, "room": r["id"],
						"entrance": other.is_empty() and kind in ["door", "gate"],
						"outside": other.is_empty() or other.get("deck", false)}
	# Two rooms that touch without a link get a doorway in the middle of their wall.
	for pair in shared:
		var list: Array = shared[pair]
		if not list.any(func(k): return edges[k]["kind"] == "door"):
			edges[list[list.size() / 2]]["kind"] = "door"
	return {"floors": floors, "edges": edges.values(), "walk": home.get("walk", []), "decor": home.get("decor", [])}


## The ways in and out of a home with these add-ons built, main one first:
## [{x, z, side, kind}], each on its room's cell and facing the yard.
static func entrances(type: String, addon_ids: Array) -> Array:
	return plan(type, addon_ids)["edges"].filter(func(e): return e["entrance"])


## Every cell inside a room (walled or deck) with these add-ons built:
## Vector2i -> room id. Furniture only goes on these.
static func room_cells_built(type: String, addon_ids: Array) -> Dictionary:
	var out := {}
	for r in built_rooms(type, addon_ids):
		for cell in room_cells(r):
			out[cell] = r["id"]
	return out


static func room_cells(r: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var rect: Array = r["rect"]
	for x in range(rect[0], rect[0] + rect[2]):
		for z in range(rect[1], rect[1] + rect[3]):
			out.append(Vector2i(x, z))
	return out


## One name for the edge between two cells, whichever side it's seen from:
## "h:x:z" for the line north of cell (x, z), "v:x:z" for the line west of it.
static func edge_key(edge: Array) -> String:
	var x := int(edge[0])
	var z := int(edge[1])
	match str(edge[2]):
		"n":
			return "h:%d:%d" % [x, z]
		"s":
			return "h:%d:%d" % [x, z + 1]
		"w":
			return "v:%d:%d" % [x, z]
		_:
			return "v:%d:%d" % [x + 1, z]


# --- Saved data -------------------------------------------------------------------

## The profile keys homes add, for a new player: the furniture in every home
## lived in so far, and the home lived in now (see Homes).
static func new_save() -> Dictionary:
	return {"homes": {STARTER: starter_items(STARTER)}, "home": STARTER}


## The home keys of a loaded save, checked. Saves from before homes kept one
## "house" layout, walls and all; its furniture moves into the Sprout Cottage,
## which stands where that house stood.
static func clean_save(data: Dictionary) -> Dictionary:
	var out := new_save()
	var homes = data.get("homes")
	if homes is Dictionary:
		for type in homes:
			if HOMES.has(type):
				out["homes"][type] = clean_items(type, homes[type])
	elif data.get("house") is Array:
		out["homes"][STARTER] = clean_items(STARTER, data["house"])
	if HOMES.has(str(data.get("home", ""))):
		out["home"] = str(data["home"])
	return out


## Every piece placed in any of a profile's homes.
static func all_items(profile: Dictionary) -> Array:
	var out := []
	var homes: Dictionary = profile.get("homes", {})
	for type in homes:
		out.append_array(homes[type])
	return out


## Every model the homes use, for the web build's art pruning.
static func art_paths() -> Array:
	var out := [SIGNPOST]
	for type in HOMES:
		for d in HOMES[type].get("decor", []):
			if not (d["model"] in out):
				out.append(d["model"])
	return out
