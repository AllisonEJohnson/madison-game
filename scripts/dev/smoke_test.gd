extends Node
## Headless multiplayer smoke test. Run a host and a client:
##   godot --headless --path . -- --host --smoke-test
##   godot --headless --path . -- --join=127.0.0.1 --smoke-test
## The client goes inside its home, edits it, adds a room to it, sends a
## phrase, puts on a hat from the shop and brings a new pet along. Then the
## host walks into the client's home to visit. Both print what they see
## (players show only to those in the same place, town or the same home).

var _t := 0.0
var _edited := false
var _visited := false
var _reported := false


func _process(delta: float) -> void:
	_t += delta
	var world := get_tree().current_scene
	if world == null or world.name != "World":
		return
	if _t > 3.0 and not _edited and not multiplayer.is_server():
		_edited = true
		world._go_home()
		var house: House = world._build.house
		print("[smoke] client home layout before: %d items" % house.layout.size())
		house.place("sofa", 6, 6, 1, "ff00aa")
		Homes.set_items(house.layout) # saved, as decorating does
		world._submit_house(house.layout.duplicate(true))
		world._send_phrase(2)
		GameState.unlock([ShopCatalog.clothes_key("hat", 20)])
		world._wear("hat", 20)
		# Add a room to the home: everyone should see it on the plot.
		var type := Homes.current()
		GameState.unlock([HomeCatalog.room_key(type, HomeCatalog.addons(type)[0]["id"])])
		PetCollection.adopt("fox", "Pickles")
		world._pets.choose("fox")
	# The host starts about 3 seconds first, so the client's edits are done by 6.
	if multiplayer.is_server() and _t > 6.5 and not _visited:
		_visited = true
		for id in world.player_plots:
			if id != 1:
				world._enter_home(world.player_plots[id], 0)
				var inside: House = world._inside
				print("[smoke] host visiting %s: %d items, custom_sofa=%s" % [inside.home_type, inside.layout.size(),
						inside.layout.any(func(i): return i["id"] == "sofa" and i["c"] == "ff00aa")])
	# The host reports after the client's edits and stays until the client has
	# reported too.
	if multiplayer.is_server() and _t > 10.0:
		get_tree().quit()
	if not _reported and _t > (7.5 if multiplayer.is_server() else 5.0):
		_reported = true
		var players: Array = world.get_node("Players").get_children().map(func(p):
				return "%s@%s %s" % [p.display_name, p.position.round(), "shown" if p.visible else "hidden"])
		print("[smoke] peer %d sees players: %s" % [multiplayer.get_unique_id(), players])
		for id in world.player_plots:
			var plot: int = world.player_plots[id]
			var home: Dictionary = world.homes[id]
			var has_sofa: bool = home["items"].any(func(i): return i["id"] == "sofa" and i["c"] == "ff00aa")
			print("[smoke] peer %d: player %d plot %d %s %s items %d custom_sofa=%s outside=%s" % [
					multiplayer.get_unique_id(), id, plot, home["type"], home["rooms"], home["items"].size(), has_sofa,
					world.plots[plot].home_type])
		print("[smoke] chat: ", world._hud._chat_lines)
		for id in world.player_avatars:
			print("[smoke] peer %d: player %d changed avatar, hat %d" % [multiplayer.get_unique_id(), id,
					world.player_avatars[id]["hat"]])
		for player in world.get_node("Players").get_children():
			print("[smoke] peer %d: player %s has a %s" % [multiplayer.get_unique_id(), player.name,
					player.pet.config["species"]])
		if not multiplayer.is_server():
			get_tree().quit()
