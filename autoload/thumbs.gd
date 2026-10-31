extends Node
## Takes small pictures of 3D models (furniture, outfit options, pets) for
## the interface. `texture()` returns a texture right away and fills it in a
## frame or two later. The newest request is drawn first, so the page on
## screen is ready before pages the player already flipped past.
##
## Pictures that never change (a furniture style) can be kept on disk under
## user://thumbs, so the catalog opens instantly on later visits. Without a
## screen (headless tests) nothing is drawn and textures stay blank.

const SIZE := 128
const STAGES := 3
const DISK_DIR := "user://thumbs/"
## Bump when the framing or lighting changes, so old pictures are redrawn.
const DISK_VERSION := 1
const MAX_CACHED := 800
const MAX_QUEUED := 160

## Camera directions (from the model toward the camera) for each view.
const VIEWS := {
	"item": Vector3(0.75, 0.75, 1.0),
	"body": Vector3(0.35, 0.12, 1.0),
	"head": Vector3(0.45, 0.12, 1.0),
	"face": Vector3(0.12, 0.04, 1.0),
	"torso": Vector3(0.35, 0.12, 1.0),
	"legs": Vector3(0.45, 0.2, 1.0),
	"feet": Vector3(0.7, 0.55, 1.0),
	"back": Vector3(0.7, 0.2, -1.0),
	"pet": Vector3(0.8, 0.4, 1.0),
	"portrait": Vector3(0.3, 0.1, 1.0),
}

var _cache := {} # key -> ImageTexture
var _used := [] # keys, least recently used first
var _queue := [] # jobs: {key, build, view, disk}
var _stages := []
var _enabled := true


func _ready() -> void:
	_enabled = DisplayServer.get_name() != "headless"
	if not _enabled:
		return
	for i in STAGES:
		_stages.append(_make_stage())


## A texture for `key`, drawn from the Node3D that `build` returns. `view` picks
## the camera (see VIEWS); `disk` keeps the picture between runs.
func texture(key: String, build: Callable, view := "item", disk := false) -> Texture2D:
	if _cache.has(key):
		_used.erase(key)
		_used.append(key)
		return _cache[key]
	var tex := ImageTexture.create_from_image(_blank())
	_remember(key, tex)
	if disk and _load_disk(key, tex):
		return tex
	if _enabled:
		_queue.append({"key": key, "build": build, "view": view, "disk": disk, "tex": tex})
		# Old requests are the least likely to still be on screen.
		while _queue.size() > MAX_QUEUED:
			var dropped: Dictionary = _queue.pop_front()
			if _cache.get(dropped["key"]) == dropped["tex"]:
				_cache.erase(dropped["key"])
				_used.erase(dropped["key"])
	return tex


## Drops pictures whose key starts with `prefix` (for example after an outfit
## color changes), so the next request draws them again.
func forget(prefix: String) -> void:
	for key in _cache.keys():
		if key.begins_with(prefix):
			_cache.erase(key)
			_used.erase(key)
	_queue = _queue.filter(func(j): return not j["key"].begins_with(prefix))


func _remember(key: String, tex: ImageTexture) -> void:
	_cache[key] = tex
	_used.append(key)
	while _used.size() > MAX_CACHED:
		_cache.erase(_used.pop_front())


func _blank() -> Image:
	return Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)


func _disk_path(key: String) -> String:
	return DISK_DIR + ("%d:%s" % [DISK_VERSION, key]).md5_text() + ".png"


func _load_disk(key: String, tex: ImageTexture) -> bool:
	var path := _disk_path(key)
	if not FileAccess.file_exists(path):
		return false
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return false
	tex.set_image(img)
	return true


func _process(_delta: float) -> void:
	for stage in _stages:
		if _queue.is_empty():
			return
		if not stage["busy"]:
			_render(stage, _queue.pop_back())


func _render(stage: Dictionary, job: Dictionary) -> void:
	stage["busy"] = true
	var model = job["build"].call() if job["build"].is_valid() else null
	if not model is Node3D:
		stage["busy"] = false
		_cache.erase(job["key"])
		_used.erase(job["key"])
		return
	var holder: Node3D = stage["holder"]
	holder.add_child(model)
	_frame(stage["camera"], model, job["view"])
	var vp: SubViewport = stage["viewport"]
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	model.queue_free()
	stage["busy"] = false
	if img == null or img.is_empty():
		return
	img.convert(Image.FORMAT_RGBA8)
	job["tex"].set_image(img)
	if job["disk"]:
		DirAccess.make_dir_recursive_absolute(DISK_DIR)
		img.save_png(_disk_path(job["key"]))


## Points an orthographic camera so the part of the model the view is about
## fills the picture with a little room around it.
func _frame(camera: Camera3D, model: Node3D, view: String) -> void:
	var box := _bounds(model, model)
	var head := model.find_child("Head", true, false) as Node3D
	match view:
		"head", "face", "portrait":
			if head:
				box = _bounds(head, model)
			else:
				box = _slice(box, 0.75, 1.0)
			if view == "face":
				box = box.grow(-box.size.y * 0.12)
			elif view == "portrait":
				box = box.merge(_slice(_bounds(model, model), 0.62, 0.8))
		"torso":
			box = _slice(box, 0.42, 0.86)
		"legs":
			box = _slice(box, 0.0, 0.58)
		"feet":
			box = _slice(box, 0.0, 0.2)
	var dir: Vector3 = VIEWS.get(view, VIEWS["item"]).normalized()
	var center := box.get_center()
	camera.position = center + dir * (box.size.length() + 4.0)
	camera.look_at(center, Vector3.UP)
	# Fit every corner of the box into the square picture.
	var inv := camera.global_transform.affine_inverse()
	var extent := 0.0
	for i in 8:
		var p := inv * box.get_endpoint(i)
		extent = maxf(extent, maxf(absf(p.x), absf(p.y)))
	camera.size = maxf(extent * 2.0 * 1.08, 0.05)


## The bounds of every mesh under `node`, in `space`'s coordinates.
func _bounds(node: Node3D, space: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var to_space := space.global_transform.affine_inverse()
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mesh: MeshInstance3D in meshes:
		if not mesh.is_visible_in_tree():
			continue
		var box := (to_space * mesh.global_transform) * mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


## A horizontal band of a box, from `low` to `high` (0 is the bottom, 1 the top).
func _slice(box: AABB, low: float, high: float) -> AABB:
	var out := box
	out.position.y = box.position.y + box.size.y * low
	out.size.y = box.size.y * (high - low)
	return out


func _make_stage() -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e8f0ff")
	env.ambient_light_energy = 0.55 if Lighting.is_compatibility() else 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.3
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	vp.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 25, 0)
	sun.light_color = Lighting.SUN_COLOR
	sun.light_energy = Lighting.COMPAT_SUN_ENERGY if Lighting.is_compatibility() else Lighting.SUN_ENERGY
	vp.add_child(sun)
	var holder := Node3D.new()
	vp.add_child(holder)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.05
	camera.far = 100.0
	vp.add_child(camera)
	camera.current = true
	return {"viewport": vp, "holder": holder, "camera": camera, "busy": false}
