class_name CharacterParts
extends RefCounted
## The licensed Cute Characters pack: the parts the character creator offers and
## how to dress the pack's rigged character in them. AvatarBuilder uses this
## when the art is installed and its own shape avatar otherwise.
##
## A character is the pack's skeleton plus one skinned mesh per part. Each part
## scene carries its own copy of the skeleton, so its meshes move onto the
## character's skeleton (the pack's demo does the same).

const PARTS := "Cute_Characters/prefabs/assets/"
const SKELETON := "Cute_Characters/prefabs/characters/base/skeleton_01"
## The animation library and the clips the game plays. The web build drops the
## other clips (see scripts/dev/prune_art.gd), which saves about 20 MB.
const ANIMATIONS := "Cute_Characters/animations/characters/skeleton_01.tres"
const CLIPS := {"Idle": "Idle_Relaxed", "Walk": "Walk_Forward", "Run": "Run_Forward", "Fall": "Fall"}
## The pack's characters are 1.15 m tall; this makes them kid height next to the
## furniture.
const SCALE := 1.3
const HEIGHT := 1.15
const FACE_Y := 0.86
## Boxes around parts of the unscaled character, for framing pictures of it
## (see Thumbs): the head without its hair, and the bands the clothes cover.
## Anything wholly above NECK_Y, like hair, hats and ears, counts as the head.
const NECK_Y := 0.55
const HEAD_BOX := AABB(Vector3(-0.31, 0.57, -0.26), Vector3(0.62, 0.56, 0.52))
const VIEW_BOXES := {
	"torso": AABB(Vector3(-0.3, 0.27, -0.15), Vector3(0.6, 0.35, 0.3)),
	"legs": AABB(Vector3(-0.2, 0.0, -0.15), Vector3(0.4, 0.4, 0.3)),
	"feet": AABB(Vector3(-0.16, 0.0, -0.13), Vector3(0.32, 0.13, 0.3)),
	"portrait": AABB(Vector3(-0.32, 0.42, -0.2), Vector3(0.64, 0.73, 0.4)),
}

## The pack's 16 bodies differ only in color, so the game uses one and tints it
## (and its ears) to the skin color. The others' colors are the menu swatches:
## natural tones first, then the fun ones.
const BODY := "body/body_10"
const EARS := "ears/ears_10"
const SKINS := [9, 10, 11, 12, 13, 14, 15, 16, 1, 2, 3, 4, 5, 6, 7, 8]
## Expressions; "lashes" picks the pack's set of faces with eyelashes.
const FACES := [
	["Smile", "usual_02"], ["Grin", "usual_01"], ["Laughing", "happy_01"], ["Cheerful", "happy_02"],
	["Calm", "neutral_01"], ["Curious", "neutral_02"], ["Heart eyes", "love_01"], ["Silly", "tongue_01"],
	["Wow", "surpriced_01"], ["Oh!", "surpriced_02"], ["Hmm", "confuse_01"], ["Smirk", "evil_01"],
	["Dreamy", "sad_02"], ["Grumpy", "angry_01"],
]
const HAIR := [
	["Flip", "female_01"], ["Two-tone", "female_02"], ["Bob", "female_03"], ["Long", "female_04"],
	["Straight", "female_05"], ["Waves", "female_06"], ["Shoulder length", "female_07"],
	["Curly top", "female_08"], ["Top bun", "female_09"], ["Big curls", "female_10"], ["Fluffy", "female_11"],
	["Space buns", "female_12"], ["Swoop", "male_01"], ["Bowl cut", "male_02"], ["Mop", "male_03"],
	["Tousled", "male_04"], ["Side part", "male_05"], ["Rainbow afro", "male_06"], ["Fancy wig", "male_07"],
	["Quiff", "male_08"], ["Short", "male_09"], ["Pompadour", "male_10"], ["Sprout", "male_11"],
	["Spiky", "male_12"], ["Crew cut", "male_13"], ["Neat", "male_14"], ["Buzz", "male_15"],
	["Slick", "male_16"], ["Flat top", "male_17"], ["Cropped", "male_18"],
]
const FACE_EXTRAS := [
	["Clown nose", "clown_nose_01"], ["Earrings", "earrings_01"], ["Headphones", "headphones_02"],
	["Face mask", "mask_01"], ["Ninja mask", "mask_02"], ["Pacifier", "pacifier_001"],
	["Beard 1", "beard_01"], ["Beard 2", "beard_02"], ["Beard 3", "beard_03"],
]
## Dress-up sets: [name, set number, pieces, whether its headpiece hides hair].
## A costume replaces every clothing slot and the hat.
const COSTUMES := [
	["Bunny", 1, 3, true], ["Bee", 2, 4, true], ["Astronaut", 3, 5, true], ["Robot", 4, 4, true],
	["Superhero", 5, 4, true], ["Penguin", 6, 2, true], ["Diver", 7, 3, true], ["Jester", 8, 2, false],
	["Knight", 9, 5, true], ["Santa", 10, 5, false], ["Explorer", 11, 6, true], ["Dino", 12, 3, true],
	["Fish", 13, 2, true], ["Pirate", 14, 3, false],
]
## Hats left out: 31 is a toy box with a brand-style label.
const SKIPPED_HATS := [31]

