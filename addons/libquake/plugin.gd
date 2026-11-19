@tool
extends EditorPlugin

const EXPORT_MENU_ITEM := "Export TrenchBroom Game Config"
const EXTRACT_MENU_ITEM := "Extract WAD Textures..."
const SETUP_MENU_ITEM := "Set up libquake Project"
const BAKE_TEXT := "Bake Quake Light"
const BAKING_TEXT := "Baking..."

var _importers: Array[EditorImportPlugin] = []
var _inspector: EditorInspectorPlugin
var _watcher: QuakeMapWatcher
var _file_menus: Array[EditorContextMenuPlugin] = []
var _gizmo: QuakeMapGizmo
var _fog_gizmo: QuakeGroundFogGizmo
var _bake_button: Button
var _lightmap: QuakeLightmap
var _auto_bake_timer: Timer
var _browser: Control
## The browser itself in Godot 4.5's bottom panel.
var _browser_dock: Control


func _enter_tree() -> void:
	QuakeImportSettings.register()
	QuakeMapWatcher.register_setting()
	preload("quake_file_menu.gd").register_setting()
	# one each: Godot takes a context menu plugin only once
	for slot in [EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM_CREATE]:
		var file_menu: EditorContextMenuPlugin = preload("quake_file_menu.gd").new()
		add_context_menu_plugin(slot, file_menu)
		_file_menus.append(file_menu)
	for importer in [preload("quake_level_importer.gd"), preload("quake_pieces_importer.gd"),
			preload("quake_wad_importer.gd")]:
		var instance: EditorImportPlugin = importer.new()
		add_import_plugin(instance)
		_importers.append(instance)
	add_tool_menu_item(SETUP_MENU_ITEM, _set_up_project)
	add_tool_menu_item(EXPORT_MENU_ITEM, _export_game_config)
	add_tool_menu_item(EXTRACT_MENU_ITEM, _choose_wad)
	_gizmo = QuakeMapGizmo.new()
	add_node_3d_gizmo_plugin(_gizmo)
	_fog_gizmo = QuakeGroundFogGizmo.new()
	_fog_gizmo.undo_redo = get_undo_redo()
	add_node_3d_gizmo_plugin(_fog_gizmo)
	_inspector = preload("quake_entity_inspector.gd").new()
	_inspector.gizmo = _gizmo
	add_inspector_plugin(_inspector)
	resource_saved.connect(_on_resource_saved)
	_watcher = QuakeMapWatcher.new()
	add_child(_watcher)
	EditorInterface.get_resource_filesystem().resources_reimported.connect(_on_resources_reimported)

	_bake_button = Button.new()
	_bake_button.text = BAKE_TEXT
	_bake_button.flat = true
	_bake_button.hide()
	_bake_button.pressed.connect(_bake)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _bake_button)

	_add_browser()

	_auto_bake_timer = Timer.new()
	_auto_bake_timer.one_shot = true
	_auto_bake_timer.timeout.connect(_auto_bake)
	add_child(_auto_bake_timer)
	# history_changed for new edits, version_changed for undo and redo
	get_undo_redo().history_changed.connect(_on_scene_changed)
	get_undo_redo().version_changed.connect(_on_scene_changed)


func _exit_tree() -> void:
	resource_saved.disconnect(_on_resource_saved)
	EditorInterface.get_resource_filesystem().resources_reimported.disconnect(_on_resources_reimported)
	_watcher.queue_free()
	for file_menu in _file_menus:
		remove_context_menu_plugin(file_menu)
	_file_menus.clear()
	remove_inspector_plugin(_inspector)
	remove_node_3d_gizmo_plugin(_gizmo)
	remove_node_3d_gizmo_plugin(_fog_gizmo)
	get_undo_redo().history_changed.disconnect(_on_scene_changed)
	get_undo_redo().version_changed.disconnect(_on_scene_changed)
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _bake_button)
	_bake_button.queue_free()
	_remove_browser()
	remove_tool_menu_item(SETUP_MENU_ITEM)
	remove_tool_menu_item(EXPORT_MENU_ITEM)
	remove_tool_menu_item(EXTRACT_MENU_ITEM)
	for importer in _importers:
		remove_import_plugin(importer)
	_importers.clear()


func _handles(object: Object) -> bool:
	return object is QuakeLightmap


func _edit(object: Object) -> void:
	_lightmap = object as QuakeLightmap


func _make_visible(visible: bool) -> void:
	_bake_button.visible = visible


func _bake() -> void:
	if _lightmap:
		_bake_lightmap(_lightmap)


func _bake_lightmap(lightmap: QuakeLightmap) -> void:
	if lightmap.is_baking():
		return
	_bake_button.disabled = true
	_bake_button.text = BAKING_TEXT
	var path: String = await lightmap.bake()
	_bake_button.disabled = false
	_bake_button.text = BAKE_TEXT
	if path.is_empty():
		return
	EditorInterface.get_resource_filesystem().update_file(path)
	# marking the scene unsaved must not start the next auto bake, an edit during the bake may
	var edited_while_baking := not _auto_bake_timer.is_stopped()
	EditorInterface.mark_scene_as_unsaved()
	if not edited_while_baking:
		_auto_bake_timer.stop()


