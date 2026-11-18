@tool
class_name QuakeTrenchBroom
extends RefCounted
## Writes a TrenchBroom game configuration for the project into TrenchBroom's games folder:
## GameConfig.cfg, <game>.fgd and an icon. The project folder is the game path, so TrenchBroom finds the
## image textures in res://textures and the maps can be saved anywhere in the project.

const ICON_PATH := "res://addons/libquake/icons/quake_map.svg"


static func game_name() -> String:
	return str(ProjectSettings.get_setting("application/config/name", "Godot"))


## Where TrenchBroom looks for user game configurations.
static func games_directory() -> String:
	match OS.get_name():
		"macOS":
			return OS.get_environment("HOME").path_join("Library/Application Support/TrenchBroom/games")
		"Windows":
			return OS.get_environment("APPDATA").path_join("TrenchBroom/games")
		_:
			return OS.get_environment("HOME").path_join(".TrenchBroom/games")


static func export_game_config(entity_classes: QuakeEntityClasses) -> Error:
	var directory := games_directory().path_join(game_name())
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		push_error("libquake: cannot create %s" % directory)
		return error

	_write(directory.path_join("GameConfig.cfg"), _game_config())
	_write(directory.path_join(game_name() + ".fgd"), entity_classes.to_fgd() if entity_classes else QuakeEntityClasses.new().to_fgd())
	_write_icon(directory.path_join("Icon.png"))
	_write_palette()
	_set_game_path()
	print("libquake: TrenchBroom game \"%s\" written to %s" % [game_name(), directory])
	return OK


static func _game_config() -> String:
	var config := {
		"version": 9,
		"name": game_name(),
		"icon": "Icon.png",
		"fileformats": [{"format": "Valve"}, {"format": "Standard"}],
		"filesystem": {
			"searchpath": ".",
			"packageformat": {"extension": ".pak", "format": "idpak"},
		},
		"materials": {
			"root": _textures_root(),
			"extensions": [".png", ".tga", ".jpg", ".jpeg", ".webp", ".bmp", ".D"],
			"palette": _palette_path().trim_prefix("res://"),
			"attribute": "wad",
		},
		"entities": {
			"definitions": [game_name() + ".fgd"],
			"defaultcolor": "0.6 0.6 0.6 1.0",
		},
		"tags": {
			"brush": [
				{"name": "Detail", "attribs": [], "match": "classname", "pattern": "func_detail*"},
				{"name": "Trigger", "attribs": ["transparent"], "match": "classname", "pattern": "trigger*", "material": "trigger"},
			],
			"brushface": [
				{"name": "Clip", "attribs": ["transparent"], "match": "material", "pattern": "clip"},
				{"name": "Skip", "attribs": ["transparent"], "match": "material", "pattern": "skip"},
				{"name": "Liquid", "attribs": ["transparent"], "match": "material", "pattern": "\\**"},
			],
		},
		"faceattribs": {"surfaceflags": [], "contentflags": []},
	}
	return JSON.stringify(config, "\t", false)


## The first texture folder relative to the project, TrenchBroom's materials root.
static func _textures_root() -> String:
	var directories: PackedStringArray = QuakeImportSettings.project_default("textures/texture_directories")
	return directories[0].trim_prefix("res://") if not directories.is_empty() else "textures"


## TrenchBroom needs Quake's palette to show wad textures.
static func _palette_path() -> String:
	return "res://addons/libquake/palette.lmp"


static func _write_palette() -> void:
	if FileAccess.file_exists(_palette_path()):
		return
	var file := FileAccess.open(_palette_path(), FileAccess.WRITE)
	file.store_buffer(QuakeLevel.get_default_palette())


## Sets the project folder as the game path in TrenchBroom's preferences, unless one is set already.
## TrenchBroom writes its preferences when it quits, so it should not be running.
static func _set_game_path() -> void:
	var preferences_path := games_directory().get_base_dir().path_join("Preferences.json")
	var preferences := {}
	if FileAccess.file_exists(preferences_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(preferences_path))
		if parsed is Dictionary:
			preferences = parsed
	var key := "Games/%s/Path" % game_name()
	if preferences.has(key):
		return
	preferences[key] = ProjectSettings.globalize_path("res://").trim_suffix("/")
	_write(preferences_path, JSON.stringify(preferences, "    ", false, true))


static func _write_icon(path: String) -> void:
	var icon := Image.new()
	icon.load_svg_from_string(FileAccess.get_file_as_string(ICON_PATH), 2.0)
	icon.save_png(path)


static func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
