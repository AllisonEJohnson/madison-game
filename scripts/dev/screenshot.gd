extends Node
## Saves a screenshot after a short delay, then quits. Dev helper:
##   godot --path . -- --screenshot=/tmp/menu.png [--host [--shot-build]]
## --shot-ui=a,b,... opens parts of the interface first: in the world "chat",
## "help", "leave", "tuck", "say:<phrase index>", "category:<id>", "search:<words>", "favorite:<key>" or
## "stress" (fills build mode's catalog with every model in the furniture
## pack, to check it copes with hundreds of items), "goto:<x>/<z>/<yaw>[/<pitch>/<distance>]"
## (moves you there and turns the camera; the glade starts at x 600), "admin:<command>" (types a
## command into the admin console, which needs a debug build or --admin), "shop:<home|clothes>",
## "shopcat:<category id>", "shoppick:<shop key>" (shows one item up close), "build:<id>/<style>"
## (picks a piece in build mode), "chase" (starts Star Chase), "chasedone:<stars>" (shows the
## result card), "prompt" (shows the nearby card for the zone you stand in); in the menu "tab:<n>",
## "part:<n>", "try:<option>/<index>" (tries on a choice) or "names". For levels: "levels" (opens
## the level card), "levelup:<level>" (shows that level's level-up card) and
## "camera:<x>/<y>/<z>/<look x>/<look y>/<look z>" (a free camera, for views from above); "nohud"
## hides the interface; "closeadmin" closes the admin console; "sky[:<yaw>[/<pitch>/<distance>]]" goes
## up to the Sky Garden. "adminpanel" opens the admin tools from the Help card, and
## "adminpick:<tile>/<number>" picks a number on one of its tiles.
## For homes: "homes[:<homes|rooms>]" (opens the Homes window), "homepick:<shop key>" (shows a home
## or room up close), "visit:<home type>" (moves into a home you own and goes inside; "admin:unlock all"
## first owns them all), "outside[:<door>]" (walks back out to town), "decorate" (starts decorating,
## looking down into the home) and "plans" (shows where rooms can be added, as when decorating).
## For pets: "wild:<land>[/<n>]" (stands by a wild pet), "meet" (says hi), "befriend" (makes
## friends), "pets" (opens My pets), "petpick:<species>", "petfilter:<id>" and "petbring:<species>"
## (brings one of your pets along).
## "sleep:<seconds>" pauses before the next step.
## --shot-wait=<seconds> waits longer before the picture (default 5), for pictures to render.

var path := ""
var press_actions: Array[String] = []
var look_down := false # Tilts the camera to see inside the home.
var ui_steps: Array[String] = []
var wait := 5.0
var _t := 0.0
var _hold_until := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t > 1.5 and not press_actions.is_empty():
		var ev := InputEventAction.new()
		ev.action = press_actions.pop_front()
		ev.pressed = true
		Input.parse_input_event(ev)
	if _t > 2.0 and look_down:
		look_down = false
		# Stands in the middle of the home and looks down over the walls.
		var world := get_tree().current_scene
		var player: Player = world.get("local_player") if world else null
		var inside: House = world.get("_inside") if world else null
		if player and inside:
			player.teleport(inside.to_global(Vector3(0, 0.5, 1.5)))
			player.set_camera_view(-1.0, 8.0)
	if _t > 2.5 and _t > _hold_until and not ui_steps.is_empty():
		_ui_step(ui_steps.pop_front())
	if _t > wait:
		get_viewport().get_texture().get_image().save_png(path)
		print("[screenshot] saved ", path)
		get_tree().quit()


