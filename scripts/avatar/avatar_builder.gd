class_name AvatarBuilder
extends RefCounted
## Builds a stylable avatar from a plain Dictionary config.
## The config only holds option indices and hex colors, so it is easy to
## save as JSON and cheap to send over the network.

const SKIN_TONES := ["ffe0cc", "f6cba9", "e0ac80", "c68a5e", "a0683f", "7a4a2a", "553220"]
const HAIR_COLORS := ["1f1a17", "4a2f20", "8a5a33", "d9b26a", "f2e3b3", "c2452d", "e26fb0", "5a8de0", "7fd18a", "ffffff"]
const EYE_COLORS := ["3b2a20", "4f7fd6", "3e9a5b", "8a6a3a", "7a4fc2", "2a2a2a"]

const OPTIONS := {
	"build": ["Slim", "Regular", "Broad"],
	"eyes": ["Round", "Happy", "Sleepy", "Sparkle", "Wink", "Dots"],
	"brows": ["None", "Soft", "Bold", "Raised", "Worried"],
	"nose": ["None", "Dot", "Button", "Pointy"],
	"mouth": ["Smile", "Big Grin", "Open", "Tongue Out", "Neutral", "Smirk"],
	"cheeks": ["None", "Blush", "Freckles", "Blush + Freckles"],
	"glasses": ["None", "Round", "Square", "Shades"],
	"hair": ["Bald", "Short", "Long", "Spiky", "Bun", "Pigtails", "Ponytail", "Curly", "Mohawk", "Bob"],
	"top": ["T-Shirt", "Tank Top", "Hoodie", "Striped Sweater", "Jacket"],
	"bottom": ["Pants", "Shorts", "Skirt", "Long Skirt"],
	"shoes": ["Sneakers", "Boots", "Sandals"],
	"hat": ["None", "Cap", "Top Hat", "Beanie", "Crown", "Bow", "Flower", "Headphones", "Bunny Ears"],
	"back": ["None", "Backpack", "Cape", "Wings"],
}

const HEAD_Y := 1.58
const HEAD_R := 0.2


static func default_config() -> Dictionary:
	return {
		"skin": SKIN_TONES[1], "height": 1.0, "build": 1,
		"eyes": 0, "eye_color": EYE_COLORS[1], "brows": 1, "nose": 1, "mouth": 0, "cheeks": 1,
		"glasses": 0, "glasses_color": "333344",
		"hair": 1, "hair_color": HAIR_COLORS[1],
		"top": 0, "top_color": "3f7fd9", "top_accent": "ffffff",
		"bottom": 0, "bottom_color": "2f3550",
		"shoes": 0, "shoe_color": "e04848",
		"hat": 0, "hat_color": "f2c94c",
		"back": 0, "back_color": "8a5ad6",
	}


static func random_config(rng: RandomNumberGenerator) -> Dictionary:
	var c := default_config()
	for key in OPTIONS:
		c[key] = rng.randi_range(0, OPTIONS[key].size() - 1)
	c["glasses"] = 0 if rng.randf() < 0.7 else c["glasses"]
	c["skin"] = SKIN_TONES[rng.randi_range(0, SKIN_TONES.size() - 1)]
	c["hair_color"] = HAIR_COLORS[rng.randi_range(0, HAIR_COLORS.size() - 1)]
	c["eye_color"] = EYE_COLORS[rng.randi_range(0, EYE_COLORS.size() - 1)]
	for key in ["top_color", "top_accent", "bottom_color", "shoe_color", "hat_color", "back_color"]:
		c[key] = Color.from_hsv(rng.randf(), rng.randf_range(0.35, 0.8), rng.randf_range(0.5, 0.95)).to_html(false)
	c["height"] = snappedf(rng.randf_range(0.9, 1.1), 0.01)
	return c


## Clamps every field to a valid value. Used on configs that arrive over the network.
static func sanitize(config: Variant) -> Dictionary:
	var out := default_config()
	if not config is Dictionary:
		return out
	for key in out:
		if not config.has(key):
			continue
		var value = config[key]
		if OPTIONS.has(key):
			if value is int or value is float:
				out[key] = clampi(int(value), 0, OPTIONS[key].size() - 1)
		elif key == "height":
			if value is int or value is float:
				out[key] = clampf(float(value), 0.85, 1.15)
		elif value is String and Color.html_is_valid(value):
			out[key] = Color.html(value).to_html(false)
	return out


