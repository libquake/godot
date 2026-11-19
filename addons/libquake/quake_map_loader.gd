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
	level.wad_directories = wad_directories(options.get("textures/wad_directories", PackedStringArray()))
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


## Where a map's wads are looked for, besides its own folder: the folders of all wads in the project, then the
## extra ones, usually outside it. The wads of the key wad are found there by file name, and textures they do
## not have in all of these wads.
static func wad_directories(extra: PackedStringArray) -> PackedStringArray:
	var directories := PackedStringArray()
	_add_wad_folders("res://", directories)
	for path in extra:
		var directory := ProjectSettings.globalize_path(path)
		if not directories.has(directory):
			directories.append(directory)
	return directories


## Like the FileSystem dock: hidden folders and those with a .gdignore are left out.
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
