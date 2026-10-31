class_name PetBuilder
extends RefCounted
## Builds pet models from a small config: species, coat, colors, and a collar.
## Species with a licensed model pick it by coat; the others (and every species
## when the art isn't installed) are built from shapes using the colors.

const SPECIES := ["Cat", "Dog", "Bunny", "Dragon", "Bird"]
const ART_DIR := "Animals/prefabs/assets/animals/domectic_animals/"
## Coats per species: [name, model, scale]. The models are life-size, so the
## big dogs are shrunk and the small ones grown a little to read well in play.
const COATS := {
	"Cat": [
		["White", "cat/cat_01", 1.3], ["Gray tabby", "cat/cat_02", 1.3],
		["Tuxedo", "cat/cat_03", 1.3], ["Ginger", "cat/cat_04", 1.3],
		["White kitten", "kitty/kitty_01", 1.65], ["Gray kitten", "kitty/kitty_02", 1.65],
		["Peach kitten", "kitty/kitty_03", 1.65], ["Black kitten", "kitty/kitty_04", 1.65],
	],
	"Dog": [
		["Husky", "dog/dog_01", 0.8], ["Silver", "dog/dog_02", 0.8],
		["Brown", "dog/dog_03", 0.8], ["Snowy", "dog/dog_04", 0.8],
		["Smoky", "dog/dog_05", 0.8], ["Black", "dog/dog_06", 0.8],
	],
	"Bird": [
		["Pigeon", "pigeon/pigeon_01", 1.7], ["Dark pigeon", "pigeon/pigeon_02", 1.7],
		["White dove", "pigeon/pigeon_03", 1.7], ["Chick", "chick/chick_01", 2.5],
		["Duck", "duck/duck_01", 1.1],
	],
}
const SOUNDS := {
	"Cat": ["Mew!", "Purr...", "Mrrp?"],
	"Dog": ["Woof!", "Arf arf!", "*wags*"],
	"Bunny": ["*hop hop*", "*nose wiggle*", "Squeak!"],
	"Dragon": ["Rawr!", "*tiny puff of smoke*", "Grr~"],
	"Bird": ["Tweet!", "Chirp chirp!", "*flutter*"],
}


static func default_config() -> Dictionary:
	return {"species": 0, "coat": 3, "name": "Biscuit", "color": "e8a35a", "accent": "fff3e0", "collar": "e04848"}


static func sanitize(config: Variant) -> Dictionary:
	var out := default_config()
	if not config is Dictionary:
		return out
	if config.get("species") is int or config.get("species") is float:
		out["species"] = clampi(int(config["species"]), 0, SPECIES.size() - 1)
	var coat = config.get("coat", out["coat"])
	var last_coat := maxi(coat_names(out).size() - 1, 0)
	out["coat"] = clampi(int(coat), 0, last_coat) if (coat is int or coat is float) else 0
	for key in ["color", "accent", "collar"]:
		var v = config.get(key)
		if v is String and Color.html_is_valid(v):
			out[key] = Color.html(v).to_html(false)
	out["name"] = SafeNames.clean_pet_name(str(config.get("name", out["name"])))
	return out


static func species_name(config: Dictionary) -> String:
	return SPECIES[int(config.get("species", 0))]


static func coat_names(config: Dictionary) -> Array:
	return COATS.get(species_name(config), []).map(func(coat): return coat[0])


## True when this pet shows a licensed model, so its colors don't apply.
static func has_art(config: Dictionary) -> bool:
	return _coat_path(config) != "" and Art.has(_coat_path(config))


static func art_paths() -> Array:
	var out := []
	for species in COATS:
		for coat in COATS[species]:
			out.append(ART_DIR + coat[1])
	return out


static func _coat_path(config: Dictionary) -> String:
	var coats: Array = COATS.get(species_name(config), [])
	if coats.is_empty():
		return ""
	return ART_DIR + coats[clampi(int(config.get("coat", 0)), 0, coats.size() - 1)][1]