## Every edit restarts the timer, so it bakes once things stay put.
func _on_scene_changed() -> void:
	var lightmap := _auto_bake_lightmap()
	if lightmap:
		_auto_bake_timer.start(lightmap.auto_bake_delay)


## A map placed in the open scene changed, its light needs a new bake.
func _on_resources_reimported(resources: PackedStringArray) -> void:
	if resources.has(_browser.path):
		_show_in_browser(_browser.path)
	var root := EditorInterface.get_edited_scene_root()
	if not root:
		return
	for map in root.find_children("*", "Node3D", true, false):
		if map is QuakeMap and resources.has(map.scene_file_path):
			_on_scene_changed()
			return


func _auto_bake() -> void:
	var lightmap := _auto_bake_lightmap()
	if not lightmap:
		return
	if lightmap.is_baking():
		_auto_bake_timer.start(lightmap.auto_bake_delay)
	else:
		_bake_lightmap(lightmap)


## Only in saved scenes, baking needs the path.
func _auto_bake_lightmap() -> QuakeLightmap:
	var root := EditorInterface.get_edited_scene_root()
	if not root or root.scene_file_path.is_empty():
		return null
	for node in [root] + root.find_children("*", "Node3D"):
		if node is QuakeLightmap and node.auto_bake:
			return node
	return null


## Any wad on disk, e.g. of a Quake install.
func _choose_wad() -> void:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	dialog.add_filter("*.wad", "Quake WAD")
	dialog.title = EXTRACT_MENU_ITEM.trim_suffix("...")
	dialog.file_selected.connect(_extract_wad)
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			dialog.queue_free())
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_file_dialog()


func _extract_wad(path: String) -> void:
	QuakeWadExtractor.extract_to_project(path)


## EditorDock from Godot 4.6, the bottom panel before.
func _add_browser() -> void:
	_browser = preload("quake_browser.gd").new()
	_browser.extract_requested.connect(_extract_wad)
	if ClassDB.class_exists(&"EditorDock"):
		_browser_dock = ClassDB.instantiate(&"EditorDock")
		_browser_dock.set(&"title", "Quake")
		_browser_dock.set(&"layout_key", "libquake_browser")
		_browser_dock.set(&"default_slot", ClassDB.class_get_integer_constant(&"EditorDock", &"DOCK_SLOT_BOTTOM"))
		_browser_dock.add_child(_browser)
		call(&"add_dock", _browser_dock)
	else:
		_browser_dock = _browser
		add_control_to_bottom_panel(_browser, "Quake")
	var file_system := EditorInterface.get_file_system_dock()
	if file_system.has_signal(&"selection_changed"):
		file_system.connect(&"selection_changed", _on_files_selected)


func _remove_browser() -> void:
	var file_system := EditorInterface.get_file_system_dock()
	if file_system.is_connected(&"selection_changed", _on_files_selected):
		file_system.disconnect(&"selection_changed", _on_files_selected)
	if _browser_dock != _browser:
		call(&"remove_dock", _browser_dock)
	else:
		remove_control_from_bottom_panel(_browser)
	_browser_dock.queue_free()


func _on_files_selected() -> void:
	var paths := EditorInterface.get_selected_paths()
	if paths.size() == 1 and _show_in_browser(paths[0]):
		if _browser_dock != _browser:
			_browser_dock.call(&"make_visible")
		else:
			make_bottom_panel_item_visible(_browser)


## Checks the type first, so a click never loads a level.
func _show_in_browser(path: String) -> bool:
	if not path.get_extension().to_lower() in ["map", "wad"]:
		return false
	if EditorInterface.get_resource_filesystem().get_file_type(path) != "Resource":
		return false
	var resource := load(path)
	if resource is QuakePieces:
		_browser.show_pieces(resource, path)
	elif resource is QuakeWadTextures:
		_browser.show_wad(resource, path)
	else:
		return false
	return true


func _set_up_project() -> void:
	var lines := QuakeProjectSetup.run()
	EditorInterface.get_resource_filesystem().scan()
	var dialog := AcceptDialog.new()
	dialog.title = SETUP_MENU_ITEM
	dialog.dialog_text = "\n".join(lines)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	EditorInterface.popup_dialog_centered(dialog)


func _export_game_config() -> void:
	QuakeTrenchBroom.export_game_config(_project_entity_classes())


## Saving the entity classes, a script they use or a ground fog style exports the game config again.
func _on_resource_saved(resource: Resource) -> void:
	var classes := _project_entity_classes()
	if resource is QuakeGroundFogStyle:
		QuakeTrenchBroom.export_game_config(classes)
		return
	if not classes:
		return
	if resource.resource_path == classes.resource_path or (resource is Script and classes.uses_script(resource)):
		QuakeTrenchBroom.export_game_config(classes)


func _project_entity_classes() -> QuakeEntityClasses:
	var path: String = QuakeImportSettings.project_default("entities/entity_classes")
	return load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