static func opt(config: Dictionary, key: String) -> int:
	return int(config.get(key, 0))


static func col(config: Dictionary, key: String) -> Color:
	return MeshUtil.hex(config.get(key, "ffffff"))


## Returns a Node3D whose origin is between the feet, facing +Z.
## Limb pivots are named ArmL/ArmR/LegL/LegR so callers can animate them.
static func build(config: Dictionary) -> Node3D:
	config = sanitize(config)
	var root := Node3D.new()
	root.name = "Avatar"
	var s := float(config["height"])
	root.scale = Vector3(s, s, s)

	var skin := col(config, "skin")
	var width: float = [0.88, 1.0, 1.15][opt(config, "build")]

	_build_legs(root, config, skin)
	_build_torso(root, config, skin, width)
	_build_arms(root, config, skin, width)
	MeshUtil.cylinder(root, 0.07, 0.075, 0.14, skin, Vector3(0, 1.45, 0))

	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, HEAD_Y, 0)
	root.add_child(head)
	MeshUtil.sphere(head, HEAD_R, skin)
	MeshUtil.sphere(head, 0.045, skin, Vector3(-HEAD_R, -0.01, 0), Vector3(0.5, 1, 1))
	MeshUtil.sphere(head, 0.045, skin, Vector3(HEAD_R, -0.01, 0), Vector3(0.5, 1, 1))
	_build_face(head, config, skin)
	_build_hair(head, config)
	_build_hat(head, config)
	_build_back(root, config)
	return root


# --- Body -----------------------------------------------------------------

static func _build_legs(root: Node3D, config: Dictionary, skin: Color) -> void:
	var bottom := opt(config, "bottom")
	var bottom_color := col(config, "bottom_color")
	var shoe_color := col(config, "shoe_color")
	var shoes := opt(config, "shoes")
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.name = "LegL" if side < 0 else "LegR"
		pivot.position = Vector3(0.1 * side, 0.86, 0)
		root.add_child(pivot)
		var leg_color := bottom_color if bottom == 0 else skin
		MeshUtil.capsule(pivot, 0.075, 0.8, leg_color, Vector3(0, -0.4, 0))
		if bottom == 1:
			MeshUtil.cylinder(pivot, 0.09, 0.085, 0.32, bottom_color, Vector3(0, -0.14, 0))
		match shoes:
			0:
				MeshUtil.box(pivot, Vector3(0.15, 0.09, 0.26), shoe_color, Vector3(0, -0.78, 0.03))
				MeshUtil.box(pivot, Vector3(0.155, 0.03, 0.265), Color.WHITE, Vector3(0, -0.83, 0.03))
			1:
				MeshUtil.cylinder(pivot, 0.085, 0.09, 0.26, shoe_color, Vector3(0, -0.7, 0))
				MeshUtil.box(pivot, Vector3(0.16, 0.08, 0.27), shoe_color.darkened(0.2), Vector3(0, -0.8, 0.04))
			2:
				MeshUtil.box(pivot, Vector3(0.15, 0.025, 0.26), shoe_color, Vector3(0, -0.835, 0.03))
				MeshUtil.box(pivot, Vector3(0.155, 0.02, 0.05), shoe_color, Vector3(0, -0.79, 0.06))
				MeshUtil.sphere(pivot, 0.07, skin, Vector3(0, -0.8, 0.07), Vector3(1, 0.5, 1.4))


