@tool
class_name QuakePieces
extends Resource
## What a map of pieces imports as: one piece per TrenchBroom group, each saved as a file of its own to place in
## levels. This resource lists them, in the map's order.

## Named like their group, or the entity's classname outside groups.
@export var names: PackedStringArray
## The piece's scene or mesh, see the import option pieces/save_as.
@export var files: PackedStringArray
## A rendered picture of each piece, null when imported without a renderer.
@export var previews: Array[Texture2D]


func size() -> int:
	return names.size()


## The index of the piece with this name, or -1.
func find(piece_name: String) -> int:
	return names.find(piece_name)
