extends QuakeTest

const TRIGGER := Vector3(-5.75, 1.0, 0.0)


func test_keys_are_parsed() -> void:
	var node := Node.new()
	node.set_meta(QuakeSceneBuilder.ENTITY_META, {"properties": {
		"speed": "250", "lip": "8.5", "mangle": "0 -90 0", "_color": "255 128 0", "spawnflags": "5"}})
	check_equal(QuakeEntity.get_int(node, "speed"), 250, "int")
	check_equal(QuakeEntity.get_float(node, "lip"), 8.5, "float")
	check_equal(QuakeEntity.get_float(node, "missing", 3.0), 3.0, "default")
	check_equal(QuakeEntity.get_vector(node, "mangle"), Vector3(0, -90, 0), "vector")
	check(QuakeEntity.get_color(node, "_color").is_equal_approx(Color(1, 128.0 / 255.0, 0)), "0-255 color")
	check(QuakeEntity.has_spawnflag(node, 4) and not QuakeEntity.has_spawnflag(node, 2), "spawnflags")
	node.free()


func test_keys_land_in_export_variables() -> void:
	var map: QuakeMap = add_scene("res://maps/level.map")
	await frames(1)
	var destination: QuakeTeleportDestination = map.find_entities("info_teleport_destination")[0]
	check_equal(destination.exit_speed, 160.0, "the key exit_speed, parsed to the variable's float")


func test_units_follow_the_map() -> void:
	var map: QuakeMap = add_scene("res://maps/level.map")
	await frames(1)
	var destination: Node = map.find_entities("info_teleport_destination")[0]
	check_equal(map.units_per_meter, 32.0, "the import option on the map")
	check_equal(QuakeEntity.meters(destination, 160.0), 5.0, "units of its map in meters")
	var options := {}
	for option in QuakeImportSettings.level_options():
		options[option.name] = option.default_value
	options["geometry/units_per_meter"] = 64.0
	var big: QuakeMap = QuakeSceneBuilder.new().build(QuakeMapLoader.new("res://maps/level.map", options), options, "big")
	add_child(big)
	check_equal(QuakeEntity.meters(big.find_entities("info_teleport_destination")[0], 160.0), 2.5, "another scale")
	var loose := Node3D.new()
	check_equal(QuakeEntity.meters(loose, 64.0), 2.0, "outside a map, the project's default")
	loose.free()


func test_export_variables_become_fgd_keys() -> void:
	var entity_class := QuakeEntityClass.new()
	entity_class.classname = "info_teleport_destination"
	entity_class.node_script = load("res://addons/libquake/examples/quake_teleport_destination.gd")
	entity_class.properties.assign({"angle": 0})
	check(entity_class.all_properties().has("exit_speed"), "the @export variable is a key")
	check(entity_class.to_fgd().contains("exit_speed(float)"), "with the variable's type")
	check(entity_class.to_fgd().contains("angle(integer)"), "next to the keys of properties")


func test_parse_turns_text_into_types() -> void:
	check_equal(QuakeEntity.parse("1.5", TYPE_INT), 1, "a float key as int")
	check_equal(QuakeEntity.parse("1", TYPE_BOOL), true, "1 is true")
	check_equal(QuakeEntity.parse("abc", TYPE_FLOAT), null, "text that is no number")


func test_lights_with_a_targetname_are_switchable() -> void:
	var map: QuakeMap = add_scene("res://maps/level.map")
	await frames(1)
	var lamp: Node = map.find_targets("lamp")[0]
	check(lamp is QuakeSwitchableLight, "a light with a targetname switches")
	check_equal(lamp.style, 32, "the first switchable style")
	var styles: QuakeLightStyles = map.get_node("LightStyles")
	check(Array(styles.layers.styles).has(32), "the bake gave it the same style")
	check_equal(styles.get_style(32), "a", "spawnflag 1 starts it off")


func test_triggers_fire_their_targets() -> void:
	var map: QuakeMap = add_scene("res://maps/level.map")
	await frames(1)
	var styles: QuakeLightStyles = map.get_node("LightStyles")
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	body.add_child(shape)
	add_child(body)
	body.global_position = TRIGGER
	await physics_frames(5)
	check_equal(styles.get_style(32), "m", "walking into the trigger switches the lamp on")
