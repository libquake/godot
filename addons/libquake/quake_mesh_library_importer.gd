@tool
extends EditorImportPlugin
## Imports a .map as a MeshLibrary for GridMaps, chosen with "Import As" in the Import dock.
## Every TrenchBroom group becomes one item named like the group, with its pivot as the item's origin.
## Brush entities outside groups get their own item, loose world brushes the item "worldspawn".
## An item's id comes from its name, so placed GridMaps keep their pieces across reimports and clones.


func _get_importer_name() -> String:
	return "libquake.mesh_library"


func _get_visible_name() -> String:
	return "Quake Mesh Library"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["map"])


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	return "MeshLibrary"


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
	return QuakeImportSettings.mesh_library_options()


func _get_option_visibility(_path: String, _option_name: StringName, _options: Dictionary) -> bool:
	return true


func _import(source_file: String, save_path: String, options: Dictionary,
		_platform_variants: Array[String], _gen_files: Array[String]) -> Error:
	var loader := QuakeMapLoader.new(source_file, options, true)
	if loader.error != OK:
		return loader.error

	var materials := QuakeMaterials.new(loader.level, loader.texture_files, QuakeMaterials.Style.GODOT,
			loader.liquid_alphas(options))
	materials.fullbright_energy = options.get("surfaces/fullbright_energy", 1.0)
	var library := MeshLibrary.new()
	var meshes: Array[Mesh] = []
	var item_ids: Array[int] = []

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

		var item_name := _item_name(entity, index)
		var id := _item_id(item_name, library)
		library.create_item(id)
		library.set_item_name(id, item_name)
		library.set_item_mesh(id, mesh)
		library.set_item_shapes(id, _shapes(loader.level.get_geometry_hulls(entity.geometry)))
		meshes.append(mesh)
		item_ids.append(id)

	var previews := EditorInterface.make_mesh_previews(meshes, 64)
	for index in previews.size():
		if previews[index]:
			library.set_item_preview(item_ids[index], previews[index])

	return ResourceSaver.save(library, "%s.%s" % [save_path, _get_save_extension()])


## Groups are named in TrenchBroom, everything else after its classname.
static func _item_name(entity: Dictionary, index: int) -> String:
	if entity.properties.has("_tb_name"):
		return entity.properties["_tb_name"]
	return entity.classname if entity.classname == "worldspawn" else "%s_%d" % [entity.classname, index]


static func _shapes(hulls: Array[Dictionary]) -> Array:
	var shapes := []
	for hull in hulls:
		if hull.type == QuakeLevel.HULL_LIQUID:
			continue
		var shape := ConvexPolygonShape3D.new()
		shape.points = hull.points
		shapes.append_array([shape, Transform3D.IDENTITY])
	return shapes


## Stable for a name; a rare collision moves on to the next free id. GridMap keeps item ids in 16 bits.
static func _item_id(item_name: String, library: MeshLibrary) -> int:
	var id := item_name.hash() & 0xffff
	while library.get_item_list().has(id):
		id = (id + 1) & 0xffff
	return id
