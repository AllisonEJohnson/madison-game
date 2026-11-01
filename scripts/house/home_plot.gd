class_name HomePlot
extends Node3D
## A lot in town with the outside of the home its player lives in: closed
## walls, roofs and shut doors (see HomeShell.exterior), never the furniture.
## Walking into one of its entrances takes you inside, to the home's own space
## (see House). The node sits at the middle of the lot, its front (+Z) facing
## the street. Like the rest of the house code it doesn't use the autoloads.

## The local player walked into entrance `index` (see HomeCatalog.entrances).
signal door_entered(player: Player, index: int)

## The lot is this many meters each way. The home's 12 × 12 grid sits toward
## the back, at HOME_AT, leaving a front yard with a path to the street.
const LOT := 22.0
const HOME_AT := Vector3(0, 0, -2.5)

var owner_id := 0
## The signpost by the street: standing there opens the Homes window. Only the
## lot's own player gets it (the world turns it on).
var sign_zone: InteractZone
## The home on this lot ("" for a free lot) and the add-ons built.
var home_type := ""
var rooms: Array = []
var _owner_name := ""
var _home: Node3D # at HOME_AT: the outside, its path and its doors
var _outside: Node3D
var _doors: Array = [] # see House.doorways()
var _sign: Label3D


func _init() -> void:
	# Town's grass shows through; a low curb marks the lot.
	for i in 4:
		var edge := Node3D.new()
		edge.rotation_degrees.y = 90 * i
		add_child(edge)
		MeshUtil.box(edge, Vector3(LOT, 0.08, 0.15), Color("e9e2cf"), Vector3(0, 0.04, LOT / 2.0))
	_home = Node3D.new()
	_home.name = "Home"
	_home.position = HOME_AT
	add_child(_home)
	_sign = Label3D.new()
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.pixel_size = 0.008
	_sign.outline_size = 12
	_sign.position = Vector3(0, 3.0, LOT / 2.0)
	add_child(_sign)
	var post := HomeShell.signpost()
	post.position = Vector3(3.0, 0, LOT / 2.0 - 0.6)
	add_child(post)
	sign_zone = InteractZone.new().setup("Your homes", "Move to another home, or add rooms", "house_with_garden",
			"Homes", 1.6)
	sign_zone.set_meta("homes", true)
	sign_zone.enabled = false
	sign_zone.position = Vector3(3.0, 0, LOT / 2.0 + 0.4)
	add_child(sign_zone)
	_show_sign()


func set_owner_name(display_name: String) -> void:
	_owner_name = display_name
	_show_sign()


func _show_sign() -> void:
	if _owner_name == "":
		_sign.text = "Free plot"
	elif home_type == "":
		_sign.text = "%s's Home" % _owner_name
	else:
		_sign.text = "%s's %s" % [_owner_name, HomeCatalog.home_name(home_type)]


## Shows the outside of a home ({"type", "rooms", ...}, checked first; its
## furniture isn't needed). Only rebuilt when the home or its rooms change.
func set_home(home: Variant) -> void:
	var clean := HomeCatalog.sanitize(home)
	if clean["type"] == home_type and clean["rooms"] == rooms and _outside != null:
		return
	home_type = clean["type"]
	rooms = clean["rooms"]
	_build()


## Empties the lot (its player left).
func clear() -> void:
	home_type = ""
	rooms = []
	_build()


func _build() -> void:
	if _outside:
		_outside.queue_free()
		_outside = null
	_doors = []
	_show_sign()
	if home_type == "":
		return
	_outside = Node3D.new()
	_outside.name = "Outside"
	_home.add_child(_outside)
	_outside.add_child(HomeShell.exterior(home_type, rooms))
	# The path goes on from the home's walk across the front yard to the street.
	var home := HomeCatalog.info(home_type)
	var front := LOT / 2.0 - HOME_AT.z
	for cell in home.get("walk", []):
		if int(cell[1]) == HomeCatalog.PLOT - 1:
			var x: float = cell[0] + 0.5 - HomeCatalog.PLOT / 2.0
			var z := HomeCatalog.PLOT / 2.0
			while z + 0.5 < front:
				MeshUtil.box(_outside, Vector3(0.84, 0.04, 0.84), MeshUtil.hex(home.get("path")), Vector3(x, 0.02, z + 0.5))
				z += 1.0
	_doors = House.doorways(home_type, rooms)
	var doors := Node3D.new()
	doors.name = "Doors"
	_outside.add_child(doors)
	House.add_triggers(doors, _doors, func(player, index): door_entered.emit(player, index))


## Where you stand after coming out through entrance `index`, and the camera
## turn that looks away from the home: {"position" (global), "yaw"}.
func departure(index: int) -> Dictionary:
	return House.door_spot(_home, _doors, index, true)


## The middle of the lot's front edge, by the street (global).
func front() -> Vector3:
	return to_global(Vector3(0, 0.5, LOT / 2.0 + 1.0))
