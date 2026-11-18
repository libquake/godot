@tool
extends EditorImportPlugin
## Imports .map and .bsp files as scenes. Saving the map in TrenchBroom reimports it, lights included.
## A map with the worldspawn key _meshlib is switched to the mesh library importer instead.



func _get_importer_name() -> String:
	return "libquake.level"


func _get_visible_name() -> String:
	return "Quake Level"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["map", "bsp"])


func _get_save_extension() -> String:
	return "scn"


func _get_resource_type() -> String:
	return "PackedScene"


func _get_priority() -> float:
	return 2.0


func _get_import_order() -> int:
	return IMPORT_ORDER_SCENE


func _can_import_threaded() -> bool:
	return false


func _get_preset_count() -> int:
	return 1


func _get_preset_name(_preset_index: int) -> String:
	return "Default"


func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return QuakeImportSettings.level_options()


func _get_option_visibility(_path: String, _option_name: StringName, _options: Dictionary) -> bool:
	return true


func _import(source_file: String, save_path: String, options: Dictionary,
		_platform_variants: Array[String], _gen_files: Array[String]) -> Error:
	var loader := QuakeMapLoader.new(source_file, options)
	if loader.error != OK:
		return loader.error
	if loader.is_mesh_library():
		_switch_to_mesh_library(source_file)
		return _save(QuakeMap.new(), save_path)

	var builder := QuakeSceneBuilder.new()
	builder.light_grid_cell_size = options["lighting/light_grid_cell_size"]
	builder.show_hulls = options.get("editor/show_hulls", false)
	var entity_classes_path: String = options["entities/entity_classes"]
	if not entity_classes_path.is_empty():
		builder.entity_classes = load(entity_classes_path)
	var root := builder.build(loader, options, source_file.get_file().get_basename())
	root.import_warnings = builder.report()
	for line in root.import_warnings:
		push_warning("%s: %s" % [source_file, line])
	_announce(source_file, root.import_warnings)
	return _save(root, save_path)


## Maps reimport on every save in TrenchBroom and most keep warnings for good (entities without a class), so
## a toast only comes for what is new since the map's last import in this session.
static var _last_warnings := {}


static func _announce(source_file: String, warnings: PackedStringArray) -> void:
	var added := QuakeSceneBuilder.new_warnings(_last_warnings.get(source_file, PackedStringArray()), warnings)
	_last_warnings[source_file] = warnings
	if added.is_empty():
		return
	var text := added[0] if added.size() == 1 else "%d new import warnings" % added.size()
	# imports may run in a thread, the toaster wants the main one
	_toast.call_deferred("%s: %s. The map's inspector lists them." % [source_file.get_file(), text])


static func _toast(text: String) -> void:
	EditorInterface.get_editor_toaster().push_toast(text, EditorToaster.SEVERITY_WARNING)


func _save(root: Node, save_path: String) -> Error:
	var scene := PackedScene.new()
	var error := scene.pack(root)
	root.free()
	if error != OK:
		return error
	return ResourceSaver.save(scene, "%s.%s" % [save_path, _get_save_extension()])


## What "Import As > Quake Mesh Library" does: change the importer in the .import file and reimport.
## Both wait until the current import is over, the editor writes the .import file itself at its end.
static func _switch_to_mesh_library(source_file: String) -> void:
	var file_system := EditorInterface.get_resource_filesystem()
	file_system.resources_reimported.connect(func(_resources: PackedStringArray) -> void:
		var import_path := source_file + ".import"
		var config := ConfigFile.new()
		if config.load(import_path) != OK:
			return
		config.set_value("remap", "importer", "libquake.mesh_library")
		config.set_value("remap", "type", "MeshLibrary")
		config.save(import_path)
		file_system.reimport_files.call_deferred(PackedStringArray([source_file])),
		CONNECT_ONE_SHOT)
