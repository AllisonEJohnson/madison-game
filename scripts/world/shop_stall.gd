class_name ShopStall
extends Node3D
## A market stall with a "Shop" sign. Standing at its counter offers the shop
## (see InteractZone). The model comes from the Fantasy pack; without it, a
## stall made of shapes stands in. It faces +Z, where the counter is.

const MODEL := "Fantasy/prefabs/assets/prop/stall_004"
const HEIGHT := 3.2

var zone: InteractZone


static func art_paths() -> Array:
	return [MODEL]


func _init() -> void:
	name = "ShopStall"


func _ready() -> void:
	var depth := 2.0
	var top := HEIGHT
	var model := Art.instance(MODEL)
	if model:
		var box := Art.bounds(model)
		var s := HEIGHT / maxf(box.size.y, 0.01)
		model.scale = Vector3.ONE * s
		model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * s
		add_child(model)
		depth = box.size.z * s
		MeshUtil.collider(self, box.size * s * Vector3(0.85, 1, 0.7), Vector3(0, box.size.y * s / 2, 0))
	else:
		_shape_stall()
	var sign := Label3D.new()
	sign.text = "Shop"
	sign.font = UiTheme.font(700, true)
	sign.font_size = 72
	sign.pixel_size = 0.009
	sign.outline_size = 18
	sign.outline_modulate = Color(0.16, 0.1, 0.3)
	sign.modulate = Color("fff3b0")
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position.y = top + 0.9
	add_child(sign)
	var bags := Sprite3D.new()
	bags.texture = UiTheme.icon("shopping_bags")
	bags.pixel_size = 0.006
	bags.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bags.shaded = false
	bags.position.y = top + 1.75
	add_child(bags)
	zone = InteractZone.new().setup("Shop", "Furniture and clothes", "shopping_bags", "Shop", 2.4)
	zone.position = Vector3(0, 0, depth / 2.0 + 1.2)
	add_child(zone)


## A counter under a striped awning on four posts.
func _shape_stall() -> void:
	var wood := Color("a8744a")
	MeshUtil.box(self, Vector3(2.6, 1.0, 1.0), wood, Vector3(0, 0.5, 0.2))
	MeshUtil.box(self, Vector3(2.8, 0.08, 1.2), wood.lightened(0.2), Vector3(0, 1.04, 0.2))
	for x in [-1.3, 1.3]:
		for z in [-0.6, 0.7]:
			MeshUtil.box(self, Vector3(0.12, 2.8, 0.12), wood.darkened(0.2), Vector3(x, 1.4, z))
	for i in 6:
		var color := Color("ff6fa8") if i % 2 == 0 else Color("fffaf2")
		MeshUtil.box(self, Vector3(0.5, 0.1, 1.7), color, Vector3(-1.25 + i * 0.5, 2.85, 0.1), Vector3(14, 0, 0))
	MeshUtil.collider(self, Vector3(2.6, 1.2, 1.4), Vector3(0, 0.6, 0.1))
