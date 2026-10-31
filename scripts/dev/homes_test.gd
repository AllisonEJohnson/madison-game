extends Node
## Headless check of homes. Run it as the host:
##   godot --headless --path . -- --host --homes-test
## It checks that every home in HomeCatalog is built right (rooms on the plot,
## doors that lead somewhere, free starter furniture), then plays through
## buying a home, moving in and out, adding a room and filling a home up, and
## checks old saves move into the Sprout Cottage. It puts this device's save
## back the way it was, prints one line per check and quits with the number
## of failures as its exit code.

var _t := 0.0
var _step := 0
var _fails := 0
var _checks := 0
var _saved := {}
var _world: Node


func _process(delta: float) -> void:
	_t += delta
	_world = get_tree().current_scene
	if _world == null or _world.name != "World" or _world.local_player == null:
		return
	if _step == 0 and _t > 2.0:
		_step = 1
		_saved = GameState.profile.duplicate(true)
		_catalog()
		_new_player()
		_buying_and_moving()
		_rooms_and_room_left()
		_saves()
		_sign_and_window()
	elif _step == 1 and _t > 2.6:
		_step = 2
		_check("standing at your signpost offers your homes", _world._zone == _own_house().sign_zone)
		_world._use_zone()
		_check("using the signpost opens the Homes window", _world._hud._homes.visible)
		_world._hud.close_popups()
		_finish()


# --- The catalog ------------------------------------------------------------------------

func _catalog() -> void:
	var stardust := 0
	for type in HomeCatalog.types():
		var home := HomeCatalog.info(type)
		var name := HomeCatalog.home_name(type)
		var cells := {} # Vector2i -> room id
		var on_plot := true
		var overlap := false
		for r in home["rooms"]:
			for cell in HomeCatalog.room_cells(r):
				on_plot = on_plot and cell.x >= 0 and cell.y >= 0 and cell.x < HomeCatalog.PLOT and cell.y < HomeCatalog.PLOT
				overlap = overlap or cells.has(cell)
				cells[cell] = r
		_check("%s: rooms are on the plot and don't overlap" % name, on_plot and not overlap)
		_check("%s: 2 rooms to start and 2 or 3 to add" % name, HomeCatalog.base_rooms(type).size() == 2
				and HomeCatalog.addons(type).size() in [2, 3])
		var blocked := HomeCatalog.blocked(type)
		_check("%s: decor stays out of walled rooms" % name, blocked.keys().all(func(c):
				return not cells.has(c) or cells[c].get("deck", false)))
		_check("%s: the walk is clear" % name, home["walk"].all(func(w):
				return not cells.has(Vector2i(w[0], w[1])) and not blocked.has(Vector2i(w[0], w[1]))))
		_check("%s: doors, windows and links are on their room's edge" % name, _edges_ok(home, cells))
		# With every room built, each walled room has a way in.
		var all := HomeCatalog.addons(type).map(func(r): return r["id"])
		var p := HomeCatalog.plan(type, all)
		var ways_in := true
		for r in home["rooms"]:
			if r.get("deck", false):
				continue
			var doors: Array = p["edges"].filter(func(e): return e["kind"] == "door" and _touches(e, r))
			ways_in = ways_in and not doors.is_empty()
		_check("%s: every room has a doorway" % name, ways_in)
		_check("%s: each room added fits more things" % name,
				HomeCatalog.capacity(type, all) > HomeCatalog.capacity(type, []))
		var starter := HomeCatalog.starter_items(type)
		_check("%s: comes furnished, all with free looks" % name, starter.size() >= 8 and starter.all(func(i):
				return ShopCatalog.is_free(ShopCatalog.furniture_key(i["id"], i["s"]))))
		_check("%s: its furniture fits" % name, HomeCatalog.clean_items(type, starter).size() == starter.size()
				and starter.size() <= HomeCatalog.capacity(type, []))
		for key in [HomeCatalog.home_key(type)] + all.map(func(id): return HomeCatalog.room_key(type, id)):
			if ShopCatalog.price(key).get("currency") == "stardust":
				stardust += 1
			_check("%s is for sale by its key" % key, ShopCatalog.is_item(key) and HomeCatalog.parse_key(key) != {})
	_check("the Sprout Cottage is free for everyone", ShopCatalog.is_free(HomeCatalog.home_key(HomeCatalog.STARTER)))
	_check("other homes cost something", HomeCatalog.types().all(func(t):
			return t == HomeCatalog.STARTER or not ShopCatalog.is_free(HomeCatalog.home_key(t))))
	_check("some homes and rooms cost Stardust (%d)" % stardust, stardust >= 3)
	_check("Stardust ones never wait for a level", HomeCatalog.all_keys().all(func(k):
			return ShopCatalog.price(k).get("currency") != "stardust" or ShopCatalog.level_needed(k) == 1))
	_check("the Oak Lookout opens at level 6", ShopCatalog.level_needed("home:oak_lookout:0") == 6)
	_check("nonsense home keys aren't for sale", not ShopCatalog.is_item("home:castle:0")
			and not ShopCatalog.is_item("room:sprout_cottage:9") and not ShopCatalog.is_item("home:oak_lookout:1"))
	var lines := Levels.rewards(6).map(func(r): return r["text"])
	_check("reaching level 6 tells you about the Oak Lookout", lines.any(func(t): return "Oak Lookout" in t))