func _ui_step(step: String) -> void:
	var scene := get_tree().current_scene
	var arg := step.substr(step.find(":") + 1) if ":" in step else ""
	var hud = scene.get("_hud")
	match step.get_slice(":", 0):
		"sleep":
			_hold_until = _t + float(arg)
		"chat":
			hud.open_quick_chat()
		"help":
			hud._show_only(hud._help)
		"leave":
			hud.ask_leave()
		"tuck":
			hud._tuck(true)
		"say":
			hud.add_chat("*", "SunnyOtter7 joined")
			scene._send_phrase(int(arg))
		"category":
			hud._browser.show_category(arg)
		"search":
			hud._browser._search.text = arg
			hud._browser._refresh(false)
		"favorite":
			GameState.set_favorite(arg, true)
			hud._browser.favorites[arg] = true
			hud._browser.set_favorites(hud._browser.favorites)
		"tab":
			scene._show_tab(int(arg))
		"part":
			scene._show_part(int(arg))
		"names":
			scene._open_name_picker()
		"stress":
			_fill_with_whole_pack(hud._browser)
		"admin":
			var console := scene.find_children("*", "AdminConsole", false, false)
			if not console.is_empty():
				if not console[0]._panel.visible:
					console[0].toggle()
				console[0]._on_submitted(arg)
		"shop":
			hud.open_shop(arg)
		"shopcat":
			hud._shop.show_category(arg)
		"shoppick":
			hud._shop.pick(arg)
		"build":
			var v := arg.split("/")
			scene._build.select_item(v[0], int(v[1]))
			scene._show_build_selection()
		"acorn":
			# Stands a few steps south of an acorn in the land you're in, facing it.
			var pickups: AcornPickups = scene._pickups[1 if scene.land_at(scene.local_player.global_position) == "glade" else 0]
			var spot: Vector3 = pickups.positions()[int(arg) if arg != "" else 0]
			scene.local_player.teleport(Vector3(spot.x + 1.6, 0.5, spot.z + 3.0))
			scene.local_player.set_camera_yaw(0.0)
			scene.local_player.set_camera_view(-0.3, 3.5)
		"star":
			# Stands a few steps from the falling star.
			var star: Vector3 = scene._glade.chase.star_position()
			scene.local_player.teleport(Vector3(star.x, 0.5, star.z + 5.0))
			scene.local_player.set_camera_yaw(0.0)
		"chase":
			scene._glade.chase.start()
		"sky":
			# Goes up to the Sky Garden as if through its portal, and turns the camera.
			scene._travel(scene.local_player, scene._sky.portal)
			if arg != "":
				var v := arg.split("/")
				scene.local_player.set_camera_yaw(deg_to_rad(float(v[0])))
				if v.size() >= 3:
					scene.local_player.set_camera_view(float(v[1]), float(v[2]))
		"closeadmin":
			for console in scene.find_children("*", "AdminConsole", false, false):
				if console._panel.visible:
					console.toggle()
		"nohud":
			hud.visible = false
			hud._pending_levels.clear()
		"homes":
			hud.open_homes(arg)
		"homepick":
			hud._homes.pick(arg)
		"visit":
			scene._visit_home(arg)
		"decorate":
			# Starts decorating and looks down into the home, like --shot-build.
			scene._toggle_build()
			var house: House = scene._own_inside()
			scene.local_player.teleport(house.to_global(Vector3(0, 0.5, 1.5)))
			scene.local_player.set_camera_view(-1.0, 8.0)
		"plans":
			var house: House = scene._own_inside()
			house.set_decorating(true, Homes.plan_labels(house.home_type))
		"outside":
			scene._leave_home(int(arg) if arg != "" else 0)
		"levels":
			hud.open_level_card()
		"adminpanel":
			hud.open_admin()
		"adminpick":
			hud._admin.pick(arg.get_slice("/", 0), int(arg.get_slice("/", 1)))
		"levelup":
			var level := int(arg)
			hud._pending_levels.clear()
			hud._level_up.show_level(level, Levels.rewards(level))
			if not hud._level_up.visible:
				hud._show_only(hud._level_up)
			hud._level_up.burst(hud._root)
		"camera":
			var v := Array(arg.split("/")).map(func(n): return float(n))
			var cam := Camera3D.new()
			scene.add_child(cam)
			cam.position = Vector3(v[0], v[1], v[2])
			cam.look_at(Vector3(v[3], v[4], v[5]), Vector3.UP if absf(v[1] - v[4]) < 1.0 or absf(v[0] - v[3]) + absf(v[2] - v[5]) > 0.1 else Vector3.FORWARD)
			cam.make_current()
		"wild":
			# Stands just east of a wild pet ("wild:glade/1": the second one in the glade),
			# looking north so both show. Going up to the Sky Garden first needs the "sky" step.
			var v := arg.split("/")
			var wild: WildPets = scene._pets._wild.filter(func(w): return w.land == v[0])[0]
			var pet: WildPet = wild.pets()[int(v[1]) if v.size() > 1 else 0]
			scene.local_player.teleport(pet.global_position + Vector3(1.5, 0.5, 0.4))
			scene.local_player.set_camera_yaw(0.0)
			scene.local_player.set_camera_view(-0.3, 4.0)
		"meet":
			scene._process(0.0)
			scene._use_zone()
		"befriend":
			hud.adopt_card.press_befriend()
		"pets":
			hud.open_pets()
		"petpick":
			hud.pets_panel.pick(arg)
		"petfilter":
			hud.pets_panel.show_filter(arg)
		"petbring":
			scene._pets.choose(arg)
		"chasedone":
			hud.show_game_result(int(arg), StarChase.reward_for(int(arg)), true,
					int(arg) * int(Levels.SOURCES["star"]["xp"]))
		"try":
			var v := arg.split("/")
			scene._on_option_chosen(v[0], int(v[1]))
		"goto":
			var v := arg.split("/")
			scene.local_player.teleport(Vector3(float(v[0]), 0.5, float(v[1])))
			scene.local_player.set_camera_yaw(deg_to_rad(float(v[2])))
			if v.size() >= 5:
				scene.local_player.set_camera_view(float(v[3]), float(v[4]))


func _fill_with_whole_pack(browser: CatalogBrowser) -> void:
	var start := Time.get_ticks_msec()
	var base := "Bright_Furniture/prefabs/assets/"
	var categories := []
	var entries := []
	for folder in DirAccess.get_directories_at(Art.ROOT + base):
		categories.append({"id": folder, "name": folder.capitalize(), "icon": "package"})
		for file in DirAccess.get_files_at(Art.ROOT + base + folder):
			if not file.ends_with(".tscn"):
				continue
			var path: String = base + folder + "/" + file.get_basename()
			entries.append({"key": path, "name": file.get_basename().capitalize(), "category": folder,
				"group": folder.capitalize(), "thumb": func(): return Thumbs.texture("stress:" + path, func(): return Art.instance(path), "item")})
	browser.setup(categories, entries, "picture")
	print("[stress] %d items in %d categories, browser ready in %d ms" % [entries.size(), categories.size(),
			Time.get_ticks_msec() - start])
