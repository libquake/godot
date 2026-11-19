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


## A wad anywhere in the project is found: by the file name in the key wad, whatever path and case the mapper's
## machine had, and without the key by the texture's name.
func test_maps_find_the_project_wads() -> void:
	var wad_path := ProjectSettings.globalize_path("res://").path_join(WAD).simplify_path()
	var folder := "res://wad_lookup_test/textures"
	DirAccess.make_dir_recursive_absolute(folder)
	DirAccess.copy_absolute(wad_path, ProjectSettings.globalize_path(folder.path_join("Prototype.WAD")))
	var wad := QuakeWad.new()
	wad.load(wad_path)
	var texture: String = wad.get_texture_names()[0]
	for key in ['"wad" "C:\\QuakeDev\\wads\\prototype.wad"\n', ""]:
		var map := "res://wad_lookup_test/box.map"
		var file := FileAccess.open(map, FileAccess.WRITE)
		file.store_string('{\n"classname" "worldspawn"\n%s{\n' % key
				+ "( 0 0 0 ) ( 0 1 0 ) ( 0 0 1 ) %s 0 0 0 1 1\n" % texture
				+ "( 0 0 0 ) ( 0 0 1 ) ( 1 0 0 ) %s 0 0 0 1 1\n" % texture
				+ "( 0 0 0 ) ( 1 0 0 ) ( 0 1 0 ) %s 0 0 0 1 1\n" % texture
				+ "( 64 64 64 ) ( 64 65 64 ) ( 65 64 64 ) %s 0 0 0 1 1\n" % texture
				+ "( 64 64 64 ) ( 65 64 64 ) ( 64 64 65 ) %s 0 0 0 1 1\n" % texture
				+ "( 64 64 64 ) ( 64 64 65 ) ( 64 65 64 ) %s 0 0 0 1 1\n}\n}\n" % texture)
		file.close()
		var loader := QuakeMapLoader.new(map, {})
		check_equal(loader.error, OK, "loads")
		check(loader.level.get_texture_image(texture) != null,
				"%s found %s" % [texture, "by the key" if key else "by its name"])
	_remove(ProjectSettings.globalize_path("res://wad_lookup_test"))


static func _remove(directory: String) -> void:
	for subdirectory in DirAccess.get_directories_at(directory):
		_remove(directory.path_join(subdirectory))
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
