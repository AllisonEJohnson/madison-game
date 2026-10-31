extends Node
## Saves a screenshot after a short delay, then quits. Dev helper:
##   godot --path . -- --screenshot=/tmp/menu.png [--host]

var path := ""
var press_actions: Array[String] = []
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t > 1.5 and not press_actions.is_empty():
		var ev := InputEventAction.new()
		ev.action = press_actions.pop_front()
		ev.pressed = true
		Input.parse_input_event(ev)
	if _t > 4.0:
		get_viewport().get_texture().get_image().save_png(path)
		print("[screenshot] saved ", path)
		get_tree().quit()