static func _build_torso(root: Node3D, config: Dictionary, skin: Color, width: float) -> void:
	var top := opt(config, "top")
	var top_color := col(config, "top_color")
	var accent := col(config, "top_accent")
	var bottom := opt(config, "bottom")
	var bottom_color := col(config, "bottom_color")
	var torso_scale := Vector3(width, 1, 0.78)

	MeshUtil.capsule(root, 0.2, 0.66, top_color, Vector3(0, 1.14, 0), Vector3.ZERO, torso_scale)
	# Hips/waistband in the bottom color so pants and skirts read clearly.
	MeshUtil.cylinder(root, 0.19 * width, 0.2 * width, 0.14, bottom_color, Vector3(0, 0.9, 0),
			Vector3.ZERO, Vector3(1, 1, 0.8))
	match top:
		1: # Tank top: show shoulders
			MeshUtil.sphere(root, 0.09, skin, Vector3(-0.17 * width, 1.37, 0))
			MeshUtil.sphere(root, 0.09, skin, Vector3(0.17 * width, 1.37, 0))
		2: # Hoodie: hood and front pocket
			MeshUtil.torus(root, 0.07, 0.15, top_color, Vector3(0, 1.44, -0.06), Vector3(-15, 0, 0))
			MeshUtil.box(root, Vector3(0.24 * width, 0.12, 0.03), accent, Vector3(0, 1.0, 0.15))
		3: # Striped sweater
			for y in [1.0, 1.14, 1.28]:
				MeshUtil.cylinder(root, 0.205 * width, 0.205 * width, 0.05, accent, Vector3(0, y, 0),
						Vector3.ZERO, Vector3(1, 1, 0.8))
		4: # Jacket: open front shows a shirt underneath, plus a collar
			MeshUtil.box(root, Vector3(0.12, 0.5, 0.03), accent, Vector3(0, 1.15, 0.155))
			MeshUtil.box(root, Vector3(0.3 * width, 0.05, 0.2), top_color.darkened(0.15), Vector3(0, 1.43, 0))
	match bottom:
		2:
			MeshUtil.cylinder(root, 0.2 * width, 0.33, 0.32, bottom_color, Vector3(0, 0.78, 0))
		3:
			MeshUtil.cylinder(root, 0.2 * width, 0.38, 0.55, bottom_color, Vector3(0, 0.66, 0))


static func _build_arms(root: Node3D, config: Dictionary, skin: Color, width: float) -> void:
	var top := opt(config, "top")
	var top_color := col(config, "top_color")
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.name = "ArmL" if side < 0 else "ArmR"
		pivot.position = Vector3(0.27 * width * side, 1.38, 0)
		pivot.rotation_degrees.z = 6 * side
		root.add_child(pivot)
		var long_sleeves := top in [2, 3, 4]
		MeshUtil.capsule(pivot, 0.06, 0.6, top_color if long_sleeves else skin, Vector3(0, -0.28, 0))
		if top == 0:
			MeshUtil.capsule(pivot, 0.072, 0.24, top_color, Vector3(0, -0.08, 0))
		MeshUtil.sphere(pivot, 0.065, skin, Vector3(0, -0.6, 0))


static func _build_back(root: Node3D, config: Dictionary) -> void:
	var color := col(config, "back_color")
	match opt(config, "back"):
		1:
			MeshUtil.box(root, Vector3(0.3, 0.36, 0.14), color, Vector3(0, 1.14, -0.22))
			MeshUtil.box(root, Vector3(0.22, 0.12, 0.05), color.lightened(0.25), Vector3(0, 1.04, -0.3))
		2:
			MeshUtil.box(root, Vector3(0.46, 0.85, 0.03), color, Vector3(0, 1.0, -0.2), Vector3(8, 0, 0))
		3:
			for side in [-1, 1]:
				MeshUtil.box(root, Vector3(0.45, 0.3, 0.02), Color(color, 0.85),
						Vector3(0.24 * side, 1.25, -0.2), Vector3(0, -25 * side, 25 * side))


# --- Face -----------------------------------------------------------------

## Position on the head sphere's surface for a face feature at (x, y).
static func _face(x: float, y: float, lift := 0.012) -> Vector3:
	var z := sqrt(maxf(HEAD_R * HEAD_R - x * x - y * y, 0.0))
	return Vector3(x, y, z + lift)


