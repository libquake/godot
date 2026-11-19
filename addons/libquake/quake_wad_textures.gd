@tool
class_name QuakeWadTextures
extends Resource
## What a .wad imports as: the names and pictures of its textures, to see them in the editor. Maps do not use
## it, they read the wad itself.

## As in the wad, which is how maps name them.
@export var names: PackedStringArray
## The full size of each texture in pixels.
@export var sizes: PackedVector2Array
## Each texture, scaled down to 128 pixels at most.
@export var previews: Array[Texture2D]


func size() -> int:
	return names.size()
