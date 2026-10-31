class_name Pet
extends Node3D
## A pet that follows its owner around. Every peer runs the follow logic
## locally from the owner's synced position, so pets need no network sync of
## their own. Needs (fullness, happiness) are tracked only by the owner.

signal needs_changed(fullness: float, happiness: float)

const FOLLOW_DISTANCE := 1.6
const SPEED := 4.5
const DECAY_PER_SEC := 100.0 / 900.0 # A full bar lasts about 15 minutes.

var config := {}
var owner_node: Node3D
var fullness := 80.0
var happiness := 80.0
var track_needs := false

var _model: Node3D
var _animated := false
var _label: Label3D
var _emote: Label3D
var _emote_y := 1.1
var _emote_time := 0.0
var _gesture_time := 0.0
var _hop := 0.0
var _wander_target := Vector3.ZERO
var _wander_timer := 0.0


func setup(pet_config: Dictionary, follow: Node3D, is_mine: bool) -> void:
	config = PetBuilder.sanitize(pet_config)
	owner_node = follow
	track_needs = is_mine
	if is_mine:
		fullness = clampf(float(pet_config.get("fullness", 80.0)), 0.0, 100.0)
		happiness = clampf(float(pet_config.get("happiness", 80.0)), 0.0, 100.0)
	top_level = true
	_model = PetBuilder.build(config)
	add_child(_model)
	_animated = PetBuilder.play_clip(_model, "Idle")
	var top := Art.bounds(_model).end.y
	_emote_y = top + 0.5
	_label = Label3D.new()
	_label.text = config["name"]
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, top + 0.25, 0)
	_label.pixel_size = 0.004
	_label.outline_size = 8
	add_child(_label)
	_emote = Label3D.new()
	_emote.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_emote.position = Vector3(0, _emote_y, 0)
	_emote.pixel_size = 0.005
	_emote.outline_size = 10
	_emote.modulate = Color("ffe066")
	_emote.visible = false
	add_child(_emote)


func _ready() -> void:
	if owner_node:
		global_position = owner_node.global_position + Vector3(1, 0, 1)


func _process(delta: float) -> void:
	if not owner_node or not is_instance_valid(owner_node):
		return
	_follow(delta)
	if _emote.visible:
		_emote_time -= delta
		_emote.position.y = _emote_y + (1.5 - _emote_time) * 0.2
		if _emote_time <= 0.0:
			_emote.visible = false
	if track_needs:
		var hunger_penalty := 2.0 if fullness < 30.0 else 1.0
		fullness = maxf(fullness - DECAY_PER_SEC * delta, 0.0)
		happiness = maxf(happiness - DECAY_PER_SEC * hunger_penalty * delta, 0.0)
		needs_changed.emit(fullness, happiness)


func _follow(delta: float) -> void:
	var owner_pos := owner_node.global_position
	var to_owner := owner_pos - global_position
	to_owner.y = 0.0
	var target := global_position
	if to_owner.length() > FOLLOW_DISTANCE:
		target = owner_pos - to_owner.normalized() * FOLLOW_DISTANCE
		_wander_timer = 2.0
	else:
		# Pottering around near the owner while they stand still.
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_wander_timer = randf_range(2.0, 4.0)
			_wander_target = owner_pos + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
		if _wander_target != Vector3.ZERO:
			target = _wander_target
	var step := target - global_position
	step.y = 0.0
	var moving := step.length() > 0.05
	var speed := SPEED if to_owner.length() > FOLLOW_DISTANCE else 1.2
	if moving:
		var move := step.normalized() * minf(speed * delta, step.length())
		global_position += move
		rotation.y = lerp_angle(rotation.y, atan2(move.x, move.z), 10.0 * delta)
		_hop += delta * 12.0
	else:
		_hop = 0.0
	global_position.y = lerpf(global_position.y, owner_pos.y, 10.0 * delta)
	if to_owner.length() > 25.0:
		global_position = owner_pos # Teleport if left far behind.
	if _animated:
		_gesture_time -= delta
		if moving:
			PetBuilder.play_clip(_model, "Run" if speed > 2.0 else "Walk")
		elif _gesture_time <= 0.0:
			PetBuilder.play_clip(_model, "Idle")
	else:
		_model.position.y = absf(sin(_hop)) * 0.08 if moving else 0.0


func feed() -> void:
	fullness = minf(fullness + 35.0, 100.0)
	happiness = minf(happiness + 5.0, 100.0)


## Returns which of the species' sounds the pet makes.
func play() -> int:
	happiness = minf(happiness + 25.0, 100.0)
	fullness = maxf(fullness - 3.0, 0.0)
	return randi() % PetBuilder.SOUNDS[PetBuilder.species_name(config)].size()


func show_emote(text: String) -> void:
	_emote.text = text
	_emote.visible = true
	_emote_time = 1.5
	if _animated and PetBuilder.play_clip(_model, ["Gesture", "Sit"], false):
		_gesture_time = 4.0


func save_state() -> Dictionary:
	var out := config.duplicate()
	out["fullness"] = snappedf(fullness, 0.1)
	out["happiness"] = snappedf(happiness, 0.1)
	return out
