class_name PetBuilder
extends RefCounted
## Every kind of pet and how to build one from a small config: species,
## coat, name, colors, and a collar. Species with a licensed model pick it by
## coat; without the art, each species is built from shapes in its colors.
##
## Cats, dogs and birds live with every player from the start ("home" pets).
## Every other kind lives in the wild, in one land ("land"), where players
## find it and make friends with it (see WildPets and PetCollection). Most
## wild kinds can also be had at once for Stardust ("stardust", the price);
## the few without a price can only be found. "rare" ones turn up less often.

## Species ids in the order they're listed (home pets first, then by land).
## Configs and saves use these ids.
const SPECIES := {
	"cat": {
		"name": "Cat", "home": true, "shape": "cat", "colors": ["e8a35a", "fff3e0"],
		"sounds": ["Mew!", "Purr...", "Mrrp?"],
		# [name, model, scale]. The models are life-size, so the big ones are
		# shrunk and the small ones grown a little to read well in play.
		"coats": [
			["White", "domectic_animals/cat/cat_01", 1.3], ["Gray tabby", "domectic_animals/cat/cat_02", 1.3],
			["Tuxedo", "domectic_animals/cat/cat_03", 1.3], ["Ginger", "domectic_animals/cat/cat_04", 1.3],
			["White kitten", "domectic_animals/kitty/kitty_01", 1.65],
			["Gray kitten", "domectic_animals/kitty/kitty_02", 1.65],
			["Peach kitten", "domectic_animals/kitty/kitty_03", 1.65],
			["Black kitten", "domectic_animals/kitty/kitty_04", 1.65],
		],
	},
	"dog": {
		"name": "Dog", "home": true, "shape": "dog", "colors": ["c49a6c", "fff3e0"],
		"sounds": ["Woof!", "Arf arf!", "*wags*"],
		"coats": [
			["Husky", "domectic_animals/dog/dog_01", 0.8], ["Silver", "domectic_animals/dog/dog_02", 0.8],
			["Brown", "domectic_animals/dog/dog_03", 0.8], ["Snowy", "domectic_animals/dog/dog_04", 0.8],
			["Smoky", "domectic_animals/dog/dog_05", 0.8], ["Black", "domectic_animals/dog/dog_06", 0.8],
		],
	},
	"bird": {
		"name": "Bird", "home": true, "shape": "bird", "colors": ["8fb8e8", "fff3e0"],
		"sounds": ["Tweet!", "Chirp chirp!", "*flutter*"],
		"coats": [
			["Pigeon", "domectic_animals/pigeon/pigeon_01", 1.7], ["Dark pigeon", "domectic_animals/pigeon/pigeon_02", 1.7],
			["White dove", "domectic_animals/pigeon/pigeon_03", 1.7], ["Chick", "domectic_animals/chick/chick_01", 2.5],
			["Duck", "domectic_animals/duck/duck_01", 1.1],
		],
	},
	# Hometown: around the houses and at the edge of the woods.
	"raccoon": {
		"name": "Raccoon", "land": "town", "stardust": 25, "shape": "cat", "colors": ["8a8a8a", "e8e8e8"],
		"sounds": ["*chitter chitter*", "*sniff sniff*", "Hee hee!"],
		"coats": [["Masked", "forest_animals/raccoon/raccoon_01", 1.35]],
	},
	"fox": {
		"name": "Fox", "land": "town", "stardust": 25, "shape": "cat", "colors": ["e8742a", "fff3e0"],
		"sounds": ["Yip yip!", "*pounce!*", "*fluffy tail wag*"],
		"coats": [["Red", "forest_animals/fox/fox_01", 1.0]],
	},
	"fawn": {
		"name": "Fawn", "land": "town", "stardust": 25, "shape": "bunny", "colors": ["b07a4a", "f6e6d0"],
		"sounds": ["Meep?", "*hop hop*", "*ear flick*"],
		"coats": [["Brown", "forest_animals/deer_cub/deer_cub_01", 0.75],
			["Golden", "forest_animals/deer_cub/deer_cub_02", 0.75]],
	},
	# Starfall Glade.
	"bear_cub": {
		"name": "Bear cub", "land": "glade", "stardust": 40, "shape": "dog", "colors": ["7a4a2a", "c9a27a"],
		"sounds": ["Grrr~", "*big yawn*", "*rolls over*"],
		"coats": [["Brown", "forest_animals/bear_cub/bear_cub_01", 0.9],
			["Black", "forest_animals/bear_cub/bear_cub_02", 0.9]],
	},
	"panda_cub": {
		"name": "Panda cub", "land": "glade", "stardust": 50, "shape": "dog", "colors": ["f4f4f4", "1f1f1f"],
		"sounds": ["*munch munch*", "*tumble!*", "Squeak!"],
		"coats": [["Panda", "exotic_animals/panda_cub/panda_cub_01", 0.9]],
	},
	"koala": {
		"name": "Koala", "land": "glade", "stardust": 40, "shape": "bunny", "colors": ["9a9aa2", "f0f0f0"],
		"sounds": ["*sleepy blink*", "*hug!*", "Mmm, leaves!"],
		"coats": [["Gray", "exotic_animals/koala/koala_01", 1.7]],
	},
	"tiger_cub": {
		"name": "Tiger cub", "land": "glade", "stardust": 40, "shape": "cat", "colors": ["f08a2a", "fff3e0"],
		"sounds": ["Rawr!", "*pounce!*", "Purrr..."],
		"coats": [["Orange", "exotic_animals/tiger_cub/tiger_cub_01", 0.85],
			["Snow", "exotic_animals/tiger_cub/tiger_cub_02", 0.85]],
	},
	"glimmer_cub": {
		"name": "Glimmer cub", "land": "glade", "rare": true, "shape": "cat", "colors": ["3fd8f0", "e8fbff"],
		"sounds": ["*sparkle*", "Rawr~!", "*twinkly purr*"],
		"coats": [["Glimmer", "@Fantasy/prefabs/assets/animals/fantasy_animal_005", 0.7]],
	},
	"honey_bear": {
		"name": "Honey bear", "land": "glade", "rare": true, "shape": "dog", "colors": ["f2c04a", "6f7f8f"],
		"sounds": ["*hums*", "Yum, honey!", "*happy wiggle*"],
		"coats": [["Honey", "@Fantasy/prefabs/assets/animals/fantasy_animal_008", 0.75]],
	},
	# The Sky Garden: it's chilly up in the clouds.
	"penguin_chick": {
		"name": "Penguin chick", "land": "sky", "stardust": 60, "shape": "bird", "colors": ["8a8f99", "ffffff"],
		"sounds": ["Peep peep!", "*waddle waddle*", "*flap flap*"],
		"coats": [["Fluffy", "polar_animals/pinguin_cub/pinguin_cub_01", 0.9]],
	},
	"polar_cub": {
		"name": "Polar bear cub", "land": "sky", "stardust": 60, "shape": "dog", "colors": ["f6f3ea", "e0dccf"],
		"sounds": ["*snow sniff*", "Grrr~", "*belly slide*"],
		"coats": [["Snowy", "polar_animals/polar_bear_cub/polar_bear_cub_01", 0.9]],
	},
	"lion_cub": {
		"name": "Lion cub", "land": "sky", "stardust": 60, "shape": "cat", "colors": ["e8b85a", "fff3e0"],
		"sounds": ["Mrrrow!", "*tiny roar*", "*sunny stretch*"],
		"coats": [["Golden", "savanna_animals/lion_cub/lion_cub_01", 0.85]],
	},
	"pegasus": {
		"name": "Pegasus", "land": "sky", "rare": true, "hover": true, "shape": "dragon", "colors": ["ffffff", "f2d36b"],
		"sounds": ["Neigh!", "*flutter flutter*", "*sparkly whinny*"],
		"coats": [["Cloud", "@Fantasy/prefabs/assets/animals/fantasy_animal_009", 0.28]],
	},
}
## Where the Animals pack keeps its animals. Coats starting with "@" are a
## path from the art root instead (the Fantasy pack's creatures).
const ART_DIR := "Animals/prefabs/assets/animals/"
## Saves from before species had names stored a number; bunnies and dragons
## have no models, so they became the closest kinds that do.
const LEGACY := ["cat", "dog", "koala", "pegasus", "bird"]
## How high a hovering pet floats.
const HOVER := 0.35


