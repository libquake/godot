extends QuakeTest


func test_a_brush_becomes_its_box() -> void:
	var map: QuakeMap = add_scene("res://maps/level.map")
	await frames(1)
	var fog: Node = _fog_with_style(map, "thick")
	check(fog is QuakeGroundFog, "func_groundfog is a QuakeGroundFog")
	check(fog.size.is_equal_approx(Vector3(4, 2, 4)), "the brush's size: %s" % fog.size)
	check(fog.position.is_equal_approx(Vector3(-8, 1, -8)), "centered on the brush: %s" % fog.position)
	check_equal(fog.get_child_count(), 0, "no mesh or collision of the brush")
	check_equal(fog.find_children("*", "MeshInstance3D", false, false).size(), 1, "the fog's own box")


func test_the_style_key_picks_a_style() -> void:
	var map: QuakeMap = add_scene("res://maps/level.map")
	await frames(1)
	var fog: QuakeGroundFog = _fog_with_style(map, "thick")
	check(fog.style and fog.style.resource_path == "res://fog_styles/thick.tres", "the style of that name")
	check_equal(_material(fog).get_shader_parameter("density"), 3.0, "its look in the shader")
	var lost: QuakeGroundFog = _fog_with_style(map, "nowhere")
	check_equal(lost.style, null, "an unknown style leaves it to the default")
	check_equal(_material(lost).get_shader_parameter("density"), 0.7, "the project's default, not libquake's")


func test_unknown_styles_are_reported() -> void:
	var options := {}
	for option in QuakeImportSettings.level_options():
		options[option.name] = option.default_value
	var builder := QuakeSceneBuilder.new()
	builder.build(QuakeMapLoader.new("res://maps/level.map", options), options, "level").free()
	var report := "\n".join(builder.report())
	check(report.contains("ground fog styles not found, default used: nowhere"), report)
	check(report.contains("ground fog boxes lower than their fog with its hills") and report.contains("(0.50 m of 0.90 m)"), report)


func test_warnings_name_a_low_or_floating_box() -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(20, 1, 20)
	ground.add_child(shape)
	add_child(ground)
	var fog := QuakeGroundFog.new()
	fog.size = Vector3(4, 2, 4)
	add_child(fog)
	fog.position = Vector3(0, 1.5, 0)
	await physics_frames(2)
	check_equal(fog.floor_below(), 0.5, "the top of the ground")
	check_equal(fog._get_configuration_warnings().size(), 0, "a box on the floor: %s" % fog._get_configuration_warnings())
	fog.position = Vector3(0, 4, 0)
	check(fog._get_configuration_warnings().size() == 1 and fog._get_configuration_warnings()[0].contains("floats 2.50 m"),
			"a floating box: %s" % fog._get_configuration_warnings())
	fog.drop_to_floor.call()
	check(is_equal_approx(fog.position.y, 1.5 - QuakeGroundFog.FLOOR_SINK), "dropped: %s" % fog.position)
	fog.size = Vector3(4, 0.5, 4)
	fog.position.y = 0.75
	check(fog._get_configuration_warnings().size() == 1 and fog._get_configuration_warnings()[0].contains("cut flat"),
			"a low box: %s" % fog._get_configuration_warnings())


func test_editing_a_style_shows_at_once() -> void:
	var style: QuakeGroundFogStyle = load("res://fog_styles/thick.tres").duplicate()
	var fog := QuakeGroundFog.new()
	fog.style = style
	add_child(fog)
	style.alpha_steps = 7
	check_equal(_material(fog).get_shader_parameter("alpha_steps"), 7, "a value changed on the style")
	fog.style = null
	check_equal(_material(fog).get_shader_parameter("density"), 0.7, "back to the default")
	style.alpha_steps = 9
	check_equal(_material(fog).get_shader_parameter("alpha_steps"), 4, "the old style lets go")
	fog.size = Vector3(2, 1, 6)
	check_equal(_material(fog).get_shader_parameter("half_size"), Vector3(1, 0.5, 3), "the box")


func test_project_styles_win_on_the_same_name() -> void:
	check_equal(QuakeGroundFogStyle.find("default").resource_path, "res://fog_styles/default.tres", "the project's")
	check_equal(QuakeGroundFogStyle.find("default", PackedStringArray()).resource_path,
			QuakeGroundFogStyle.BUILTIN_DIRECTORY.path_join("default.tres"), "libquake's without project folders")
	check_equal(QuakeGroundFogStyle.names(), PackedStringArray(["default", "thick"]), "default first, once")


func test_the_fgd_offers_the_styles() -> void:
	var fgd := QuakeEntityClasses.new().to_fgd()
	check(fgd.contains("@SolidClass") and fgd.contains("= func_groundfog :"), "a brush entity")
	check(fgd.contains('style(choices) : "Its look, a QuakeGroundFogStyle by file name" : "default" = [ "default" : "default" "thick" : "thick" ]'), fgd)
	check(not fgd.contains("size(string)"), "no size key, the brush is the box")


func _fog_with_style(map: QuakeMap, style_name: String) -> Node:
	for fog in map.find_entities(QuakeGroundFog.CLASSNAME):
		if QuakeEntity.get_string(fog, "style") == style_name:
			return fog
	return null


func _material(fog: QuakeGroundFog) -> ShaderMaterial:
	return fog.find_children("*", "MeshInstance3D", false, false)[0].material_override