## Keys whose color can be "" to keep the part's own colors.
const TINTS := {"hair_color": "hair", "top_color": "top", "bottom_color": "bottom",
	"shoe_color": "shoes", "hat_color": "hat"}

static var _lists := {}
static var _tint_shader: Shader


## Every option list by config key: entries are [label, part path], with "" for none.
static func lists() -> Dictionary:
	if not _lists.is_empty():
		return _lists
	var faces := []
	for face in FACES:
		faces.append([face[0], face[1]])
	var hair := [["None", ""]]
	for h in HAIR:
		hair.append([h[0], "hairstyle/hairstyle_" + h[1]])
	var glasses := _numbered("Glasses", "glasses/glasses_%02d", 21)
	glasses.append(["Eye patch", "glasses/bandage_01"])
	var extras := [["None", ""]]
	for e in FACE_EXTRAS:
		extras.append([e[0], "face_accessories/" + e[1]])
	for i in range(1, 16):
		extras.append(["Mustache %d" % i, "face_accessories/mustache_%02d" % i])
	var bottoms := _numbered("Pants", "pants/pants_%02d", 15)
	bottoms.append_array(_numbered("Shorts", "shorts/shorts_%02d", 3).slice(1))
	var shoes := _numbered("Sandals", "shoes/shoe_slippers_%02d", 7)
	shoes.append_array(_numbered("Sneakers", "shoes/shoe_sneakers_%02d", 15).slice(1))
	var hats := [["None", ""]]
	for i in range(1, 60):
		if i not in SKIPPED_HATS:
			hats.append(["Hat %d" % (hats.size()), "hat/hat_%02d" % i])
	var costumes := [["None", ""]]
	for c in COSTUMES:
		costumes.append([c[0], ""])
	_lists = {
		"face": faces,
		"lashes": [["No", ""], ["Yes", ""]],
		"ears": [["Hidden", ""], ["Shown", ""]],
		"glasses": glasses,
		"face_extra": extras,
		"hair": hair,
		"top": _numbered("Top", "outwear/outwear_%02d", 56),
		"bottom": bottoms,
		"outfit": _numbered("Outfit", "outfit/outfit_%02d", 9),
		"shoes": shoes,
		"socks": _numbered("Socks", "socks/socks_%02d", 3),
		"gloves": _numbered("Gloves", "gloves/gloves_%02d", 12),
		"hat": hats,
		"costume": costumes,
	}
	return _lists


static func _numbered(label: String, pattern: String, count: int) -> Array:
	var out := [["None", ""]]
	for i in range(1, count + 1):
		out.append(["%s %d" % [label, i], pattern % i])
	return out


static func labels(key: String) -> Array:
	return lists().get(key, []).map(func(entry): return entry[0])