static func _build_face(head: Node3D, config: Dictionary, skin: Color) -> void:
	var eye_color := col(config, "eye_color")
	var dark := Color("2a1f1a")
	var eyes := opt(config, "eyes")
	for side in [-1, 1]:
		var p := _face(0.07 * side, 0.02)
		var style := eyes
		if eyes == 4: # Wink: left eye open, right eye closed
			style = 0 if side < 0 else 1
		match style:
			0, 3:
				MeshUtil.sphere(head, 0.042, Color.WHITE, p, Vector3(1, 1.1, 0.45))
				var iris := 0.03 if style == 3 else 0.025
				MeshUtil.sphere(head, iris, eye_color, p + Vector3(0, -0.004, 0.012), Vector3(1, 1.1, 0.4))
				MeshUtil.sphere(head, 0.011, dark, p + Vector3(0, -0.004, 0.022), Vector3(1, 1, 0.4))
				MeshUtil.sphere(head, 0.008, Color.WHITE, p + Vector3(0.01, 0.01, 0.026))
				if style == 3:
					MeshUtil.sphere(head, 0.005, Color.WHITE, p + Vector3(-0.012, -0.012, 0.026))
			1: # Happy closed arcs: ^ ^
				MeshUtil.box(head, Vector3(0.035, 0.01, 0.01), dark, p + Vector3(-0.014, 0, 0), Vector3(0, 0, 30))
				MeshUtil.box(head, Vector3(0.035, 0.01, 0.01), dark, p + Vector3(0.014, 0, 0), Vector3(0, 0, -30))
			2: # Sleepy half-closed
				MeshUtil.sphere(head, 0.035, Color.WHITE, p + Vector3(0, -0.008, 0), Vector3(1, 0.5, 0.4))
				MeshUtil.box(head, Vector3(0.075, 0.012, 0.012), skin.darkened(0.3), p + Vector3(0, 0.006, 0.006))
				MeshUtil.sphere(head, 0.016, eye_color, p + Vector3(0, -0.01, 0.012), Vector3(1, 0.6, 0.4))
			5: # Simple dots
				MeshUtil.sphere(head, 0.02, dark, p, Vector3(1, 1.3, 0.5))

	var brow_color := col(config, "hair_color").darkened(0.15)
	for side in [-1, 1]:
		var p := _face(0.07 * side, 0.085, 0.01)
		match opt(config, "brows"):
			1: MeshUtil.box(head, Vector3(0.05, 0.01, 0.01), brow_color, p, Vector3(0, 0, -6 * side))
			2: MeshUtil.box(head, Vector3(0.06, 0.02, 0.012), brow_color, p, Vector3(0, 0, -4 * side))
			3: MeshUtil.box(head, Vector3(0.05, 0.012, 0.01), brow_color, p + Vector3(0, 0.015, 0), Vector3(0, 0, 14 * side))
			4: MeshUtil.box(head, Vector3(0.05, 0.012, 0.01), brow_color, p, Vector3(0, 0, -16 * side))

	match opt(config, "nose"):
		1: MeshUtil.sphere(head, 0.014, skin.darkened(0.12), _face(0, -0.03, 0.004))
		2: MeshUtil.sphere(head, 0.026, skin.darkened(0.06), _face(0, -0.03, 0.0))
		3: MeshUtil.cylinder(head, 0.0, 0.022, 0.05, skin.darkened(0.05), _face(0, -0.025, 0.018), Vector3(80, 0, 0))

	var lip := Color("b8474f")
	match opt(config, "mouth"):
		0: _arc(head, 0.035, 0.012, dark, -0.08, 5)
		1:
			MeshUtil.sphere(head, 0.045, Color.WHITE, _face(0, -0.085, 0.0), Vector3(1, 0.45, 0.35))
			_arc(head, 0.045, 0.016, dark, -0.075, 7)
		2: MeshUtil.sphere(head, 0.028, Color("5a1f25"), _face(0, -0.09, 0.0), Vector3(1, 1.1, 0.35))
		3:
			_arc(head, 0.035, 0.012, dark, -0.08, 5)
			MeshUtil.sphere(head, 0.018, Color("f07a8a"), _face(0, -0.1, 0.008), Vector3(1, 1.2, 0.5))
		4: MeshUtil.box(head, Vector3(0.05, 0.01, 0.01), lip, _face(0, -0.085))
		5: MeshUtil.box(head, Vector3(0.05, 0.01, 0.01), lip, _face(0.012, -0.083), Vector3(0, 0, 14))

	var cheeks := opt(config, "cheeks")
	for side in [-1, 1]:
		if cheeks == 1 or cheeks == 3:
			MeshUtil.sphere(head, 0.03, Color(1.0, 0.55, 0.6, 0.55), _face(0.12 * side, -0.05, 0.0), Vector3(1, 0.7, 0.3))
		if cheeks >= 2:
			for f in [Vector2(0.1, -0.035), Vector2(0.125, -0.025), Vector2(0.112, -0.055)]:
				MeshUtil.sphere(head, 0.006, skin.darkened(0.35), _face(f.x * side, f.y, 0.006))

	var glasses_color := col(config, "glasses_color")
	match opt(config, "glasses"):
		1, 2:
			var segments := 24 if opt(config, "glasses") == 1 else 4
			var spin := 0.0 if segments == 24 else 45.0
			for side in [-1, 1]:
				var frame := MeshUtil.torus(head, 0.034, 0.042, glasses_color, _face(0.07 * side, 0.02, 0.03),
						Vector3(90, 0, 0), segments)
				frame.rotate_object_local(Vector3.UP, deg_to_rad(spin))
			MeshUtil.box(head, Vector3(0.05, 0.008, 0.008), glasses_color, _face(0, 0.025, 0.035))
		3:
			for side in [-1, 1]:
				MeshUtil.box(head, Vector3(0.075, 0.045, 0.01), Color("15151c"), _face(0.07 * side, 0.02, 0.032))
			MeshUtil.box(head, Vector3(0.22, 0.012, 0.01), glasses_color, _face(0, 0.04, 0.035))


