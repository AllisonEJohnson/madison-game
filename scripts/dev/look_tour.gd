extends SceneTree
## Dev helper for tuning the game's look: starts a solo world once and saves a
## picture from each of a few fixed views, so lighting changes can be compared
## side by side in both renderers.
##   godot [--rendering-method gl_compatibility] --path . -s scripts/dev/look_tour.gd -- --host --tour=<folder>
## --tour-tag=<suffix> is added to each file name, --tour-only=plaza,glade takes just those views, and
## --tour-set=env.<property>=<value>;sun.<property>=<value> tries other settings without editing code.

const VIEWS := [
	# name, player spot x/z, camera yaw (degrees), pitch, distance
	["plaza", Vector3(0, 0.5, 6), 0.0, -0.25, 7.0],
	["meadow", Vector3(46, 0.5, -38), 160.0, -0.12, 5.5],
	["close", Vector3(3, 0.5, 5), 210.0, -0.05, 2.6],
	["glade", Vector3(590, 0.5, 14), 120.0, -0.2, 6.0],
	["village", Vector3(575, 0.5, 8), 250.0, -0.18, 6.0],
]

var _folder := ""
var _tag := ""
var _t := 0.0
var _view := -1
var _next := 0.0
var _overrides := {} # property -> value, for the environment ("env.x") or sun ("sun.x")
var _only := [] # view names to take; all when empty


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tour="):
			_folder = arg.trim_prefix("--tour=")
		elif arg.begins_with("--tour-tag="):
			_tag = arg.trim_prefix("--tour-tag=")
		elif arg.begins_with("--tour-set="):
			# e.g. --tour-set=env.tonemap_mode=4;sun.light_energy=1.2
			for pair in arg.trim_prefix("--tour-set=").split(";"):
				_overrides[pair.get_slice("=", 0)] = str_to_var(pair.get_slice("=", 1))
		elif arg.begins_with("--tour-only="):
			_only = Array(arg.trim_prefix("--tour-only=").split(","))
	DirAccess.make_dir_recursive_absolute(_folder)
	change_scene_to_file.call_deferred("res://scenes/main_menu.tscn")


func _process(delta: float) -> bool:
	_t += delta
	var world := current_scene
	var player = world.get("local_player") if world else null
	if player == null or _t < 4.0 or _t < _next:
		return false
	if _view >= 0:
		var file := "%s/%s%s.png" % [_folder, VIEWS[_view][0], _tag]
		root.get_viewport().get_texture().get_image().save_png(file)
		print("[tour] saved ", file)
	_view += 1
	var hud = world.get("_hud")
	if hud:
		hud.visible = false
	while _view < VIEWS.size() and not _only.is_empty() and not VIEWS[_view][0] in _only:
		_view += 1
	if _view >= VIEWS.size():
		quit()
		return false
	_apply_overrides(world)
	var v: Array = VIEWS[_view]
	player.teleport(v[1])
	player.set_camera_yaw(deg_to_rad(v[2]))
	player.set_camera_view(v[3], v[4])
	_next = _t + 2.5
	return false


func _apply_overrides(world: Node) -> void:
	var env: Environment = world.get("_env").environment
	var sun: DirectionalLight3D = world.get("_sun")
	for key: String in _overrides:
		var target: Object = env if key.begins_with("env.") else sun
		target.set(key.get_slice(".", 1), _overrides[key])
