extends Node
## Saves a screenshot after a short delay, then quits. Dev helper:
##   godot --path . -- --screenshot=/tmp/menu.png [--host [--shot-build]]

var path := ""
var press_actions: Array[String] = []
var look_down := false # Tilts the camera to see inside the home.
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
	if _t > 4.0:
		get_viewport().get_texture().get_image().save_png(path)
		print("[screenshot] saved ", path)
		get_tree().quit()