## Draws a smile as a row of tiny spheres along a curve.
static func _arc(head: Node3D, half_width: float, depth: float, color: Color, y: float, dots: int) -> void:
	for i in dots:
		var t := lerpf(-1.0, 1.0, float(i) / float(dots - 1))
		var x := t * half_width
		var dy := -depth * (1.0 - t * t)
		MeshUtil.sphere(head, 0.007, color, _face(x, y + dy, 0.004))


# --- Hair & hats ------------------------------------------------------------

static func _build_hair(head: Node3D, config: Dictionary) -> void:
	var c := col(config, "hair_color")
	var style := opt(config, "hair")
	if style == 0:
		return
	var cap_scale := Vector3(1.04, 1.0, 1.04)
	if style != 8:
		MeshUtil.sphere(head, 0.215, c, Vector3(0, 0.045, -0.05), cap_scale)
	match style:
		1: # Short with a side sweep
			MeshUtil.sphere(head, 0.07, c, Vector3(0.07, 0.15, 0.12), Vector3(1.4, 0.5, 0.8))
		2: # Long
			MeshUtil.box(head, Vector3(0.4, 0.45, 0.1), c, Vector3(0, -0.14, -0.13))
			MeshUtil.box(head, Vector3(0.08, 0.32, 0.14), c, Vector3(-0.18, -0.12, -0.02))
			MeshUtil.box(head, Vector3(0.08, 0.32, 0.14), c, Vector3(0.18, -0.12, -0.02))
		3: # Spiky
			for i in 7:
				var a := TAU * float(i) / 7.0
				var dir := Vector3(sin(a) * 0.6, 1.0, cos(a) * 0.6 - 0.3).normalized()
				var spike := MeshUtil.cylinder(head, 0.0, 0.05, 0.14, c, dir * 0.22)
				spike.basis = Basis(Quaternion(Vector3.UP, dir))
		4: # Bun
			MeshUtil.sphere(head, 0.09, c, Vector3(0, 0.24, -0.06))
		5: # Pigtails
			for side in [-1, 1]:
				MeshUtil.sphere(head, 0.07, c, Vector3(0.22 * side, 0.02, -0.06))
				MeshUtil.capsule(head, 0.05, 0.25, c, Vector3(0.26 * side, -0.12, -0.06), Vector3(0, 0, 10 * side))
		6: # Ponytail
			MeshUtil.sphere(head, 0.05, c, Vector3(0, 0.1, -0.22))
			MeshUtil.capsule(head, 0.055, 0.32, c, Vector3(0, -0.06, -0.27), Vector3(-20, 0, 0))
		7: # Curly
			for i in 12:
				var a := TAU * float(i) / 12.0
				MeshUtil.sphere(head, 0.07, c, Vector3(sin(a) * 0.19, 0.1 + 0.05 * cos(a * 2.0), cos(a) * 0.19 - 0.04))
			MeshUtil.sphere(head, 0.09, c, Vector3(0, 0.2, -0.02))
		8: # Mohawk
			for i in 6:
				var z := lerpf(0.14, -0.18, float(i) / 5.0)
				var y := sqrt(maxf(HEAD_R * HEAD_R - z * z, 0.0))
				MeshUtil.box(head, Vector3(0.04, 0.1, 0.07), c, Vector3(0, y + 0.03, z))
		9: # Bob
			MeshUtil.box(head, Vector3(0.44, 0.24, 0.24), c, Vector3(0, -0.04, -0.1))
			MeshUtil.box(head, Vector3(0.07, 0.24, 0.16), c, Vector3(-0.2, -0.04, 0.05))
			MeshUtil.box(head, Vector3(0.07, 0.24, 0.16), c, Vector3(0.2, -0.04, 0.05))
			MeshUtil.sphere(head, 0.12, c, Vector3(0, 0.14, 0.1), Vector3(1.3, 0.45, 0.8))


