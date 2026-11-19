extends QuakeTest


func test_groups_become_pieces() -> void:
	var pieces: QuakePieces = load("res://maps/pieces.map")
	var names := Array(pieces.names)
	names.sort()
	check_equal(names, ["crate", "pillar", "worldspawn"], "pieces")
	check_equal(pieces.files[pieces.find("crate")], "res://maps/pieces/crate.scn", "a file per piece, next to the map")
	check_equal(pieces.previews.size(), pieces.size(), "a preview for each, null without a renderer")


func test_pieces_are_scenes() -> void:
	var crate: Node = add_scene("res://maps/pieces/crate.scn")
	check(crate is MeshInstance3D, "a MeshInstance3D at the root")
	var bounds: AABB = crate.mesh.get_aabb()
	check_equal(bounds.position.y, 0.0, "the crate stands on its pivot")
	check(bounds.size.is_equal_approx(Vector3(2, 1, 1)), "both brushes of the group: %s" % bounds.size)
	var body := crate.get_node_or_null("StaticBody3D")
	check(body is StaticBody3D, "a static body")
	check_equal(body.get_child_count() if body else 0, 2, "a collision shape per brush")
	crate.queue_free()


func test_pieces_keep_their_uid() -> void:
	var path := "res://maps/pieces/crate.scn"
	var uid := ResourceLoader.get_resource_uid(path)
	check(uid != ResourceUID.INVALID_ID, "the piece has a uid")
	var importer: GDScript = load("res://addons/libquake/quake_pieces_importer.gd")
	check_equal(importer._save_keeping_uid(load(path), path), OK, "saved again")
	check_equal(ResourceLoader.get_resource_uid(path), uid, "the uid after importing again")


func test_pieces_as_meshes() -> void:
	var importer: GDScript = load("res://addons/libquake/quake_pieces_importer.gd")
	var options: Dictionary = QuakeImportSettings.pieces_options().reduce(func(all: Dictionary, option: Dictionary) -> Dictionary:
		all[option.name] = option.default_value
		return all, {})
	options["pieces/save_as"] = QuakeImportSettings.Pieces.MESHES
	options["pieces/folder"] = "res://maps/pieces_as_meshes"
	var files: Array[String] = []
	var meshes: Array[Mesh] = []
	check_equal(importer.save_pieces("res://maps/pieces.map", options, QuakePieces.new(), meshes, files), OK, "imported")
	check_equal(files.size(), 3, "a file per piece")
	check(load("res://maps/pieces_as_meshes/crate.res") is Mesh, "the bare mesh")
	check_equal(load("res://maps/pieces_as_meshes/crate.res").get_meta(QuakeLightmap.DIRT_META, -1.0), 1.0,
			"the maps' full ambient occlusion, pieces are architecture")
