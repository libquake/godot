@tool
class_name QuakeSkybox
extends RefCounted
## A skybox as Quakespasm and the ericw tools read it: the worldspawn key "sky" names six images,
## <sky>rt, bk, lf, ft, up and dn, e.g. "sky" "armagedon_" for armagedon_rt.tga ... The Quake mods keep them in
## gfx/env, a Godot project in textures/sky_directories.

const SUFFIXES := ["rt", "bk", "lf", "ft", "up", "dn"]


## Suffix -> Texture2D of the level's sky, empty without a "sky" key or when an image is missing.
static func of_level(level: QuakeLevel, directories: PackedStringArray) -> Dictionary:
	for entity: Dictionary in level.get_entities():
		if entity.classname == "worldspawn":
			return find(entity.properties.get("sky", ""), directories)
	return {}


## Suffix -> Texture2D, empty unless all six are there.
static func find(sky_name: String, directories: PackedStringArray) -> Dictionary:
	if sky_name.strip_edges().is_empty():
		return {}
	var faces := {}
	for suffix: String in SUFFIXES:
		var texture := _face(sky_name.strip_edges() + suffix, directories)
		if not texture:
			return {}
		faces[suffix] = texture
	return faces


static func _face(file_name: String, directories: PackedStringArray) -> Texture2D:
	for directory in directories:
		for extension: String in QuakeTextureFiles.EXTENSIONS:
			for name in [file_name, file_name.to_lower()]:
				var path := directory.path_join("%s.%s" % [name, extension])
				if FileAccess.file_exists(path):
					return QuakeTextureFiles._load(path)
	return null