func _edges_ok(home: Dictionary, cells: Dictionary) -> bool:
	for r in home["rooms"]:
		var mine := HomeCatalog.room_cells(r)
		var outward := []
		if r.has("door"):
			outward.append(r["door"])
		outward.append_array(r.get("windows", []))
		outward.append_array(r.get("gaps", []))
		for e in outward:
			var cell := Vector2i(e[0], e[1])
			var other: Dictionary = cells.get(cell + HomeCatalog.STEPS[e[2]], {})
			if not (cell in mine) or other.get("id") == r["id"]:
				return false
		if r.has("link"):
			var l: Array = r["link"]
			var a: Dictionary = cells.get(Vector2i(l[0], l[1]), {})
			var b: Dictionary = cells.get(Vector2i(l[0], l[1]) + HomeCatalog.STEPS[l[2]], {})
			# The link joins this room to another one of the home.
			if a.is_empty() or b.is_empty() or a.get("id") == b.get("id") or not r["id"] in [a.get("id"), b.get("id")]:
				return false
	return true


## True when an edge lies on room `r`'s border.
func _touches(edge: Dictionary, r: Dictionary) -> bool:
	var cell := Vector2i(edge["x"], edge["z"])
	var cells := HomeCatalog.room_cells(r)
	return cell in cells or (cell + HomeCatalog.STEPS[edge["side"]]) in cells


# --- Playing ----------------------------------------------------------------------------

func _new_player() -> void:
	GameState.profile.merge(HomeCatalog.new_save(), true)
	GameState.profile["owned"] = []
	GameState.profile["acorns"] = 0
	GameState.profile["stardust"] = 0
	Progress.set_level(1)
	var house := _own_house()
	house.set_home(Homes.active())
	_world._submit_home(Homes.active())
	_check("a new player lives in the Sprout Cottage", Homes.current() == HomeCatalog.STARTER
			and Homes.owned() == [HomeCatalog.STARTER] and house.home_type == HomeCatalog.STARTER)
	_check("it comes furnished", house.layout.size() == HomeCatalog.starter_items(HomeCatalog.STARTER).size())
	_check("the plot's sign names the home", "Sprout Cottage" in house._sign.text)


func _buying_and_moving() -> void:
	var oak := HomeCatalog.home_key("oak_lookout")
	GameState.grant("acorns", 5000)
	_check("can't buy the Oak Lookout before level 6", not GameState.buy(oak))
	_check("can't add a room to a home you don't own",
			not GameState.buy(HomeCatalog.room_key("oak_lookout", "nook")))
	_check("can't move into a home you don't own", not Homes.move_in("oak_lookout"))
	Progress.set_level(6)
	var before := GameState.balance("acorns")
	_check("buying the Oak Lookout at level 6", GameState.buy(oak) and Homes.owns_home("oak_lookout"))
	_check("it cost 1500 Acorns", before - GameState.balance("acorns") == 1500)
	_check("buying a home doesn't move you", Homes.current() == HomeCatalog.STARTER)
	_world._visit_home("oak_lookout")
	var house := _own_house()
	_check("moving in shows the Oak Lookout on your plot", house.home_type == "oak_lookout"
			and "Oak Lookout" in house._sign.text)
	_check("everyone hears about the move", _world.homes[_world.local_player.peer_id]["type"] == "oak_lookout")
	_check("the new home comes furnished", house.layout.size() == HomeCatalog.starter_items("oak_lookout").size())
	_check("nothing goes on the oak tree", not house.can_fit("chair", 8, 1, 0) and house.can_fit("chair", 2, 6, 0))
	house.place("lamp", 2, 6, 0, "ffffff")
	_world._build._edited()
	_check("furniture is kept per home", Homes.items("oak_lookout").size() == house.layout.size()
			and Homes.items(HomeCatalog.STARTER).size() == HomeCatalog.starter_items(HomeCatalog.STARTER).size())
	_world._visit_home(HomeCatalog.STARTER)
	_check("moving back brings the cottage back as it was", house.home_type == HomeCatalog.STARTER
			and house.layout.size() == HomeCatalog.starter_items(HomeCatalog.STARTER).size())
	_world._visit_home("oak_lookout")
	_check("and the Oak Lookout keeps its new lamp", house.layout.any(func(i): return i["id"] == "lamp" and i["x"] == 2))
	GameState.grant("stardust", 200)
	_check("Toadstool Hollow costs Stardust at any level", GameState.buy(HomeCatalog.home_key("toadstool_hollow")))


