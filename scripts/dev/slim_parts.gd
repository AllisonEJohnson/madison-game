extends SceneTree
## Every Cute Characters part scene carries its own 59-bone skeleton, which the
## game never uses (it moves the meshes onto one shared skeleton). This saves
## each part as just its meshes, which cuts the characters' share of the web
## download by about a third. CI runs it after prune_art.gd and the import that
## follows (the parts' materials need their imported texture):
##   godot --headless -s scripts/dev/slim_parts.gd
## It rewrites the art files, so don't run it on an art folder you want to keep.
## (Godot's vertex compression would save more but breaks these skinned meshes.)


func _init() -> void:
	var slimmed := 0
	var failed := 0
	for path: String in CharacterParts.art_paths():
		if path == CharacterParts.SKELETON:
			continue
		var full := Art.ROOT + path + ".tscn"
		var part := (load(full) as PackedScene).instantiate()
		var root := Node3D.new()
		root.name = part.name
		for source: MeshInstance3D in part.find_children("*", "MeshInstance3D", true, false):
			var mesh := MeshInstance3D.new()
			mesh.name = source.name
			mesh.mesh = source.mesh
			mesh.skin = source.skin
			for s in source.get_surface_override_material_count():
				var material := source.get_surface_override_material(s)
				if material == null:
					push_error("Part lost its material (was the art imported?): " + full)
					failed += 1
				mesh.set_surface_override_material(s, material)
			root.add_child(mesh)
			mesh.owner = root
		var packed := PackedScene.new()
		packed.pack(root)
		ResourceSaver.save(packed, full)
		root.free()
		part.free()
		slimmed += 1
	print("[slim_parts] slimmed %d character parts, %d problems" % [slimmed, failed])
	quit(1 if failed > 0 else 0)
