class_name Player
extends CharacterBody3D
## A player character. The owning peer has authority: it reads input, moves,
## and replicates `sync_position` / `sync_yaw` to everyone else, who smooth
## toward those values. Each player brings their pet along as a child node.

signal pet_needs_changed(fullness: float, happiness: float)

const SPEED := 5.0
const JUMP_VELOCITY := 4.8
const MOUSE_SENSITIVITY := 0.006

@export var sync_position := Vector3.ZERO
@export var sync_yaw := 0.0

var peer_id := 1
var display_name := ""
var plot_index := -1
var input_enabled := true
var pet: Pet
var camera: Camera3D

var _model: Node3D
var _avatar: Node3D
var _pivot: Node3D
var _arm: SpringArm3D
var _yaw := 0.0
var _pitch := -0.35
var _walk_time := 0.0
var _air_time := 0.0
var _last_pos := Vector3.ZERO
var _bubble: Label3D
var _bubble_time := 0.0
var _name_label: Label3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


## Called by the world's spawner before the node enters the tree, on every peer.
func setup(data: Dictionary) -> void:
	peer_id = int(data["id"])
	name = str(peer_id)
	plot_index = int(data.get("plot", -1))
	display_name = SafeNames.display_name(data.get("name_parts"))
	position = data.get("spawn", Vector3.ZERO)
	sync_position = position

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)

	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	var avatar_config := AvatarBuilder.sanitize(data.get("avatar", {}))
	_avatar = AvatarBuilder.build(avatar_config)
	_model.add_child(_avatar)
	var head_top := AvatarBuilder.head_top(avatar_config)

	_name_label = Label3D.new()
	_name_label.text = display_name
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.position.y = head_top + 0.35
	_name_label.pixel_size = 0.005
	_name_label.outline_size = 10
	add_child(_name_label)

	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.position.y = head_top + 0.7
	_bubble.pixel_size = 0.005
	_bubble.outline_size = 12
	_bubble.modulate = Color("fff8d6")
	_bubble.visible = false
	add_child(_bubble)

	var is_mine: bool = peer_id == int(data.get("viewer_id", -1))
	set_pet(data.get("pet", {}), is_mine)

	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_interval = 0.05
	var cfg := SceneReplicationConfig.new()
	for prop in [NodePath(".:sync_position"), NodePath(".:sync_yaw")]:
		cfg.add_property(prop)
		cfg.property_set_spawn(prop, true)
		cfg.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)

	set_multiplayer_authority(peer_id)


func _ready() -> void:
	_last_pos = position
	if is_multiplayer_authority():
		_pivot = Node3D.new()
		_pivot.position.y = 1.5
		add_child(_pivot)
		_arm = SpringArm3D.new()
		_arm.spring_length = 6.0
		_arm.margin = 0.2
		_arm.add_excluded_object(get_rid())
		_pivot.add_child(_arm)
		camera = Camera3D.new()
		camera.fov = 65.0
		_arm.add_child(camera)
		camera.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		look(-event.relative.x * MOUSE_SENSITIVITY, -event.relative.y * MOUSE_SENSITIVITY)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(-0.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(0.5)


## Turns the camera around the player (right-drag, or a finger on a touch screen).
func look(yaw: float, pitch: float) -> void:
	_yaw += yaw
	_pitch = clampf(_pitch + pitch, -1.2, 0.3)


## Moves the camera closer (negative) or further away, in meters.
func zoom(meters: float) -> void:
	_arm.spring_length = clampf(_arm.spring_length + meters, 2.0, 14.0)


## Scales how far away the camera is (pinching on a touch screen).
func zoom_by(factor: float) -> void:
	_arm.spring_length = clampf(_arm.spring_length * factor, 2.0, 14.0)


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_move_locally(delta)
	else:
		# Far jumps (through a door or portal) snap instead of gliding across the map.
		if position.distance_squared_to(sync_position) > 400.0:
			position = sync_position
		position = position.lerp(sync_position, minf(15.0 * delta, 1.0))
		_model.rotation.y = lerp_angle(_model.rotation.y, sync_yaw, minf(15.0 * delta, 1.0))
	var speed := Vector2(position.x - _last_pos.x, position.z - _last_pos.z).length() / maxf(delta, 0.0001)
	var climb := (position.y - _last_pos.y) / maxf(delta, 0.0001)
	_last_pos = position
	_animate(delta, speed, climb)
	if _bubble.visible:
		_bubble_time -= delta
		_bubble.visible = _bubble_time > 0.0


func _move_locally(delta: float) -> void:
	_pivot.rotation = Vector3(_pitch, _yaw, 0)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var dir := Vector3.ZERO
	if input_enabled and not _typing():
		# The touch joystick pushes softly or hard, so a small push walks.
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back", 0.05)
		dir = (Basis(Vector3.UP, _yaw) * Vector3(input.x, 0, input.y)).limit_length(1.0)
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	move_and_slide()
	if position.y < -20.0:
		position = Vector3(0, 2, 0)
		velocity = Vector3.ZERO
	if dir.length() > 0.02:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(dir.x, dir.z), minf(12.0 * delta, 1.0))
	sync_position = position
	sync_yaw = _model.rotation.y