func _rooms_and_room_left() -> void:
	_world._visit_home(HomeCatalog.STARTER)
	var house := _own_house()
	var garden := HomeCatalog.room_key(HomeCatalog.STARTER, "garden")
	var cap := house.capacity
	var walls_before := _parts(HomeCatalog.STARTER, [])
	_check("buying the Garden Room", GameState.buy(garden))
	_check("the room shows up on your plot", "garden" in house.rooms and house.capacity == cap + 20)
	_check("everyone sees the new room", "garden" in _world.homes[_world.local_player.peer_id]["rooms"])
	_check("the home grew", _parts(HomeCatalog.STARTER, ["garden"]) > walls_before)
	var p := HomeCatalog.plan(HomeCatalog.STARTER, ["garden"])
	var link := HomeCatalog.edge_key([8, 6, "e"])
	_check("a doorway leads into it", p["edges"].any(func(e): return e["key"] == link and e["kind"] == "door"))
	# Fill the home to the brim.
	var spots := []
	for x in HomeCatalog.PLOT:
		for z in HomeCatalog.PLOT:
			if house.layout.size() >= house.capacity:
				break
			if house.can_fit("plant", x, z, 0) and _empty_at(house, Vector2i(x, z)):
				house.place("plant", x, z, 0, "4caf50")
				spots.append(Vector2i(x, z))
	var free_cell := Vector2i(-1, -1)
	for x in HomeCatalog.PLOT:
		for z in HomeCatalog.PLOT:
			if free_cell.x < 0 and _empty_at(house, Vector2i(x, z)) and not HomeCatalog.blocked(house.home_type).has(Vector2i(x, z)):
				free_cell = Vector2i(x, z)
	_check("a home holds only so much (%d)" % house.capacity, house.layout.size() == house.capacity
			and house.is_full_for("plant", free_cell.x, free_cell.y, 0)
			and not house.place("plant", free_cell.x, free_cell.y, 0, "4caf50"))
	var full_said := [false]
	_world._build.home_full.connect(func(): full_said[0] = true, CONNECT_ONE_SHOT)
	_check("swapping a piece still works when full", house.place("lamp", spots[0].x, spots[0].y, 0, "ffffff"))
	_world._build.set_active(true)
	_world._build._cell = free_cell
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_world._build.select_item("plant", 0)
	_world._build._unhandled_input(click)
	_check("decorating a full home says so", full_said[0])
	_world._build.set_active(false)
	GameState.profile["owned"].append("furniture:piano:1")
	GameState.reset_owned()
	_check("taking back what was bought keeps the home lived in and its rooms",
			GameState.owns(garden) and not Homes.owns_home("oak_lookout"))


func _saves() -> void:
	var old := FurnitureCatalog.starter_layout()
	old.append({"id": "piano", "x": 10, "z": 10, "r": 0, "s": 0})
	var moved := HomeCatalog.clean_save({"house": old})
	var items: Array = moved["homes"][HomeCatalog.STARTER]
	_check("an old save's furniture moves into the Sprout Cottage", moved["home"] == HomeCatalog.STARTER
			and items.size() == 13 and items.any(func(i): return i["id"] == "piano"))
	_check("its walls and floors stay behind", items.all(func(i): return FurnitureCatalog.layer(i["id"]) == "object"))
	var odd := HomeCatalog.sanitize({"type": "castle", "rooms": ["moat", "garden", "garden"], "items": [
			{"id": "wall", "x": 1, "z": 1}, {"id": "chair", "x": 1, "z": 1}]})
	_check("a strange home becomes a cottage with real rooms", odd["type"] == HomeCatalog.STARTER
			and odd["rooms"] == ["garden"] and odd["items"].size() == 1)
	var tree := HomeCatalog.sanitize({"type": "oak_lookout", "items": [{"id": "chair", "x": 8, "z": 1}]})
	_check("nothing sent can stand on decor", tree["items"].is_empty())


func _sign_and_window() -> void:
	var house := _own_house()
	_check("only your own signpost offers homes", house.sign_zone.enabled and _world.houses.filter(
			func(h): return h != house and h.sign_zone.enabled).is_empty())
	_world.local_player.teleport(house.sign_zone.global_position + Vector3(0, 0.5, 0))
	_world._hud.open_homes("homes")
	var entries: Dictionary = _world._hud._homes._entries
	_check("the Homes window lists every home", HomeCatalog.types().all(func(t):
			return entries.has(HomeCatalog.home_key(t))))
	_check("and the rooms of homes you own", entries.has(HomeCatalog.room_key(HomeCatalog.STARTER, "bedroom"))
			and not entries.has(HomeCatalog.room_key("safari_camp", "platform")))
	_world._hud.close_popups()


## How many pieces the home is built from with these rooms.
func _parts(type: String, rooms: Array) -> int:
	var shell := HomeShell.build(type, rooms)
	var n := shell.get_child_count()
	shell.free()
	return n


func _empty_at(house: House, cell: Vector2i) -> bool:
	for i in house.layout:
		if cell in FurnitureCatalog.cells(i["id"], i["x"], i["z"], i["r"]):
			return false
	return true


func _own_house() -> House:
	return _world._own_house()


func _check(what: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print("[homes] %s %s" % ["ok  " if ok else "FAIL", what])


func _finish() -> void:
	GameState.profile = _saved
	GameState.save_profile()
	print("[homes] %d checks, %d failed" % [_checks, _fails])
	get_tree().quit(_fails)