## Returns a Node3D with its origin on the ground, facing +Z. A licensed model
## comes with an AnimationPlayer, already playing its idle loop.
static func build(config: Dictionary) -> Node3D:
	config = sanitize(config)
	var root := Node3D.new()
	root.name = "PetModel"
	var model := Art.instance(_coat_path(config)) if _coat_path(config) != "" else null
	if model:
		model.scale = Vector3.ONE * float(COATS[species_name(config)][config["coat"]][2])
		root.add_child(model)
		play_clip(root, "Idle")
		return root
	var c := MeshUtil.hex(config["color"])
	var accent := MeshUtil.hex(config["accent"])
	var collar := MeshUtil.hex(config["collar"])
	var dark := Color("231a16")
	var species := species_name(config)

	if species == "Bird":
		_build_bird(root, c, accent, collar, dark)
		return root

	var body_len := 0.42 if species != "Bunny" else 0.3
	var body_r := 0.14 if species != "Dragon" else 0.15
	MeshUtil.capsule(root, body_r, body_len, c, Vector3(0, 0.26, 0), Vector3(90, 0, 0))
	MeshUtil.sphere(root, body_r * 0.85, accent, Vector3(0, 0.22, 0.05), Vector3(0.8, 0.7, 1.3))
	for x in [-0.08, 0.08]:
		for z in [-0.13, 0.13]:
			if species == "Bunny" and z > 0:
				MeshUtil.sphere(root, 0.05, c, Vector3(x, 0.06, z + 0.05))
			else:
				MeshUtil.cylinder(root, 0.04, 0.045, 0.18, c, Vector3(x, 0.09, z))

	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.44, 0.22 if species != "Bunny" else 0.16)
	root.add_child(head)
	MeshUtil.sphere(head, 0.13, c)
	MeshUtil.torus(root, 0.07, 0.09, collar, head.position + Vector3(0, -0.1, -0.03), Vector3(70, 0, 0))
	for side in [-1, 1]:
		MeshUtil.sphere(head, 0.025, dark, Vector3(0.05 * side, 0.025, 0.115))
		MeshUtil.sphere(head, 0.008, Color.WHITE, Vector3(0.05 * side + 0.008, 0.035, 0.135))

	match species:
		"Cat":
			MeshUtil.sphere(head, 0.05, accent, Vector3(0, -0.04, 0.1), Vector3(1.2, 0.8, 0.8))
			MeshUtil.sphere(head, 0.015, Color("f08a9a"), Vector3(0, -0.015, 0.14))
			for side in [-1, 1]:
				MeshUtil.cylinder(head, 0.0, 0.05, 0.1, c, Vector3(0.07 * side, 0.12, 0), Vector3(0, 0, -15 * side))
			MeshUtil.capsule(root, 0.03, 0.38, c, Vector3(0, 0.42, -0.3), Vector3(-30, 0, 0))
		"Dog":
			MeshUtil.capsule(head, 0.06, 0.14, accent, Vector3(0, -0.04, 0.11), Vector3(90, 0, 0))
			MeshUtil.sphere(head, 0.025, dark, Vector3(0, -0.02, 0.18))
			for side in [-1, 1]:
				MeshUtil.capsule(head, 0.035, 0.16, c.darkened(0.2), Vector3(0.12 * side, -0.02, -0.01), Vector3(0, 0, 15 * side))
			MeshUtil.capsule(root, 0.03, 0.2, c, Vector3(0, 0.38, -0.27), Vector3(-50, 0, 0))
		"Bunny":
			MeshUtil.sphere(head, 0.014, Color("f08a9a"), Vector3(0, -0.01, 0.13))
			for side in [-1, 1]:
				MeshUtil.capsule(head, 0.035, 0.26, c, Vector3(0.05 * side, 0.2, -0.02), Vector3(-10, 0, -8 * side))
				MeshUtil.capsule(head, 0.018, 0.2, Color("f6a5b8"), Vector3(0.05 * side, 0.2, 0.0), Vector3(-10, 0, -8 * side))
			MeshUtil.sphere(root, 0.06, accent, Vector3(0, 0.28, -0.2))
		"Dragon":
			MeshUtil.capsule(head, 0.06, 0.14, c, Vector3(0, -0.03, 0.1), Vector3(90, 0, 0))
			for side in [-1, 1]:
				MeshUtil.cylinder(head, 0.0, 0.025, 0.1, accent, Vector3(0.06 * side, 0.13, -0.03), Vector3(-25, 0, 0))
				MeshUtil.box(root, Vector3(0.28, 0.02, 0.18), Color(accent, 0.9), Vector3(0.18 * side, 0.4, -0.02), Vector3(0, 0, 30 * side))
			for i in 4:
				MeshUtil.cylinder(root, 0.0, 0.025, 0.06, accent, Vector3(0, 0.42 - i * 0.02, 0.05 - i * 0.1))
			MeshUtil.cylinder(root, 0.01, 0.06, 0.4, c, Vector3(0, 0.22, -0.38), Vector3(-75, 0, 0))
	return root


## Plays the model's clip whose name ends with one of `suffixes` (e.g. "Walk"
## finds "Cat_Walk"). Returns false for shape models, which have no clips.
static func play_clip(model: Node3D, suffixes: Variant, loop := true, blend := 0.25) -> bool:
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not player:
		return false
	for suffix in (suffixes if suffixes is Array else [suffixes]):
		for clip in player.get_animation_list():
			if clip.ends_with("_" + suffix):
				# The pack's clips are all set to play once.
				player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
				if player.current_animation != clip:
					player.play(clip, blend)
				return true
	return false


static func _build_bird(root: Node3D, c: Color, accent: Color, collar: Color, dark: Color) -> void:
	MeshUtil.sphere(root, 0.15, c, Vector3(0, 0.3, 0), Vector3(1, 1.05, 1.2))
	MeshUtil.sphere(root, 0.11, accent, Vector3(0, 0.27, 0.07), Vector3(1, 1, 0.8))
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.5, 0.08)
	root.add_child(head)
	MeshUtil.sphere(head, 0.1, c)
	MeshUtil.cylinder(head, 0.0, 0.03, 0.08, Color("f2b134"), Vector3(0, -0.01, 0.12), Vector3(90, 0, 0))
	for side in [-1, 1]:
		MeshUtil.sphere(head, 0.02, dark, Vector3(0.05 * side, 0.02, 0.08))
		MeshUtil.box(root, Vector3(0.03, 0.14, 0.2), c.darkened(0.15), Vector3(0.15 * side, 0.3, -0.02), Vector3(10, 0, 10 * side))
		MeshUtil.cylinder(root, 0.012, 0.012, 0.16, Color("f2b134"), Vector3(0.05 * side, 0.08, 0))
	MeshUtil.box(head, Vector3(0.02, 0.07, 0.06), collar, Vector3(0, 0.1, 0))
	MeshUtil.box(root, Vector3(0.12, 0.02, 0.18), c.darkened(0.2), Vector3(0, 0.26, -0.2), Vector3(-25, 0, 0))
