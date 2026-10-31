class_name PetBuilder
extends RefCounted
## Builds pet models from a small config: species, colors, and a collar.

const SPECIES := ["Cat", "Dog", "Bunny", "Dragon", "Bird"]
const SOUNDS := {
	"Cat": ["Mew!", "Purr...", "Mrrp?"],
	"Dog": ["Woof!", "Arf arf!", "*wags*"],
	"Bunny": ["*hop hop*", "*nose wiggle*", "Squeak!"],
	"Dragon": ["Rawr!", "*tiny puff of smoke*", "Grr~"],
	"Bird": ["Tweet!", "Chirp chirp!", "*flutter*"],
}


static func default_config() -> Dictionary:
	return {"species": 0, "name": "Biscuit", "color": "e8a35a", "accent": "fff3e0", "collar": "e04848"}


static func sanitize(config: Variant) -> Dictionary:
	var out := default_config()
	if not config is Dictionary:
		return out
	if config.get("species") is int or config.get("species") is float:
		out["species"] = clampi(int(config["species"]), 0, SPECIES.size() - 1)
	for key in ["color", "accent", "collar"]:
		var v = config.get(key)
		if v is String and Color.html_is_valid(v):
			out[key] = Color.html(v).to_html(false)
	out["name"] = SafeNames.clean_pet_name(str(config.get("name", out["name"])))
	return out


static func species_name(config: Dictionary) -> String:
	return SPECIES[int(config.get("species", 0))]


## Returns a Node3D with its origin on the ground, facing +Z.
static func build(config: Dictionary) -> Node3D:
	config = sanitize(config)
	var root := Node3D.new()
	root.name = "PetModel"
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
