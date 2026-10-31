extends Node
## Headless multiplayer smoke test. Run a host and a client:
##   godot --headless --path . -- --host --smoke-test
##   godot --headless --path . -- --join=127.0.0.1 --smoke-test
## The client edits its house, sends a phrase and puts on a hat from the shop;
## both print what they see.

var _t := 0.0
var _edited := false
var _reported := false


func _process(delta: float) -> void:
	_t += delta
	var world := get_tree().current_scene
	if world == null or world.name != "World":
		return
	if _t > 3.0 and not _edited and not multiplayer.is_server():
		_edited = true
		var house: House = world._build.house
		print("[smoke] client plot layout before: %d items" % house.layout.size())
		house.place("sofa", 6, 6, 1, "ff00aa")
		world._submit_house(house.layout.duplicate(true))
		world._send_phrase(2)
		GameState.unlock([ShopCatalog.clothes_key("hat", 20)])
		world._wear("hat", 20)
	# The host starts about 3 seconds first. It reports after the client's edits
	# and stays until the client has reported too.
	if multiplayer.is_server() and _t > 10.0:
		get_tree().quit()
	if not _reported and _t > (7.5 if multiplayer.is_server() else 5.0):
		_reported = true
		var players: Array = world.get_node("Players").get_children().map(func(p): return "%s@%s" % [p.display_name, p.position.round()])
		print("[smoke] peer %d sees players: %s" % [multiplayer.get_unique_id(), players])
		for id in world.player_plots:
			var plot: int = world.player_plots[id]
			var has_sofa: bool = world.houses[plot].layout.any(func(i): return i["id"] == "sofa" and i["c"] == "ff00aa")
			print("[smoke] peer %d: player %d plot %d items %d custom_sofa=%s" % [multiplayer.get_unique_id(), id, plot, world.houses[plot].layout.size(), has_sofa])
		print("[smoke] chat: ", world._hud._chat_lines)
		for id in world.player_avatars:
			print("[smoke] peer %d: player %d changed avatar, hat %d" % [multiplayer.get_unique_id(), id,
					world.player_avatars[id]["hat"]])
		if not multiplayer.is_server():
			get_tree().quit()
