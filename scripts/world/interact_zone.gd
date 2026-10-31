class_name InteractZone
extends Node3D
## A spot that offers something to do, like a shop counter or a game's start
## ring. While the local player stands within `radius`, the HUD shows a card
## with the zone's title and a button (also the E key); pressing it emits
## `used`. The world finds zones through the "interact_zones" group.

signal used

var title := ""
var hint := ""
var icon := "sparkles"
var button_text := "Open"
var radius := 2.0
## Off while the zone has nothing to offer (say, during a game).
var enabled := true


func setup(zone_title: String, zone_hint: String, icon_name: String, button: String, reach: float) -> InteractZone:
	title = zone_title
	hint = zone_hint
	icon = icon_name
	button_text = button
	radius = reach
	name = "Zone" + zone_title.to_pascal_case()
	return self


func _enter_tree() -> void:
	add_to_group("interact_zones")


## True when `pos` (world space) is close enough to use this zone.
func reaches(pos: Vector3) -> bool:
	if not enabled or not is_visible_in_tree():
		return false
	var here := global_position
	return Vector2(pos.x - here.x, pos.z - here.z).length() < radius and absf(pos.y - here.y) < 2.5