static func _build_hat(head: Node3D, config: Dictionary) -> void:
	var c := col(config, "hat_color")
	match opt(config, "hat"):
		1: # Cap
			MeshUtil.sphere(head, 0.225, c, Vector3(0, 0.06, -0.01), Vector3(1, 0.75, 1))
			MeshUtil.box(head, Vector3(0.26, 0.02, 0.16), c.darkened(0.15), Vector3(0, 0.1, 0.24), Vector3(8, 0, 0))
		2: # Top hat
			MeshUtil.cylinder(head, 0.3, 0.3, 0.02, c, Vector3(0, 0.17, 0))
			MeshUtil.cylinder(head, 0.17, 0.16, 0.3, c, Vector3(0, 0.33, 0))
			MeshUtil.cylinder(head, 0.162, 0.162, 0.05, Color("c0392b"), Vector3(0, 0.21, 0))
		3: # Beanie
			MeshUtil.sphere(head, 0.228, c, Vector3(0, 0.05, -0.02), Vector3(1, 0.85, 1))
			MeshUtil.cylinder(head, 0.232, 0.232, 0.06, c.darkened(0.15), Vector3(0, 0.05, -0.02))
			MeshUtil.sphere(head, 0.06, Color.WHITE, Vector3(0, 0.25, -0.02))
		4: # Crown
			MeshUtil.cylinder(head, 0.15, 0.15, 0.08, c, Vector3(0, 0.22, 0))
			for i in 5:
				var a := TAU * float(i) / 5.0
				MeshUtil.cylinder(head, 0.0, 0.035, 0.08, c, Vector3(sin(a) * 0.13, 0.3, cos(a) * 0.13))
				MeshUtil.sphere(head, 0.015, Color("e04848"), Vector3(sin(a) * 0.15, 0.22, cos(a) * 0.15))
		5: # Bow
			var p := Vector3(0.12, 0.17, 0.05)
			MeshUtil.sphere(head, 0.06, c, p + Vector3(-0.05, 0, 0), Vector3(1, 0.7, 0.4))
			MeshUtil.sphere(head, 0.06, c, p + Vector3(0.05, 0, 0), Vector3(1, 0.7, 0.4))
			MeshUtil.sphere(head, 0.025, c.darkened(0.2), p)
		6: # Flower
			var center := Vector3(-0.14, 0.15, 0.08)
			for i in 6:
				var a := TAU * float(i) / 6.0
				MeshUtil.sphere(head, 0.025, c, center + Vector3(cos(a), sin(a), 0) * 0.035)
			MeshUtil.sphere(head, 0.022, Color("f7d25a"), center + Vector3(0, 0, 0.01))
		7: # Headphones
			MeshUtil.torus(head, 0.22, 0.25, c, Vector3(0, 0.02, 0), Vector3(0, 0, 90))
			for side in [-1, 1]:
				MeshUtil.cylinder(head, 0.06, 0.06, 0.05, c.darkened(0.2), Vector3(0.215 * side, 0, 0), Vector3(0, 0, 90))
		8: # Bunny ears
			for side in [-1, 1]:
				MeshUtil.capsule(head, 0.04, 0.3, c, Vector3(0.08 * side, 0.32, -0.02), Vector3(0, 0, -10 * side))
				MeshUtil.capsule(head, 0.022, 0.22, Color("f6a5b8"), Vector3(0.08 * side, 0.32, 0.012), Vector3(0, 0, -10 * side))