func _typing() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit


func _animate(delta: float, speed: float, climb: float) -> void:
	# Rising or falling fast means a jump or a drop; the short hold stops the
	# pose flickering at the top of a jump.
	_air_time = 0.25 if absf(climb) > 1.0 else _air_time - delta
	var state := "Fall" if _air_time > 0.0 else "Run" if speed > 3.0 else "Walk" if speed > 0.5 else "Idle"
	if AvatarBuilder.play(_avatar, state, clampf(speed / SPEED, 0.6, 1.3) if state == "Run" else 1.0):
		return
	var swing := 0.0
	if speed > 0.5:
		_walk_time += delta * 9.0
		swing = sin(_walk_time) * 0.6
	else:
		_walk_time = 0.0
	for limb in [["LegL", 1.0], ["LegR", -1.0], ["ArmL", -0.8], ["ArmR", 0.8]]:
		var node := _avatar.get_node_or_null(limb[0]) as Node3D
		if node:
			node.rotation.x = lerpf(node.rotation.x, swing * limb[1], minf(12.0 * delta, 1.0))


## Dresses the character in a new avatar config (say, after buying a hat).
func set_avatar(config: Dictionary) -> void:
	var avatar_config := AvatarBuilder.sanitize(config)
	if _avatar:
		_avatar.free()
	_avatar = AvatarBuilder.build(avatar_config)
	_model.add_child(_avatar)
	var head_top := AvatarBuilder.head_top(avatar_config)
	_name_label.position.y = head_top + 0.35
	_bubble.position.y = head_top + 0.7


## Brings a different pet along (say, a new friend from the wild). The new
## one starts beside you.
func set_pet(config: Dictionary, is_mine: bool) -> void:
	var at := Vector3.INF
	if pet:
		at = pet.global_position if pet.is_inside_tree() else Vector3.INF
		remove_child(pet)
		pet.queue_free()
	pet = Pet.new()
	pet.name = "Pet"
	pet.setup(config, self, is_mine)
	pet.needs_changed.connect(func(f, h): pet_needs_changed.emit(f, h))
	add_child(pet)
	if at != Vector3.INF:
		pet.global_position = at


func teleport(world_pos: Vector3) -> void:
	position = world_pos
	_last_pos = world_pos
	velocity = Vector3.ZERO
	sync_position = position


func camera_yaw() -> float:
	return _yaw


func set_camera_yaw(value: float) -> void:
	_yaw = value


## Turns the camera to `value` and the player with it, so you see their back
## (walking forward goes that way).
func face(value: float) -> void:
	set_camera_yaw(value)
	_model.rotation.y = value + PI
	sync_yaw = _model.rotation.y


## Tilts and pulls back the camera, within the same limits as the mouse.
func set_camera_view(pitch: float, distance: float) -> void:
	_pitch = clampf(pitch, -1.2, 0.3)
	_arm.spring_length = clampf(distance, 2.0, 14.0)


## Shows a speech bubble. Only called with preset phrases (see SafeNames).
func say(text: String) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble_time = 4.0


## The owner applies the feed/play effect locally, then calls this on everyone
## so the pet's reaction is visible to all. Only indices travel over the wire.
@rpc("authority", "call_local", "reliable")
func pet_reaction(action: int, sound: int) -> void:
	if not pet:
		return
	var sounds: Array = PetBuilder.sounds(pet.config)
	pet.show_emote("Yum!" if action == 0 else sounds[clampi(sound, 0, sounds.size() - 1)])
