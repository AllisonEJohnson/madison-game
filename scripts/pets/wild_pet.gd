class_name WildPet
extends Node3D
## One wild pet wandering near a spot in a land. When the local player comes
## close it stops, turns to look at them and says hello; standing next to it
## offers "Say hi" (an InteractZone), which opens the card to make friends.
## A kind the player doesn't have yet wears a "New!" sparkle.

## After making friends, once it has hopped away.
signal left

const WANDER_RADIUS := 3.0
const WALK_SPEED := 0.9
## The local player this close makes it stop and look.
const NOTICE := 4.5
const REACH := 2.6

var config := {}
var zone: InteractZone
## The local player, set by WildPets.
var player: Node3D

var _model: Node3D
var _animated := false
var _hover := false
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _idle := 0.0
var _noticed := false
var _new_mark: Label3D
var _label: Label3D
var _emote: Label3D
var _emote_time := 0.0
var _gesture_time := 0.0
var _emote_y := 1.0
var _leaving := -1.0
var _time := 0.0
var _phase := 0.0


func setup(pet_config: Dictionary, spot: Vector3, rng: RandomNumberGenerator) -> WildPet:
	config = PetBuilder.sanitize(pet_config)
	name = "Wild" + str(config["species"]).to_pascal_case()
	_home = spot
	_target = spot
	position = spot
	rotation.y = rng.randf() * TAU
	_phase = rng.randf() * TAU
	_idle = rng.randf_range(0.5, 3.0)
	_model = PetBuilder.build(config)
	add_child(_model)
	_animated = PetBuilder.play_clip(_model, "Idle")
	_hover = PetBuilder.hovers(config)
	var top := Art.bounds(_model).end.y + (PetBuilder.HOVER if _hover else 0.0)
	_label = _tag("Wild " + PetBuilder.species_name(config).to_lower(), top + 0.25, 0.004, Color.WHITE)
	_new_mark = _tag("New!", top + 0.55, 0.006, Color("ffe066"))
	_emote_y = top + 0.9
	_emote = _tag("", _emote_y, 0.005, Color("fff8d6"))
	_emote.visible = false
	var kind := PetBuilder.species_name(config).to_lower()
	zone = InteractZone.new().setup("A wild %s!" % kind, "", "paw_prints", "Say hi", REACH)
	add_child(zone)
	return self


func _tag(text: String, y: float, pixel: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = y
	label.pixel_size = pixel
	label.outline_size = 10
	label.modulate = color
	label.no_depth_test = false
	add_child(label)
	return label


func species() -> String:
	return config["species"]


## Shows "New!" over kinds you don't have, and says so on the "Say hi" card.
func set_owned(owned: bool, pet_name := "") -> void:
	_new_mark.visible = not owned
	zone.hint = ("Like your %s, %s!" % [PetBuilder.species_name(config).to_lower(), pet_name]) if owned \
			else "Make friends and it comes home with you"


func say(text: String) -> void:
	_emote.text = text
	_emote.visible = true
	_emote_time = 1.8


## Waves hello with a happy hop and a sound.
func greet() -> void:
	var sounds := PetBuilder.sounds(config)
	say(sounds[randi() % sounds.size()])
	if _animated and PetBuilder.play_clip(_model, ["Gesture", "Sit"], false):
		_gesture_time = 2.5


## Made friends: a happy hop and a heart, then it scampers off and fades.
func leave() -> void:
	if _leaving >= 0.0:
		return
	_leaving = 0.0
	zone.enabled = false
	_new_mark.visible = false
	_label.visible = false
	say("Yay!")


func _process(delta: float) -> void:
	_time += delta
	_gesture_time -= delta
	if _emote.visible:
		_emote_time -= delta
		_emote.position.y = _emote_y + (1.8 - _emote_time) * 0.15
		_emote.visible = _emote_time > 0.0
	_new_mark.position.y += sin(_time * 3.0 + _phase) * 0.002
	if _leaving >= 0.0:
		_leave_step(delta)
		return
	var near: bool = player != null and is_instance_valid(player) and player.is_inside_tree() \
			and (player.global_position - global_position).length() < NOTICE
	if near:
		var to := player.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(6.0 * delta, 1.0))
		if not _noticed:
			_noticed = true
			say("!")
		_settle(delta, false)
		return
	_noticed = false
	_wander(delta)


func _wander(delta: float) -> void:
	if _idle > 0.0:
		_idle -= delta
		_settle(delta, false)
		if _idle <= 0.0:
			var a := randf() * TAU
			_target = _home + Vector3(cos(a), 0, sin(a)) * randf_range(0.5, WANDER_RADIUS)
		return
	var step := _target - position
	step.y = 0.0
	if step.length() < 0.1:
		_idle = randf_range(2.0, 5.0)
		return
	var move := step.normalized() * minf(WALK_SPEED * delta, step.length())
	position += move
	rotation.y = lerp_angle(rotation.y, atan2(move.x, move.z), minf(8.0 * delta, 1.0))
	_settle(delta, true)


## Plays Walk or Idle, or for models without clips, hops while moving.
## Hovering kinds bob gently in the air either way.
func _settle(_delta: float, moving: bool) -> void:
	if _animated:
		if moving:
			PetBuilder.play_clip(_model, "Walk")
		elif _gesture_time <= 0.0:
			PetBuilder.play_clip(_model, "Idle")
	var y := 0.0
	if _hover:
		y = PetBuilder.HOVER + sin(_time * 2.0 + _phase) * 0.08
	elif not _animated and moving:
		y = absf(sin(_time * 10.0)) * 0.08
	_model.position.y = y


func _leave_step(delta: float) -> void:
	_leaving += delta
	# A couple of happy hops, then it shrinks away in a sparkle.
	if _leaving < 1.2:
		_model.position.y = absf(sin(_leaving * TAU * 1.6)) * 0.25 + (PetBuilder.HOVER if _hover else 0.0)
	else:
		var t := clampf((_leaving - 1.2) / 0.5, 0.0, 1.0)
		scale = Vector3.ONE * maxf(1.0 - t, 0.01)
		if t >= 1.0:
			left.emit()
			queue_free()
