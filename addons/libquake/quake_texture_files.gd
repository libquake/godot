@tool
class_name QuakeTextureFiles
extends RefCounted
## Image textures as TrenchBroom reads them: textures/base/wall1.png is "base/wall1" and "wall1", "#" stands
## for "*". <name>_luma or _glow holds glowing pixels, <name>_front a sky's clouds.

const EXTENSIONS := ["png", "tga", "jpg", "jpeg", "webp", "bmp"]
const COMPANION_SUFFIXES := ["_luma", "_glow", "_front"]

var _paths := {}


func _init(directories: PackedStringArray) -> void:
	for directory in directories:
		_scan(directory, directory)


func has(texture_name: String) -> bool:
	return _paths.has(_key(texture_name))


func texture(texture_name: String) -> Texture2D:
	var path: String = _paths.get(_key(texture_name), "")
	return _load(path) if path else null


func size(texture_name: String) -> Vector2i:
	var found := texture(texture_name)
	return Vector2i(found.get_size()) if found else Vector2i.ZERO


## Alpha 0 when there is no image of that name.
func average_color(texture_name: String) -> Color:
	var found := texture(texture_name)
	return QuakeMaterials.average_color(found) if found else Color(0, 0, 0, 0)


func emission(texture_name: String) -> Texture2D:
	var luma := _companion(texture_name, "_luma")
	return luma if luma else _companion(texture_name, "_glow")


func sky_front(texture_name: String) -> Texture2D:
	return _companion(texture_name, "_front")


func _companion(texture_name: String, suffix: String) -> Texture2D:
	var path: String = _paths.get(_key(texture_name), "")
	if path.is_empty():
		return null
	var companion := "%s%s.%s" % [path.get_basename(), suffix, path.get_extension()]
	return _load(companion) if FileAccess.file_exists(companion) else null


## Images added with the map are not imported yet, so they are read directly.
static func _load(path: String) -> Texture2D:
	var imported := ResourceLoader.load(path, "Texture2D") if ResourceLoader.exists(path) else null
	if imported:
		return imported
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(image) if image else null


func _scan(root: String, directory: String) -> void:
	if not DirAccess.dir_exists_absolute(directory):
		return
	for file in DirAccess.get_files_at(directory):
		if not EXTENSIONS.has(file.get_extension().to_lower()):
			continue
		var base := file.get_basename()
		if COMPANION_SUFFIXES.any(func(suffix: String) -> bool: return base.to_lower().ends_with(suffix)):
			continue
		var path := directory.path_join(file)
		var relative := path.trim_prefix(root).trim_prefix("/").get_basename()
		_paths[_key(relative)] = path
		if not _paths.has(_key(base)):
			_paths[_key(base)] = path
	for subdirectory in DirAccess.get_directories_at(directory):
		_scan(root, directory.path_join(subdirectory))


static func _key(texture_name: String) -> String:
	return texture_name.to_lower().replace("#", "*")
