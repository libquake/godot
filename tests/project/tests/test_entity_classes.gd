extends QuakeTest


func test_exact_names_win_over_prefixes() -> void:
	var classes := QuakeEntityClasses.new()
	for classname in ["light*", "l*", "light"]:
		var entity_class := QuakeEntityClass.new()
		entity_class.classname = classname
		classes.classes.append(entity_class)
	check_equal(classes.find("light").classname, "light", "exact")
	check_equal(classes.find("light_fluoro").classname, "light*", "longer prefix")
	check_equal(classes.find("lamp").classname, "l*", "shorter prefix")
	check(classes.find("info_null") == null, "no match")


func test_fgd_types_follow_the_defaults() -> void:
	var entity_class := QuakeEntityClass.new()
	entity_class.classname = "func_test"
	entity_class.type = QuakeEntityClass.Type.BRUSH
	entity_class.properties.assign({"count": 1, "speed": 2.5, "on": true, "_color": Color(1, 0.5, 0),
		"offset": Vector3(1, 2, 3), "name": "x"})
	var fgd := entity_class.to_fgd()
	for expected in ["@SolidClass", "count(integer)", "speed(float)", "on(choices)", "_color(color1)",
			'offset(string) : "" : "1 2 3"', 'name(string) : "" : "x"']:
		check(fgd.contains(expected), "FGD has %s" % expected)


func test_builtin_entities_are_in_every_fgd() -> void:
	var fgd := QuakeEntityClasses.new().to_fgd()
	check(fgd.contains("= worldspawn"), "worldspawn")
	check(fgd.contains("_meshlib(choices)"), "the pieces key")
	check(fgd.contains("= light :"), "light")


func test_classes_know_their_scripts() -> void:
	var classes: QuakeEntityClasses = load("res://entity_classes.tres")
	check(classes.uses_script(load("res://addons/libquake/examples/quake_teleport.gd")), "a mapped script")
	check(not classes.uses_script(load("res://tests/quake_test.gd")), "any other script")