static func default_config() -> Dictionary:
	return {"species": "cat", "coat": 3, "name": "Biscuit", "color": "e8a35a", "accent": "fff3e0", "collar": "e04848"}


## The config of a new pet of a kind, in its own colors.
static func new_config(species: String, coat := 0, pet_name := "") -> Dictionary:
	var info: Dictionary = SPECIES.get(species, SPECIES["cat"])
	var out := default_config()
	out["species"] = species if SPECIES.has(species) else "cat"
	out["coat"] = coat
	out["color"] = info["colors"][0]
	out["accent"] = info["colors"][1]
	if pet_name != "":
		out["name"] = pet_name
	return sanitize(out)


static func sanitize(config: Variant) -> Dictionary:
	var out := default_config()
	if not config is Dictionary:
		return out
	out["species"] = species_id(config)
	var coat = config.get("coat", out["coat"])
	var last_coat := maxi(coat_names(out).size() - 1, 0)
	out["coat"] = clampi(int(coat), 0, last_coat) if (coat is int or coat is float) else 0
	for key in ["color", "accent", "collar"]:
		var v = config.get(key)
		if v is String and Color.html_is_valid(v):
			out[key] = Color.html(v).to_html(false)
	out["name"] = SafeNames.clean_pet_name(str(config.get("name", out["name"])))
	return out


