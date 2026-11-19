@tool
class_name QuakeWadTextures
extends Resource
## What a .wad imports as, for the editor. Maps read the wad itself.

@export var names: PackedStringArray
## Full size in pixels.
@export var sizes: PackedVector2Array
## 128 pixels at most.
@export var previews: Array[Texture2D]


func size() -> int:
	return names.size()
