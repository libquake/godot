@tool
class_name QuakePieces
extends Resource
## What a map of pieces imports as: its pieces in map order, each saved as a file of its own.

@export var names: PackedStringArray
## Scenes or meshes, see pieces/save_as.
@export var files: PackedStringArray
## Null when imported without a renderer.
@export var previews: Array[Texture2D]


func size() -> int:
	return names.size()


func find(piece_name: String) -> int:
	return names.find(piece_name)
