@tool
class_name QuakeProjectSetup
extends RefCounted
## Project > Tools > Set up libquake Project: what a project needs to make maps, filled in where it is missing.
## Nothing that is there gets changed, so running it again is harmless.

const MAPS := "res://maps"
const ENTITY_CLASSES := "res://entity_classes.tres"
const FOG_STYLES := "res://fog_styles"
const EXECUTABLE_SETTING := "libquake/trenchbroom/executable"


## Returns what it did and what is left to the user, one line each. save writes project.godot,
## export_config the TrenchBroom game config.
static func run(save := true, export_config := true) -> PackedStringArray:
	var lines := PackedStringArray()
	var texture_directories: PackedStringArray = QuakeImportSettings.project_default("textures/texture_directories")
	for folder in [MAPS] + Array(texture_directories):
		_make_folder(folder, lines)

	var classes_path: String = QuakeImportSettings.project_default("entities/entity_classes")
	if classes_path.is_empty():
		classes_path = ENTITY_CLASSES
		if not ResourceLoader.exists(classes_path):
			ResourceSaver.save(QuakeEntityClasses.new(), classes_path)
			lines.append("Created %s for the project's entity classes." % classes_path)
		_set_option(&"entities/entity_classes", classes_path, lines)

	if QuakeImportSettings.project_default("entities/ground_fog_styles").is_empty():
		_make_folder(FOG_STYLES, lines)
		_set_option(&"entities/ground_fog_styles", PackedStringArray([FOG_STYLES]), lines)

	if save:
		ProjectSettings.save()

	# a bare name is looked up on the PATH when it starts
	var executable: String = ProjectSettings.get_setting(EXECUTABLE_SETTING, "")
	if executable.is_empty() or (executable.is_absolute_path() and not FileAccess.file_exists(executable)
			and not DirAccess.dir_exists_absolute(executable)):
		lines.append("TrenchBroom not found at '%s': set %s, then export the game config again." % [executable,
				EXECUTABLE_SETTING])
	if export_config:
		var classes: QuakeEntityClasses = load(classes_path) if ResourceLoader.exists(classes_path) else null
		if QuakeTrenchBroom.export_game_config(classes) == OK:
			lines.append("Exported the TrenchBroom game config '%s'." % QuakeTrenchBroom.game_name())

	if lines.is_empty():
		lines.append("Everything was set up already.")
	return lines


static func _make_folder(folder: String, lines: PackedStringArray) -> void:
	if DirAccess.dir_exists_absolute(folder):
		return
	DirAccess.make_dir_recursive_absolute(folder)
	lines.append("Created %s." % folder)


static func _set_option(option: StringName, value: Variant, lines: PackedStringArray) -> void:
	ProjectSettings.set_setting(QuakeImportSettings.PREFIX + option, value)
	lines.append("Set %s%s to %s." % [QuakeImportSettings.PREFIX, option, value])
