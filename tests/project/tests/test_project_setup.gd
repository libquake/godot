extends QuakeTest

const FOG_SETTING := QuakeImportSettings.PREFIX + "entities/ground_fog_styles"


func test_a_set_up_project_stays_as_it_is() -> void:
	var lines := "\n".join(QuakeProjectSetup.run(false, false))
	check(not lines.contains("Created") and not lines.contains("Set "), lines)


func test_missing_settings_are_filled_in() -> void:
	var before: PackedStringArray = ProjectSettings.get_setting(FOG_SETTING)
	ProjectSettings.set_setting(FOG_SETTING, PackedStringArray())
	var lines := "\n".join(QuakeProjectSetup.run(false, false))
	check_equal(ProjectSettings.get_setting(FOG_SETTING), PackedStringArray([QuakeProjectSetup.FOG_STYLES]), "the fog styles")
	check(lines.contains("Set libquake/entities/ground_fog_styles"), lines)
	ProjectSettings.set_setting(FOG_SETTING, before)
