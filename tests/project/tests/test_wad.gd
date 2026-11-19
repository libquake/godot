extends QuakeTest

## libquake's test wad, next to this repository like for the build.
const WAD := "../../../libquake/tests/data/prototype.wad"
const TARGET := "user://wad_test"


func test_wad_becomes_image_files() -> void:
	var wad_path := ProjectSettings.globalize_path("res://").path_join(WAD).simplify_path()
	if not FileAccess.file_exists(wad_path):
		failures.append("missing %s" % wad_path)
		return
	var wad := QuakeWad.new()
	check_equal(wad.load(wad_path), OK, "loads")
	var names := wad.get_texture_names()
	check(not names.is_empty(), "lists its textures")
	var count := QuakeWadExtractor.extract(wad_path, TARGET)
	check_equal(count, names.size(), "one image per texture")
	var first := TARGET.path_join("prototype").path_join(names[0].to_lower().replace("*", "#") + ".png")
	check(FileAccess.file_exists(first), "written as <wad>/<name>.png")
	check(QuakeTextureFiles.new(PackedStringArray([TARGET])).has(names[0]), "found by the import like any image")
	_remove(ProjectSettings.globalize_path(TARGET))


func test_wad_imports_as_its_textures() -> void:
	var wad_path := ProjectSettings.globalize_path("res://").path_join(WAD).simplify_path()
	var importer: GDScript = load("res://addons/libquake/quake_wad_importer.gd")
	var textures: QuakeWadTextures = importer.read(wad_path)
	check(textures != null, "read")
	if not textures:
		return
	var wad := QuakeWad.new()
	wad.load(wad_path)
	check_equal(textures.names, wad.get_texture_names(), "every texture, by its name")
	check_equal(textures.previews.size(), textures.size(), "a preview each")
	var first := wad.get_texture_image(textures.names[0])
	check_equal(Vector2i(textures.sizes[0]), first.get_size(), "the full size")
	var preview := textures.previews[0].get_image()
	check(preview.get_width() <= 128 and preview.get_height() <= 128, "previews 128 pixels at most")
	if first.get_size() == preview.get_size():
		check_equal(preview.get_pixel(3, 5), first.get_pixel(3, 5), "lossless")


static func _remove(directory: String) -> void:
	for subdirectory in DirAccess.get_directories_at(directory):
		_remove(directory.path_join(subdirectory))
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