## The species id of a config ("fox"), reading old numbered saves too.
static func species_id(config: Dictionary) -> String:
	var s = config.get("species", "cat")
	if s is String and SPECIES.has(s):
		return s
	if (s is int or s is float) and int(s) >= 0 and int(s) < LEGACY.size():
		return LEGACY[int(s)]
	return "cat"


## The kind's name for people: "Panda cub".
static func species_name(config: Dictionary) -> String:
	return SPECIES[species_id(config)]["name"]


static func info(species: String) -> Dictionary:
	return SPECIES.get(species, {})


static func sounds(config: Dictionary) -> Array:
	return SPECIES[species_id(config)]["sounds"]


static func coat_names(config: Dictionary) -> Array:
	return SPECIES[species_id(config)]["coats"].map(func(coat): return coat[0])


## Wild kinds that live in a land ("town", "glade" or "sky").
static func wild_in(land: String) -> Array:
	return SPECIES.keys().filter(func(s): return SPECIES[s].get("land", "") == land)


## The Stardust price of a kind, or 0 when it can only be found in the wild.
static func stardust_price(species: String) -> int:
	return int(SPECIES.get(species, {}).get("stardust", 0))


static func is_home(species: String) -> bool:
	return SPECIES.get(species, {}).get("home", false)


## True when this pet shows a licensed model, so its colors don't apply.
static func has_art(config: Dictionary) -> bool:
	return Art.has(_coat_path(config))


static func art_paths() -> Array:
	var out := []
	for species in SPECIES:
		for coat in SPECIES[species]["coats"]:
			out.append(_path(coat[1]))
	return out


static func _path(model: String) -> String:
	return model.substr(1) if model.begins_with("@") else ART_DIR + model


static func _coat(config: Dictionary) -> Array:
	var coats: Array = SPECIES[species_id(config)]["coats"]
	return coats[clampi(int(config.get("coat", 0)), 0, coats.size() - 1)]


static func _coat_path(config: Dictionary) -> String:
	return _path(_coat(config)[1])


