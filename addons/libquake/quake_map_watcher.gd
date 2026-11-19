@tool
class_name QuakeMapWatcher
extends Node
## Reimports a map when TrenchBroom saves it, also while the editor is in the background.

const SETTING := "libquake/editor/watch_maps"
const EXTENSIONS := ["map", "bsp"]
const INTERVAL := 0.5

var _modified_times := {}
var _timer := Timer.new()


static func register_setting() -> void:
	if not ProjectSettings.has_setting(SETTING):
		ProjectSettings.set_setting(SETTING, true)
	ProjectSettings.set_initial_value(SETTING, true)
	ProjectSettings.set_as_basic(SETTING, true)


func _ready() -> void:
	_timer.wait_time = INTERVAL
	_timer.timeout.connect(_check)
	add_child(_timer)
	_timer.start()
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_collect)
	_collect()


func _check() -> void:
	var file_system := EditorInterface.get_resource_filesystem()
	if not ProjectSettings.get_setting(SETTING, true) or file_system.is_scanning():
		return
	var changed := PackedStringArray()
	for path: String in _modified_times:
		var modified := FileAccess.get_modified_time(path)
		if modified != _modified_times[path]:
			_modified_times[path] = modified
			changed.append(path)
	if not changed.is_empty():
		file_system.reimport_files(changed)


func _collect() -> void:
	var paths := PackedStringArray()
	_find_maps(EditorInterface.get_resource_filesystem().get_filesystem(), paths)
	var times := {}
	for path in paths:
		times[path] = _modified_times.get(path, FileAccess.get_modified_time(path))
	_modified_times = times


static func _find_maps(directory: EditorFileSystemDirectory, paths: PackedStringArray) -> void:
	for index in directory.get_file_count():
		if EXTENSIONS.has(directory.get_file(index).get_extension().to_lower()):
			paths.append(directory.get_file_path(index))
	for index in directory.get_subdir_count():
		_find_maps(directory.get_subdir(index), paths)
