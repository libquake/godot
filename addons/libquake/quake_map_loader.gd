@tool
class_name QuakeMapLoader
extends RefCounted
## Loads a map with an import's options, for both importers.

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
	level.sky_samples = options.get("lighting/sky_samples", 64)
	level.bounces = options.get("lighting/bounces", -1)
	level.bounce_subdivision = options.get("lighting/bounce_subdivision", 64.0)
	level.bounce_scale = options.get("lighting/bounce_scale", -1.0)
	level.luxel_samples = options.get("lighting/luxel_samples", 1)
	level.dirt = options.get("lighting/dirt", -1)
	level.dirt_scale = options.get("lighting/dirt_scale", -1.0)
	level.dirt_samples = options.get("lighting/dirt_samples", 48)
	level.sky_surfaces = options.get("surfaces/draw_sky", true)
	level.wad_directories = wad_directories(options.get("textures/wad_directories", PackedStringArray()))
	level.texture_size_provider = texture_files.size
	level.texture_color_provider = texture_files.average_color
	level.missing_texture_size = Vector2i(QuakeMaterials.missing_texture().get_size())
	error = level.load(ProjectSettings.globalize_path(source_file))


func worldspawn() -> Dictionary:
	for entity in level.get_entities():
		if entity.classname == "worldspawn":
			return entity
	return {}


## The worldspawn key _meshlib or the older qu_meshlib, any value but "0".
func is_pieces() -> bool:
	var properties: Dictionary = worldspawn().get("properties", {})
	for key in ["_meshlib", "qu_meshlib"]:
		if properties.has(key) and properties[key] != "0":
			return true
	return false


## The worldspawn keys win over the import options.
func liquid_alphas(options: Dictionary) -> Dictionary:
	var properties: Dictionary = worldspawn().get("properties", {})
	var alphas := {}
	for kind in QuakeLiquids.ALPHA_KEYS:
		var key: String = QuakeLiquids.ALPHA_KEYS[kind]
		alphas[kind] = float(properties[key]) if properties.has(key) else options.get("surfaces/%s_alpha" % kind, 1.0)
	return alphas


## Besides the map's folder: every folder of the project with a wad, then extra. The key's wads are matched by
## file name, other textures searched in all wads.
static func wad_directories(extra: PackedStringArray) -> PackedStringArray:
	var directories := PackedStringArray()
	_add_wad_folders("res://", directories)
	for path in extra:
		var directory := ProjectSettings.globalize_path(path)
		if not directories.has(directory):
			directories.append(directory)
	return directories


## Skips hidden folders and those with a .gdignore, like the FileSystem dock.
static func _add_wad_folders(folder: String, directories: PackedStringArray) -> void:
	if FileAccess.file_exists(folder.path_join(".gdignore")):
		return
	for file in DirAccess.get_files_at(folder):
		if file.get_extension().to_lower() == "wad":
			directories.append(ProjectSettings.globalize_path(folder))
			break
	for subfolder in DirAccess.get_directories_at(folder):
		if not subfolder.begins_with("."):
			_add_wad_folders(folder.path_join(subfolder), directories)
