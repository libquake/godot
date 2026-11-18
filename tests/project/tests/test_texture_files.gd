extends QuakeTest


func test_names_follow_trenchbroom() -> void:
	var files := QuakeTextureFiles.new(PackedStringArray(["res://textures"]))
	check(files.has("test/crate"), "by path")
	check(files.has("crate"), "by name alone")
	check(files.has("*water"), "# in file names stands for *")
	check(not files.has("crate_luma"), "companions are no textures of their own")
	check_equal(files.size("crate"), Vector2i(32, 32), "size")
	check(files.emission("crate") != null, "_luma holds the glowing pixels")
	check(not files.has("missing"), "unknown texture")
