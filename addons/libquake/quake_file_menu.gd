@tool
extends EditorContextMenuPlugin
## FileSystem dock: "Open in TrenchBroom" on maps, and a new map in a folder, opened in TrenchBroom right away.

const EXECUTABLE_SETTING := "libquake/trenchbroom/executable"


static func register_setting() -> void:
	var default := _default_executable()
	if not ProjectSettings.has_setting(EXECUTABLE_SETTING):
		ProjectSettings.set_setting(EXECUTABLE_SETTING, default)
	ProjectSettings.set_initial_value(EXECUTABLE_SETTING, default)
	ProjectSettings.set_as_basic(EXECUTABLE_SETTING, true)


func _popup_menu(paths: PackedStringArray) -> void:
	if paths.size() == 1 and paths[0].ends_with("/"):
		add_context_menu_item("Quake Map...", _create_map)
	elif not paths.is_empty() and Array(paths).all(func(path: String) -> bool: return path.get_extension().to_lower() == "map"):
		add_context_menu_item("Open in TrenchBroom", _open)


func _create_map(paths: PackedStringArray) -> void:
	var path := paths[0].path_join("new_map.map")
	var number := 2
	while FileAccess.file_exists(path):
		path = paths[0].path_join("new_map_%d.map" % number)
		number += 1
	# the game header lets TrenchBroom pick the exported game config, Valve 220 is its default format
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('// Game: %s\n// Format: Valve\n// entity 0\n{\n"classname" "worldspawn"\n"mapversion" "220"\n}\n' \
			% QuakeTrenchBroom.game_name())
	file.close()
	EditorInterface.get_resource_filesystem().update_file(path)
	EditorInterface.select_file(path)
	_open(PackedStringArray([path]))


static func _open(paths: PackedStringArray) -> void:
	var executable: String = ProjectSettings.get_setting(EXECUTABLE_SETTING, _default_executable())
	for path in paths:
		var file := ProjectSettings.globalize_path(path)
		if OS.get_name() == "macOS":
			OS.create_process("open", ["-a", executable, file])
		else:
			OS.create_process(executable, [file])


static func _default_executable() -> String:
	match OS.get_name():
		"macOS":
			return "/Applications/TrenchBroom.app"
		"Windows":
			return "C:/Program Files/TrenchBroom/TrenchBroom.exe"
		_:
			return "trenchbroom"
