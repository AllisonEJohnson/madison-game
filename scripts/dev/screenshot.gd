extends Node
## Saves a screenshot after a short delay, then quits. Dev helper:
##   godot --path . -- --screenshot=/tmp/menu.png [--host [--shot-build]]
## --shot-ui=a,b,... opens parts of the interface first: in the world "chat",
## "help", "leave", "tuck", "say:<phrase index>", "category:<id>", "search:<words>", "favorite:<key>" or
## "stress" (fills build mode's catalog with every model in the furniture
## pack, to check it copes with hundreds of items), "goto:<x>/<z>/<yaw>[/<pitch>/<distance>]"
## (moves you there and turns the camera; the glade starts at x 600), "admin:<command>" (types a
## command into the admin console, which needs a debug build or --admin); in the menu "tab:<n>",
## "part:<n>" or "names".

var path := ""
var press_actions: Array[String] = []
var look_down := false # Tilts the camera to see inside the home.
var ui_steps: Array[String] = []
var _t := 0.0


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
		var plot: int = world.player_plots.get(player.peer_id, -1) if player else -1
		if plot >= 0:
			player.teleport(world.houses[plot].to_global(Vector3(0, 0.5, 1.5)))
			player.set_camera_view(-1.0, 8.0)
	if _t > 2.5 and not ui_steps.is_empty():
		_ui_step(ui_steps.pop_front())
	if _t > 5.0:
		get_viewport().get_texture().get_image().save_png(path)
		print("[screenshot] saved ", path)
		get_tree().quit()


func _ui_step(step: String) -> void:
	var scene := get_tree().current_scene
	var arg := step.substr(step.find(":") + 1) if ":" in step else ""
	var hud = scene.get("_hud")
	match step.get_slice(":", 0):
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
