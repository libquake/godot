@tool
extends EditorImportPlugin
## Imports a .wad as QuakeWadTextures, so the FileSystem dock shows it and the Quake panel its textures.

## Larger textures are scaled down for the preview, Quake's are 128 pixels or less mostly.
const PREVIEW_SIZE := 128


func _get_importer_name() -> String:
	return "libquake.wad"


func _get_visible_name() -> String:
	return "Quake WAD"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["wad"])


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	return "Resource"


func _get_priority() -> float:
	return 1.0


func _get_import_order() -> int:
	return IMPORT_ORDER_DEFAULT


func _get_preset_count() -> int:
	return 1


func _get_preset_name(_preset_index: int) -> String:
	return "Default"


func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return []


func _get_option_visibility(_path: String, _option_name: StringName, _options: Dictionary) -> bool:
	return true


func _import(source_file: String, save_path: String, _options: Dictionary,
		_platform_variants: Array[String], _gen_files: Array[String]) -> Error:
	var textures := read(source_file)
	if not textures:
		return ERR_FILE_CORRUPT
	return ResourceSaver.save(textures, "%s.%s" % [save_path, _get_save_extension()])


## The textures of the wad at path, null if it does not load.
static func read(path: String) -> QuakeWadTextures:
	var wad := QuakeWad.new()
	if wad.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	var textures := QuakeWadTextures.new()
	for texture_name in wad.get_texture_names():
		var image := wad.get_texture_image(texture_name)
		if not image:
			continue
		textures.names.append(texture_name)
		textures.sizes.append(image.get_size())
		textures.previews.append(_preview(image))
	return textures


## Pixels stay sharp, and lossless WebP keeps the file small.
static func _preview(image: Image) -> Texture2D:
	var largest := maxi(image.get_width(), image.get_height())
	if largest > PREVIEW_SIZE:
		var scale := float(PREVIEW_SIZE) / largest
		image.resize(maxi(roundi(image.get_width() * scale), 1), maxi(roundi(image.get_height() * scale), 1),
				Image.INTERPOLATE_NEAREST)
	var texture := PortableCompressedTexture2D.new()
	texture.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	return texture