## The skin swatches, one per body model, as hex colors.
static func skin_colors() -> Array:
	return SKINS.map(func(n): return PartColors.MAIN["body/body_%02d" % n])


static func default_config() -> Dictionary:
	return {
		"skin": PartColors.MAIN["body/body_10"], "face": 0, "lashes": 0, "ears": 1,
		"glasses": 0, "face_extra": 0, "hair": 16, "hair_color": "",
		"top": 54, "top_color": "", "bottom": 5, "bottom_color": "", "outfit": 0,
		"shoes": 15, "shoe_color": "", "socks": 0, "gloves": 0,
		"hat": 0, "hat_color": "", "costume": 0,
	}


## Fills the art-only choices of a random config. Most extras stay off so
## random characters look like kids rather than costume parties.
static func randomize_config(c: Dictionary, rng: RandomNumberGenerator, colors: Array) -> void:
	var skins := skin_colors()
	# Natural skin tones most of the time.
	c["skin"] = skins[rng.randi_range(0, 4) if rng.randf() < 0.75 else rng.randi_range(0, skins.size() - 1)]
	for key in ["face", "lashes", "ears"]:
		c[key] = rng.randi_range(0, labels(key).size() - 1)
	for key in ["hair", "top", "bottom", "shoes"]:
		c[key] = rng.randi_range(1, labels(key).size() - 1)
	for chance in [["glasses", 0.25], ["face_extra", 0.06], ["outfit", 0.15], ["socks", 0.2],
			["gloves", 0.1], ["hat", 0.4], ["costume", 0.08]]:
		c[chance[0]] = rng.randi_range(1, labels(chance[0]).size() - 1) if rng.randf() < chance[1] else 0
	for key in TINTS:
		c[key] = "" if rng.randf() < 0.6 else colors[rng.randi_range(0, colors.size() - 1)]


static func art_paths() -> Array:
	var out := [SKELETON]
	for key in lists():
		for entry in lists()[key]:
			if entry[1] != "" and key != "face":
				out.append(PARTS + entry[1])
	for face in FACES:
		for set_name in ["female", "male"]:
			out.append(PARTS + "faces/%s/%s_emotion_%s" % [set_name, set_name, face[1]])
	out.append(PARTS + BODY)
	out.append(PARTS + EARS)
	for c in COSTUMES:
		for piece in range(1, c[2] + 1):
			out.append(PARTS + "costumes/costume_%d_%02d" % [c[1], piece])
	return out


## The dressed character, or null when the art isn't installed. Expects a
## sanitized config. Its origin is between the feet and it faces +Z. The
## pack's character is its "Model" child, scaled to the player's height, and
## its "thumb_boxes" meta frames pictures of it.
static func build(config: Dictionary) -> Node3D:
	var model := Art.instance(SKELETON)
	if model == null:
		return null
	model.name = "Model"
	var size := SCALE * float(config["height"])
	model.scale = Vector3.ONE * size
	var root := Node3D.new()
	root.name = "Avatar"
	root.add_child(model)
	var skeleton := model.get_node("Skeleton/Skeleton3D") as Skeleton3D
	_add(skeleton, BODY, config["skin"])
	if int(config["ears"]) == 1:
		_add(skeleton, EARS, config["skin"])
	var face_set := "female" if int(config["lashes"]) == 1 else "male"
	_add(skeleton, "faces/%s/%s_emotion_%s" % [face_set, face_set, FACES[int(config["face"])][1]])
	_add_choice(skeleton, config, "glasses")
	_add_choice(skeleton, config, "face_extra")
	var costume := int(config["costume"])
	if costume > 0:
		var c: Array = COSTUMES[costume - 1]
		if not c[3]:
			_add_choice(skeleton, config, "hair")
		for piece in range(1, c[2] + 1):
			_add(skeleton, "costumes/costume_%d_%02d" % [c[1], piece])
	else:
		_add_choice(skeleton, config, "hair")
		if int(config["outfit"]) > 0:
			_add_choice(skeleton, config, "outfit")
		else:
			_add_choice(skeleton, config, "top")
			_add_choice(skeleton, config, "bottom")
		for key in ["socks", "shoes", "gloves", "hat"]:
			_add_choice(skeleton, config, key)
	var head := HEAD_BOX
	for mesh: MeshInstance3D in skeleton.get_children():
		if mesh.get_aabb().position.y > NECK_Y:
			head = head.merge(mesh.get_aabb())
	var boxes := {"face": HEAD_BOX, "head": head}
	boxes.merge(VIEW_BOXES)
	for view in boxes:
		boxes[view] = Transform3D.IDENTITY.scaled(Vector3.ONE * size) * boxes[view]
	root.set_meta("thumb_boxes", boxes)
	play(root, "Idle")
	_pose(skeleton, (model.get_node("AnimationPlayer") as AnimationPlayer).get_animation(CLIPS["Idle"]))
	return root


