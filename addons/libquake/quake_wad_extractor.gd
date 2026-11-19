@tool
class_name QuakeWadExtractor
extends RefCounted
## Writes a wad's textures as <directory>/<wad>/<name>.png, "#" for "*", with _luma and _front images.


## Into the first texture directory.
static func extract_to_project(wad_path: String) -> void:
	var directories: PackedStringArray = QuakeImportSettings.project_default("textures/texture_directories")
	var directory := directories[0] if not directories.is_empty() else "res://textures"
	var count := extract(wad_path, directory)
	if count < 0:
		push_error("libquake: could not read %s" % wad_path)
		return
	print("libquake: %d textures of %s written to %s" % [count, wad_path.get_file(), directory])
	EditorInterface.get_resource_filesystem().scan()


## The number of textures written, -1 if the wad does not load.
static func extract(wad_path: String, directory: String) -> int:
	var wad := QuakeWad.new()
	if wad.load(ProjectSettings.globalize_path(wad_path)) != OK:
		return -1
	var target := directory.path_join(wad_path.get_file().get_basename().to_lower())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target))
	var count := 0
	for texture_name in wad.get_texture_names():
		var image := wad.get_texture_image(texture_name)
		if not image:
			continue
		var file := target.path_join(texture_name.to_lower().replace("*", "#"))
		image.save_png(file + ".png")
		var emission := wad.get_texture_emission(texture_name)
		if emission:
			emission.save_png(file + "_luma.png")
		var front := wad.get_sky_front_image(texture_name)
		if front:
			front.save_png(file + "_front.png")
		count += 1
	return count
