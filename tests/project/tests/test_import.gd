extends QuakeTest


func test_level_becomes_a_scene() -> void:
	var map: QuakeMap = add_scene("res://maps/level.map")
	await frames(1)
	check_equal(map.find_entities("info_player_start").size(), 1, "player starts")
	var world: Node = map.find_entities("worldspawn")[0]
	check(world is StaticBody3D, "the worldspawn is a StaticBody3D")
	check(world.find_children("*", "CollisionShape3D", false, false).size() >= 2, "a hull per solid brush")
	check_equal(map.find_children("LightGrid", "", false, false).size(), 1, "light grid")


func test_liquids_are_areas() -> void:
	add_scene("res://maps/level.map")
	await frames(1)
	var liquids := get_tree().get_nodes_in_group(QuakeLiquids.GROUP)
	check_equal(liquids.size(), 1, "liquid areas")
	if not liquids.is_empty():
		check_equal(liquids[0].get_meta(QuakeLiquids.KIND_META), "water", "liquid kind from #water.png")


func test_triggers_are_not_drawn() -> void:
	var map: QuakeMap = add_scene("res://maps/level.map")
	await frames(1)
	var trigger: Node = map.find_entities("trigger_teleport")[0]
	check(trigger is QuakeTeleport, "the entity class gives the trigger its script")
	check_equal(trigger.find_children("*", "MeshInstance3D", false, false).size(), 0, "meshes of a trigger")
	check_equal(trigger.find_children("*", "CollisionShape3D", false, false).size(), 1, "collision of a trigger")


func test_ladders_are_areas() -> void:
	var map: QuakeMap = add_scene("res://maps/level.map")
	await frames(1)
	var ladders := map.find_entities(QuakeBuiltinEntities.LADDER)
	check_equal(ladders.size(), 1, "ladders")
	if not ladders.is_empty():
		check(ladders[0] is Area3D, "a ladder is an Area3D")
		check(ladders[0].is_in_group(&"func_ladder"), "in the group func_ladder")
		check_equal(ladders[0].find_children("*", "MeshInstance3D", false, false).size(), 0, "meshes of a ladder")
		check_equal(ladders[0].find_children("*", "CollisionShape3D", false, false).size(), 1, "collision of a ladder")


## Composes the imported layers like QuakeLightStyles does; a texture's pixels cannot be read back headless.
func test_light_styles_animate_the_lightmap() -> void:
	var map: QuakeMap = add_scene("res://maps/level.map")
	await frames(1)
	var styles: QuakeLightStyles = map.get_node("LightStyles")
	check(Array(styles.layers.styles).has(1), "the flickering light has its own layer")
	var animator := QuakeLightStyleAnimator.new()
	animator.setup(styles.layers)
	check(animator.update(0.0), "the first update composes the lightmap")
	var lit := animator.get_rgba()
	animator.set_style(1, "a")
	check(animator.update(0.0), "switching style 1 off is a change")
	check(animator.get_rgba() != lit, "switching style 1 off changes the lightmap")


func test_bsp_collides_with_its_faces() -> void:
	var map: QuakeMap = add_scene("res://maps/room.bsp")
	await frames(1)
	check(map.find_children("Faces", "CollisionShape3D", true, false).size() > 0, "face collision")
	var start: Node3D = map.find_entities("info_player_start")[0]
	var ball := RigidBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	ball.add_child(shape)
	add_child(ball)
	ball.global_position = start.global_position
	await physics_frames(120)
	check(ball.global_position.y > start.global_position.y - 2.0, "a body lands on the floor of a bsp")


func test_report_names_what_did_not_resolve() -> void:
	var options := {}
	for option in QuakeImportSettings.level_options():
		options[option.name] = option.default_value
	var loader := QuakeMapLoader.new("res://maps/level.map", options)
	var builder := QuakeSceneBuilder.new()
	builder.entity_classes = load("res://entity_classes.tres")
	builder.build(loader, options, "level").free()
	var report := "\n".join(builder.report())
	check(report.contains("info_player_start (1)"), "a point entity without class: %s" % report)
	check(report.contains("\"nowhere\""), "a target nothing answers to")
	check(not report.contains("missing textures"), "every texture of the map is there")


