extends Node
## Holds the local player's saved profile (name, avatar, pet, house) and
## registers input actions so the project file stays small.

const SAVE_PATH := "user://profile.json"

var profile := {}


func _ready() -> void:
	_register_inputs()
	load_profile()


func default_profile() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return {
		"name_parts": SafeNames.random_name_parts(rng),
		"avatar": AvatarBuilder.default_config(),
		"pet": PetBuilder.default_config(),
		"house": FurnitureCatalog.starter_layout(),
	}


func load_profile() -> void:
	profile = default_profile()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary:
		return
	profile["name_parts"] = SafeNames.clean_name_parts(data.get("name_parts"))
	profile["avatar"] = AvatarBuilder.sanitize(data.get("avatar"))
	var pet := PetBuilder.sanitize(data.get("pet"))
	if data.get("pet") is Dictionary:
		pet["fullness"] = float(data["pet"].get("fullness", 80.0))
		pet["happiness"] = float(data["pet"].get("happiness", 80.0))
	profile["pet"] = pet
	if data.get("house") is Array:
		profile["house"] = House.sanitize_layout(data["house"])


func save_profile() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(profile, "\t"))


func display_name() -> String:
	return SafeNames.display_name(profile.get("name_parts"))


## The part of the profile other players are allowed to see.
func public_profile() -> Dictionary:
	return {
		"name_parts": profile["name_parts"],
		"avatar": profile["avatar"],
		"pet": PetBuilder.sanitize(profile["pet"]),
		"house": profile["house"],
	}


func _register_inputs() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"pet_feed": [KEY_F],
		"pet_play": [KEY_G],
		"build_mode": [KEY_B],
		"build_rotate": [KEY_R],
		"build_style": [KEY_E],
		"go_home": [KEY_H],
		"quick_chat": [KEY_T],
		"menu": [KEY_ESCAPE],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)
