class_name StarChase
extends Node3D
## Star Chase, a little game in Starfall Glade. Step onto the glowing ring by
## the crystal and press Play: a star falls somewhere nearby, marked by a beam
## of light, and catching it makes the next one fall. Catch as many as you can
## before the time runs out; every star is worth Acorns.
##
## Like the acorns, each player plays their own game on their own device; the
## stars only appear for the player chasing them.

## Every frame while a game runs: the countdown before it starts (0 once it
## has), stars caught so far, and seconds left.
signal ticked(countdown: float, caught: int, time_left: float)
signal finished(caught: int, reward: int, new_best: bool)

const LENGTH := 45.0
const COUNTDOWN := 3.0
const ACORNS_PER_STAR := 3
## Catching this many stars in one game earns a bonus on top.
const BONUS_AT := 10
const BONUS := 15
const REACH := 1.4
const FALL_TIME := 0.7
const HOVER := 1.3
## Stars land this far (in meters) from the field's center.
const FIELD := Vector2(6.0, 22.0)
const PAD_RADIUS := 1.5
const GLOW := Color("ffd84a")

## The local player, set by the world.
var player: Node3D
## The middle of the area stars fall in, in this node's space.
var field_center := Vector3.ZERO
var zone: InteractZone

var _spots: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()
var _playing := false
var _countdown := 0.0
var _time_left := 0.0
var _caught := 0
var _star: Node3D
var _star_spot := Vector3.ZERO
var _star_age := 0.0
var _last_spot := -1
var _ready_frames := 2
var _time := 0.0
var _pad_ring: MeshInstance3D


func _init() -> void:
	name = "StarChase"
	_rng.randomize()


func _ready() -> void:
	_build_pad()
	zone = InteractZone.new().setup("Star Chase", "Catch falling stars for Acorns!", "glowing_star", "Play",
			PAD_RADIUS + 0.6)
	add_child(zone)


func is_playing() -> bool:
	return _playing


## Starts a game (after a short countdown). Does nothing while one is running.
func start() -> void:
	if _playing or _spots.is_empty():
		return
	_playing = true
	_countdown = COUNTDOWN
	_time_left = LENGTH
	_caught = 0
	_last_spot = -1
	zone.enabled = false
	ticked.emit(_countdown, _caught, _time_left)


## Ends the game early (leaving the land, decorating), paying for stars caught.
func stop() -> void:
	if _playing:
		_finish()


func _physics_process(_delta: float) -> void:
	if _ready_frames <= 0:
		return
	_ready_frames -= 1
	if _ready_frames > 0:
		return
	var candidates: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for i in 90:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf_range(FIELD.x * FIELD.x, FIELD.y * FIELD.y))
		candidates.append(field_center + Vector3(cos(a) * r, 0, sin(a) * r))
	_spots = AcornPickups.clear_spots(self, candidates, 0.9)


func _process(delta: float) -> void:
	_time += delta
	if _pad_ring:
		var mat := _pad_ring.material_override as StandardMaterial3D
		mat.emission_energy_multiplier = 1.2 + 0.6 * sin(_time * 3.0)
	if not _playing:
		return
	if _countdown > 0.0:
		_countdown -= delta
		if _countdown <= 0.0:
			_countdown = 0.0
			_drop_star()
		ticked.emit(_countdown, _caught, _time_left)
		return
	_time_left -= delta
	if _star:
		_star_age += delta
		var fall := clampf(_star_age / FALL_TIME, 0.0, 1.0)
		var land_y := _star_spot.y + HOVER + sin(_time * 3.0) * 0.12
		_star.position = Vector3(_star_spot.x, lerpf(_star_spot.y + 14.0, land_y, 1.0 - pow(1.0 - fall, 3.0)), _star_spot.z)
		(_star.get_node("Pic") as Node3D).scale = Vector3.ONE * (1.0 + 0.12 * sin(_time * 7.0))
		if player and is_instance_valid(player) and player.is_inside_tree() and fall >= 1.0:
			var here := to_local(player.global_position)
			if Vector2(here.x - _star_spot.x, here.z - _star_spot.z).length() < REACH:
				_caught += 1
				_drop_star()
	if _time_left <= 0.0:
		_time_left = 0.0
		_finish()
		return
	ticked.emit(0.0, _caught, _time_left)


func _finish() -> void:
	_playing = false
	zone.enabled = true
	if _star:
		_star.queue_free()
		_star = null
	var reward := reward_for(_caught)
	var best: bool = _caught > int(GameState.profile.get("chase_best", 0))
	if best:
		GameState.profile["chase_best"] = _caught
		GameState.save_profile()
	finished.emit(_caught, reward, best)


static func reward_for(caught: int) -> int:
	return caught * ACORNS_PER_STAR + (BONUS if caught >= BONUS_AT else 0)


## Where the current star is, in world space (for tests and screenshots).
func star_position() -> Vector3:
	return to_global(_star_spot) if _star else Vector3.INF


func _drop_star() -> void:
	if _star:
		_star.queue_free()
	# A new spot each time, not too close to where the last star was.
	var pick := _rng.randi() % _spots.size()
	for attempt in 8:
		if pick != _last_spot and (_last_spot < 0 or _spots[pick].distance_to(_spots[_last_spot]) > 7.0):
			break
		pick = _rng.randi() % _spots.size()
	_last_spot = pick
	_star_spot = _spots[pick]
	_star_age = 0.0
	_star = _build_star()
	_star.position = _star_spot + Vector3(0, 14, 0)
	add_child(_star)


## A big twinkling star with a beam of light under it, seen from far away.
func _build_star() -> Node3D:
	var root := Node3D.new()
	root.name = "Star"
	var pic := Sprite3D.new()
	pic.name = "Pic"
	pic.texture = UiTheme.icon("glowing_star")
	pic.pixel_size = 0.0085
	pic.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pic.shaded = false
	pic.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pic)
	var beam := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.18
	tube.bottom_radius = 0.35
	tube.height = 26.0
	tube.radial_segments = 12
	tube.rings = 1
	beam.mesh = tube
	beam.position.y = 13.0 - HOVER
	var light := StandardMaterial3D.new()
	light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	light.albedo_color = Color(GLOW, 0.32)
	light.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = light
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beam)
	return root


## The glowing ring you stand on to play, with a sign above it.
func _build_pad() -> void:
	MeshUtil.cylinder(self, PAD_RADIUS, PAD_RADIUS + 0.1, 0.06, Color("3c2f66"), Vector3(0, 0.03, 0))
	_pad_ring = MeshUtil.torus(self, PAD_RADIUS - 0.18, PAD_RADIUS, GLOW, Vector3(0, 0.07, 0), Vector3.ZERO, 40)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = GLOW
	glow.emission_enabled = true
	glow.emission = GLOW
	glow.emission_energy_multiplier = 1.2
	_pad_ring.material_override = glow
	_pad_ring.scale = Vector3(1, 0.35, 1)
	var star := Sprite3D.new()
	star.texture = UiTheme.icon("glowing_star")
	star.pixel_size = 0.006
	star.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	star.shaded = false
	star.position.y = 2.2
	add_child(star)
	var sign := Label3D.new()
	sign.text = "Star Chase"
	sign.font = UiTheme.font(700, true)
	sign.font_size = 64
	sign.pixel_size = 0.008
	sign.outline_size = 16
	sign.outline_modulate = Color(0.16, 0.1, 0.3)
	sign.modulate = Color("fff3b0")
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position.y = 3.1
	add_child(sign)