static func _add_choice(skeleton: Skeleton3D, config: Dictionary, key: String) -> void:
	var path: String = lists()[key][int(config[key])][1]
	if path == "":
		return
	var tint := ""
	for color_key in TINTS:
		if TINTS[color_key] == key:
			tint = config[color_key]
	_add(skeleton, path, tint)


static func _add(skeleton: Skeleton3D, path: String, tint := "") -> void:
	var part := Art.instance(PARTS + path)
	if part == null:
		return
	for source: MeshInstance3D in part.find_children("*", "MeshInstance3D", true, false):
		var mesh := source.duplicate() as MeshInstance3D
		skeleton.add_child(mesh, true)
		mesh.skeleton = NodePath("..")
		if tint != "":
			_tint(mesh, path, tint)
	part.free()


## Swaps the part's main color for `hex` with tint.gdshader.
static func _tint(mesh: MeshInstance3D, path: String, hex: String) -> void:
	if not PartColors.MAIN.has(path):
		return
	if _tint_shader == null:
		_tint_shader = load("res://scripts/avatar/tint.gdshader")
	for s in mesh.mesh.get_surface_count():
		var mat := mesh.get_active_material(s) as BaseMaterial3D
		if mat == null or mat.resource_name != "Color":
			continue
		var tinted := ShaderMaterial.new()
		tinted.shader = _tint_shader
		tinted.set_shader_parameter("palette", mat.albedo_texture)
		tinted.set_shader_parameter("main_color", Color.html(PartColors.MAIN[path]))
		tinted.set_shader_parameter("tint_color", MeshUtil.hex(hex))
		mesh.set_surface_override_material(s, tinted)


## Puts the skeleton in the first frame of `clip` right away. The animation
## player only poses it once it runs in the tree, and until then it would be
## drawn in the pack's T-pose (pictures of it are taken before that).
static func _pose(skeleton: Skeleton3D, clip: Animation) -> void:
	if clip == null:
		return
	for t in clip.get_track_count():
		var bone := skeleton.find_bone(clip.track_get_path(t).get_concatenated_subnames())
		if bone < 0:
			continue
		match clip.track_get_type(t):
			Animation.TYPE_POSITION_3D:
				skeleton.set_bone_pose_position(bone, clip.position_track_interpolate(t, 0.0))
			Animation.TYPE_ROTATION_3D:
				skeleton.set_bone_pose_rotation(bone, clip.rotation_track_interpolate(t, 0.0))
			Animation.TYPE_SCALE_3D:
				skeleton.set_bone_pose_scale(bone, clip.scale_track_interpolate(t, 0.0))


## Plays "Idle", "Walk", "Run" or "Fall" on a built character, looping.
## Returns false for anything without the pack's animations.
static func play(avatar: Node3D, state: String, speed := 1.0) -> bool:
	var player := avatar.get_node_or_null("Model/AnimationPlayer") as AnimationPlayer
	if player == null or not CLIPS.has(state) or not player.has_animation(CLIPS[state]):
		return false
	var clip: String = CLIPS[state]
	if player.current_animation != clip:
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		player.play(clip, 0.2)
	player.speed_scale = speed
	return true