func test_the_map_keeps_its_warnings() -> void:
	var map: QuakeMap = add_scene("res://maps/level.map")
	await frames(1)
	check("\n".join(map.import_warnings).contains("info_player_start (1)"), "the report on the map: %s" % map.import_warnings)


func test_only_new_warnings_are_news() -> void:
	var before := PackedStringArray(["point entities without an entity class, placeholders only: monster_zombie (9)"])
	var more := PackedStringArray(["point entities without an entity class, placeholders only: monster_zombie (10)"])
	check_equal(QuakeSceneBuilder.new_warnings(before, more), PackedStringArray(), "one more of the same class")
	var other := PackedStringArray(["point entities without an entity class, placeholders only: monster_zombie (9), monster_dog (1)"])
	check_equal(QuakeSceneBuilder.new_warnings(before, other).size(), 1, "a class that was not there")
	var texture := PackedStringArray(["missing textures: wall1"])
	check_equal(QuakeSceneBuilder.new_warnings(before, before + texture), texture, "a new kind of problem")
	check_equal(QuakeSceneBuilder.new_warnings(PackedStringArray(), before), before, "the first import")


func test_brush_entities_are_drawn_a_little_off() -> void:
	var map: QuakeMap = add_scene("res://maps/level.map")
	await frames(1)
	var wall: Node3D = map.find_entities("func_wall")[0]
	var world: Node3D = map.find_entities("worldspawn")[0]
	check(wall.get_node("Mesh").position.y < 0.0, "a func_wall sinks below a floor it is flush with")
	check_equal(world.get_node("Mesh").position, Vector3.ZERO, "the world stays")
	check(wall.get_child_count() > 1 and not wall.get_children().any(func(c: Node) -> bool: return c is CollisionShape3D and c.position != Vector3.ZERO), "its collision stays")


## The inspector names the kinds of warnings, the Output has the lists.
func test_warnings_are_summed_up() -> void:
	var inspector: GDScript = load("res://addons/libquake/quake_entity_inspector.gd")
	var lines := PackedStringArray([
		"missing textures: wall1, wall2, floor3",
		"door targets \"a\", no entity has that targetname",
		"button targets \"b\", no entity has that targetname",
	])
	check_equal(inspector.summarize_warnings(lines),
			PackedStringArray(["missing textures (3)", "targets that no targetname matches (2)"]), "one line per kind")


## Six images named by the worldspawn's sky key make a skybox, one missing leaves Quake's sky.
func test_skybox() -> void:
	var folder := "user://skybox_test"
	DirAccess.make_dir_recursive_absolute(folder)
	var image := Image.create(4, 4, false, Image.FORMAT_RGB8)
	image.fill(Color.ORANGE)
	for suffix: String in QuakeSkybox.SUFFIXES:
		image.save_png(folder.path_join("dusk_%s.png" % suffix))
	var faces := QuakeSkybox.find("dusk_", PackedStringArray([folder]))
	check_equal(faces.size(), 6, "all six faces")
	check(faces.rt is Texture2D, "as textures")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join("dusk_dn.png")))
	check(QuakeSkybox.find("dusk_", PackedStringArray([folder])).is_empty(), "nothing without the floor")
	for suffix: String in QuakeSkybox.SUFFIXES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join("dusk_%s.png" % suffix)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))

	var level := QuakeLevel.new()
	var materials := QuakeMaterials.new(level, QuakeTextureFiles.new(PackedStringArray()), QuakeMaterials.Style.GODOT, {})
	materials.skybox = faces
	var sky := materials.get_material("sky1") as ShaderMaterial
	check(sky.shader == QuakeMaterials.SKYBOX_SHADER, "sky surfaces draw the skybox")