## Returns a Node3D with its origin on the ground, facing +Z. A licensed model
## comes with an AnimationPlayer, already playing its idle loop (the Fantasy
## pack's creatures have none, so they hop or hover instead).
static func build(config: Dictionary) -> Node3D:
	config = sanitize(config)
	var root := Node3D.new()
	root.name = "PetModel"
	var model := Art.instance(_coat_path(config))
	if model:
		model.scale = Vector3.ONE * float(_coat(config)[2])
		root.add_child(model)
		play_clip(root, "Idle")
		return root
	var c := MeshUtil.hex(config["color"])
	var accent := MeshUtil.hex(config["accent"])
	var collar := MeshUtil.hex(config["collar"])
	var dark := Color("231a16")
	var shape: String = SPECIES[config["species"]]["shape"]

	if shape == "bird":
		_build_bird(root, c, accent, collar, dark)
		return root

	var body_len := 0.42 if shape != "bunny" else 0.3
	var body_r := 0.14 if shape != "dragon" else 0.15
	MeshUtil.capsule(root, body_r, body_len, c, Vector3(0, 0.26, 0), Vector3(90, 0, 0))
	MeshUtil.sphere(root, body_r * 0.85, accent, Vector3(0, 0.22, 0.05), Vector3(0.8, 0.7, 1.3))
	for x in [-0.08, 0.08]:
		for z in [-0.13, 0.13]:
			if shape == "bunny" and z > 0:
				MeshUtil.sphere(root, 0.05, c, Vector3(x, 0.06, z + 0.05))
			else:
				MeshUtil.cylinder(root, 0.04, 0.045, 0.18, c, Vector3(x, 0.09, z))

	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.44, 0.22 if shape != "bunny" else 0.16)
	root.add_child(head)
	MeshUtil.sphere(head, 0.13, c)
	MeshUtil.torus(root, 0.07, 0.09, collar, head.position + Vector3(0, -0.1, -0.03), Vector3(70, 0, 0))
	for side in [-1, 1]:
		MeshUtil.sphere(head, 0.025, dark, Vector3(0.05 * side, 0.025, 0.115))
		MeshUtil.sphere(head, 0.008, Color.WHITE, Vector3(0.05 * side + 0.008, 0.035, 0.135))

	match shape:
		"cat":
			MeshUtil.sphere(head, 0.05, accent, Vector3(0, -0.04, 0.1), Vector3(1.2, 0.8, 0.8))
			MeshUtil.sphere(head, 0.015, Color("f08a9a"), Vector3(0, -0.015, 0.14))
			for side in [-1, 1]:
				MeshUtil.cylinder(head, 0.0, 0.05, 0.1, c, Vector3(0.07 * side, 0.12, 0), Vector3(0, 0, -15 * side))
			MeshUtil.capsule(root, 0.03, 0.38, c, Vector3(0, 0.42, -0.3), Vector3(-30, 0, 0))
		"dog":
			MeshUtil.capsule(head, 0.06, 0.14, accent, Vector3(0, -0.04, 0.11), Vector3(90, 0, 0))
			MeshUtil.sphere(head, 0.025, dark, Vector3(0, -0.02, 0.18))
			for side in [-1, 1]:
				MeshUtil.capsule(head, 0.035, 0.16, c.darkened(0.2), Vector3(0.12 * side, -0.02, -0.01), Vector3(0, 0, 15 * side))
			MeshUtil.capsule(root, 0.03, 0.2, c, Vector3(0, 0.38, -0.27), Vector3(-50, 0, 0))
		"bunny":
			MeshUtil.sphere(head, 0.014, Color("f08a9a"), Vector3(0, -0.01, 0.13))
			for side in [-1, 1]:
				MeshUtil.capsule(head, 0.035, 0.26, c, Vector3(0.05 * side, 0.2, -0.02), Vector3(-10, 0, -8 * side))
				MeshUtil.capsule(head, 0.018, 0.2, Color("f6a5b8"), Vector3(0.05 * side, 0.2, 0.0), Vector3(-10, 0, -8 * side))
			MeshUtil.sphere(root, 0.06, accent, Vector3(0, 0.28, -0.2))
		"dragon":
			MeshUtil.capsule(head, 0.06, 0.14, c, Vector3(0, -0.03, 0.1), Vector3(90, 0, 0))
			for side in [-1, 1]:
				MeshUtil.cylinder(head, 0.0, 0.025, 0.1, accent, Vector3(0.06 * side, 0.13, -0.03), Vector3(-25, 0, 0))
				MeshUtil.box(root, Vector3(0.28, 0.02, 0.18), Color(accent, 0.9), Vector3(0.18 * side, 0.4, -0.02), Vector3(0, 0, 30 * side))
			for i in 4:
				MeshUtil.cylinder(root, 0.0, 0.025, 0.06, accent, Vector3(0, 0.42 - i * 0.02, 0.05 - i * 0.1))
			MeshUtil.cylinder(root, 0.01, 0.06, 0.4, c, Vector3(0, 0.22, -0.38), Vector3(-75, 0, 0))
	return root


## True for kinds that float above the ground instead of walking.
static func hovers(config: Dictionary) -> bool:
	return SPECIES[species_id(config)].get("hover", false)


## Plays the model's clip whose name ends with one of `suffixes` (e.g. "Walk"
## finds "Cat_Walk"). Returns false for models without clips.
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
