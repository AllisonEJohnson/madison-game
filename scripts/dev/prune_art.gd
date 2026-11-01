extends SceneTree
## Deletes every licensed art file the game doesn't use, so the web build only
## carries what it needs, and adjusts a few import settings (see
## IMPORT_SETTINGS). CI runs it on a fresh checkout of the art, before
## importing it:
##   godot --headless -s scripts/dev/prune_art.gd
## It deletes files, so don't run it on an art folder you want to keep.
## Fails when a listed model is missing, so a typo can't slip into a build.

var _missing := 0


func _init() -> void:
	var keep := {}
	for path in FurnitureCatalog.art_paths() + PetBuilder.art_paths() + Scenery.art_paths() + AvatarBuilder.art_paths() \
			+ FantasyLand.art_paths() + ShopStall.art_paths() + SkyGarden.art_paths():
		_keep(Art.ROOT + path + ".tscn", keep)
	for path in Lighting.sky_paths():
		_keep(Art.ROOT + path, keep)
	_tune_imports()
	var removed := _prune(Art.ROOT, keep)
	_trim_animations(Art.ROOT + CharacterParts.ANIMATIONS, CharacterParts.CLIPS.values())
	print("[prune_art] kept %d files, removed %d, missing %d" % [keep.size(), removed, _missing])
	quit(1 if _missing > 0 else 0)


## Marks a file and everything it loads, as found in its ext_resource lines.
func _keep(path: String, keep: Dictionary) -> void:
	if keep.has(path):
		return
	if not FileAccess.file_exists(path):
		push_error("Missing art file: " + path)
		_missing += 1
		return
	keep[path] = true
	# Entries look like "uid://…::Type::res://path"; the path is last.
	for dep in ResourceLoader.get_dependencies(path):
		_keep(dep.get_slice("::", dep.get_slice_count("::") - 1), keep)


func _prune(dir_path: String, keep: Dictionary) -> int:
	var removed := 0
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	for sub in dir.get_directories():
		removed += _prune(dir_path.path_join(sub), keep)
	for file in dir.get_files():
		var path := dir_path.path_join(file)
		# Import settings and script ids travel with the file they describe.
		var owner_path := path.trim_suffix(".import").trim_suffix(".uid")
		if not keep.has(owner_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			removed += 1
	return removed


## Import settings that suit the web build better than the packs' own, set
## before the import that follows:
## - The models are colored from small palette pictures of smooth gradients.
##   Graphics-card compression adds a blotchy grain to those, and they're
##   smaller in the download kept lossless.
## - The sky comes as a 4096 x 2048 lossless picture (about 5 MB); a
##   2048 x 1024 lossy one looks the same as a backdrop and is far smaller.
const IMPORT_SETTINGS := {
	"Fantasy/textures/Demonstration_Textures1.png": {"compress/mode": 0},
	"Animals/textures/Demonstration_ColorPalette_1.png": {"compress/mode": 0},
	"Animals/textures/Demonstration_ColorPalette_2.png": {"compress/mode": 0},
	"Bright_Furniture/textures/Demonstration_Textures.png": {"compress/mode": 0},
	"Fantasy/textures/Skybox_8.png": {"compress/mode": 1, "compress/lossy_quality": 0.85,
		"process/size_limit": 2048, "mipmaps/generate": true},
}


func _tune_imports() -> void:
	for path: String in IMPORT_SETTINGS:
		var settings := ConfigFile.new()
		if settings.load(Art.ROOT + path + ".import") != OK:
			continue
		for key: String in IMPORT_SETTINGS[path]:
			settings.set_value("params", key, IMPORT_SETTINGS[path][key])
		settings.save(Art.ROOT + path + ".import")


## The characters' animation library holds 29 clips in a 23 MB file; keeps only
## the ones the game plays.
func _trim_animations(path: String, clips: Array) -> void:
	var library := load(path) as AnimationLibrary
	if library == null:
		push_error("Missing animation library: " + path)
		_missing += 1
		return
	for clip in library.get_animation_list():
		if String(clip) not in clips:
			library.remove_animation(clip)
	ResourceSaver.save(library, path)
	print("[prune_art] kept %d animations in %s" % [library.get_animation_list().size(), path])

