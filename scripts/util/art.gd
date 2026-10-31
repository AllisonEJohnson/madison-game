class_name Art
extends RefCounted
## Licensed 3D models from the private madison-game-art repo, cloned into
## res://itHappy/ (see the README). Copies of the game built without that
## folder still work: every caller falls back to the simple shape models when
## `instance()` returns null.
##
## Paths are relative to ROOT and leave off ".tscn". Code that uses art lists
## its paths in an `art_paths()` function so the web build can drop the rest
## (see scripts/dev/prune_art.gd).

const ROOT := "res://itHappy/"

static var _scenes := {}


static func has(path: String) -> bool:
	return _scene(path) != null


## A new copy of the model, or null when the art isn't installed.
static func instance(path: String) -> Node3D:
	var scene := _scene(path)
	return scene.instantiate() as Node3D if scene else null


static func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		var full := ROOT + path + ".tscn"
		_scenes[path] = load(full) as PackedScene if ResourceLoader.exists(full) else null
	return _scenes[path]


## The model's bounds in its own space, from all of its meshes.
static func bounds(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var xform := Transform3D.IDENTITY
		var n: Node = mesh
		while n != node:
			if n is Node3D:
				xform = (n as Node3D).transform * xform
			n = n.get_parent()
		var box := xform * mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out
