@tool
class_name QuakeMapLoader
extends RefCounted
## Loads a map with the options of an import, shared by the level and the pieces importer.

var level := QuakeLevel.new()
var texture_files: QuakeTextureFiles
var error := OK


func _init(source_file: String, options: Dictionary, merge_groups := false) -> void:
	texture_files = QuakeTextureFiles.new(options.get("textures/texture_directories", PackedStringArray()))
	level.units_per_meter = options.get("geometry/units_per_meter", 32.0)
	level.csg = options.get("geometry/csg", true)
	level.pivot = options.get("geometry/pivot", QuakeLevel.PIVOT_BOTTOM_CENTER)
	level.merge_groups = merge_groups
	level.bake = options.get("lighting/bake", false)
	level.luxel_size = options.get("lighting/luxel_size", 16.0)
	level.sky_surfaces = options.get("surfaces/draw_sky", true)
	level.wad_directories = _globalize(options.get("textures/wad_directories", PackedStringArray()))
	level.texture_size_provider = texture_files.size
	level.missing_texture_size = Vector2i(QuakeMaterials.missing_texture().get_size())
	error = level.load(ProjectSettings.globalize_path(source_file))


func worldspawn() -> Dictionary:
	for entity in level.get_entities():
		if entity.classname == "worldspawn":
			return entity
	return {}


## The worldspawn key _meshlib (qu_meshlib in older maps) marks a map of pieces, any value but "0".
func is_pieces() -> bool:
	var properties: Dictionary = worldspawn().get("properties", {})
	for key in ["_meshlib", "qu_meshlib"]:
		if properties.has(key) and properties[key] != "0":
			return true
	return false


## How much each liquid kind covers: the worldspawn keys win over the import options.
func liquid_alphas(options: Dictionary) -> Dictionary:
	var properties: Dictionary = worldspawn().get("properties", {})
	var alphas := {}
	for kind in QuakeLiquids.ALPHA_KEYS:
		var key: String = QuakeLiquids.ALPHA_KEYS[kind]
		alphas[kind] = float(properties[key]) if properties.has(key) else options.get("surfaces/%s_alpha" % kind, 1.0)
	return alphas


static func _globalize(paths: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	for path in paths:
		result.append(ProjectSettings.globalize_path(path))
	return result
