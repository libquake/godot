@tool
extends EditorImportPlugin
## Imports a map of pieces: each TrenchBroom group, brush entity outside groups and the loose world brushes
## become a file of their own, with the pivot as origin.


func _get_importer_name() -> String:
	return "libquake.pieces"


func _get_visible_name() -> String:
	return "Quake Pieces"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["map"])


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	return "Resource"


func _get_priority() -> float:
	return 1.0


func _get_import_order() -> int:
	return IMPORT_ORDER_SCENE


func _can_import_threaded() -> bool:
	return false


func _get_preset_count() -> int:
	return 1


func _get_preset_name(_preset_index: int) -> String:
	return "Default"


func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return QuakeImportSettings.pieces_options()


func _get_option_visibility(_path: String, _option_name: StringName, _options: Dictionary) -> bool:
	return true


func _import(source_file: String, save_path: String, options: Dictionary,
		_platform_variants: Array[String], gen_files: Array[String]) -> Error:
	var pieces := QuakePieces.new()
	var meshes: Array[Mesh] = []
	var error := save_pieces(source_file, options, pieces, meshes, gen_files)
	if error != OK:
		return error
	pieces.previews.assign(EditorInterface.make_mesh_previews(meshes, 64))
	pieces.previews.resize(pieces.size())
	return ResourceSaver.save(pieces, "%s.%s" % [save_path, _get_save_extension()])


static func save_pieces(source_file: String, options: Dictionary, pieces: QuakePieces, meshes: Array[Mesh],
		gen_files: Array[String]) -> Error:
	var loader := QuakeMapLoader.new(source_file, options, true)
	if loader.error != OK:
		return loader.error

	var materials := QuakeMaterials.new(loader.level, loader.texture_files, QuakeMaterials.Style.GODOT,
			loader.liquid_alphas(options))
	materials.fullbright_energy = options.get("surfaces/fullbright_energy", 1.0)
	var as_scenes: bool = options.get("pieces/save_as", QuakeImportSettings.Pieces.SCENES) == QuakeImportSettings.Pieces.SCENES
	var folder := pieces_folder(source_file, options)
	var error := DirAccess.make_dir_recursive_absolute(folder)
	if error != OK:
		return error

	var entities := loader.level.get_entities()
	for index in entities.size():
		var entity: Dictionary = entities[index]
		if entity.geometry < 0:
			continue
		var mesh := loader.level.get_geometry_mesh(entity.geometry)
		if mesh.get_surface_count() == 0:
			continue
		for surface in mesh.get_surface_count():
			mesh.surface_set_material(surface, materials.get_material(mesh.surface_get_name(surface)))
		# brushes are architecture, a QuakeLightmap bakes them like the maps
		mesh.set_meta(QuakeLightmap.LEVEL_META, true)

		var piece_name := _piece_name(entity, index)
		var path := _piece_path(folder, piece_name, "scn" if as_scenes else "res", pieces.files)
		var piece: Resource = mesh
		if as_scenes:
			piece = _piece_scene(piece_name, mesh, _shapes(loader.level.get_geometry_hulls(entity.geometry)))
		error = _save_keeping_uid(piece, path)
		if error != OK:
			return error
		gen_files.append(path)
		pieces.names.append(piece_name)
		pieces.files.append(path)
		meshes.append(mesh)

	_warn_about_removed(source_file, folder, pieces.files)
	return OK


static func pieces_folder(source_file: String, options: Dictionary) -> String:
	var folder: String = options.get("pieces/folder", "")
	return source_file.get_basename() if folder.is_empty() else folder


static func _piece_name(entity: Dictionary, index: int) -> String:
	if entity.properties.has("_tb_name"):
		return entity.properties["_tb_name"]
	return entity.classname if entity.classname == "worldspawn" else "%s_%d" % [entity.classname, index]


## A second piece of the same name gets a number.
static func _piece_path(folder: String, piece_name: String, extension: String, taken: PackedStringArray) -> String:
	var base := folder.path_join(piece_name.validate_filename())
	var path := "%s.%s" % [base, extension]
	var number := 2
	while taken.has(path):
		path = "%s_%d.%s" % [base, number, extension]
		number += 1
	return path


static func _piece_scene(piece_name: String, mesh: Mesh, shapes: Array[ConvexPolygonShape3D]) -> PackedScene:
	var root := MeshInstance3D.new()
	root.name = piece_name.validate_node_name()
	root.mesh = mesh
	if not shapes.is_empty():
		var body := StaticBody3D.new()
		body.name = "StaticBody3D"
		root.add_child(body)
		body.owner = root
		for shape in shapes:
			var collision := CollisionShape3D.new()
			collision.shape = shape
			body.add_child(collision, true)
			collision.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


static func _shapes(hulls: Array[Dictionary]) -> Array[ConvexPolygonShape3D]:
	var shapes: Array[ConvexPolygonShape3D] = []
	for hull in hulls:
		if hull.type == QuakeLevel.HULL_LIQUID:
			continue
		var shape := ConvexPolygonShape3D.new()
		shape.points = hull.points
		shapes.append(shape)
	return shapes


## Keeps the uid, so placed pieces follow the map. Saving during an import writes none by itself.
static func _save_keeping_uid(piece: Resource, path: String) -> Error:
	var uid := ResourceLoader.get_resource_uid(path) if FileAccess.file_exists(path) else ResourceUID.INVALID_ID
	if uid == ResourceUID.INVALID_ID:
		uid = ResourceUID.create_id()
	var error := ResourceSaver.save(piece, path)
	if error != OK:
		return error
	if ResourceUID.has_id(uid):
		ResourceUID.set_id(uid, path)
	else:
		ResourceUID.add_id(uid, path)
	return ResourceSaver.set_uid(path, uid)


## Kept, scenes may still use them.
static func _warn_about_removed(source_file: String, folder: String, saved: PackedStringArray) -> void:
	for file in DirAccess.get_files_at(folder):
		var path := folder.path_join(file)
		if file.get_extension() in ["scn", "res"] and not saved.has(path):
			push_warning("%s: %s is no longer in the map" % [source_file, path])
