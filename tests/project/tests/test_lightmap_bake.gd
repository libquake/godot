extends QuakeTest

const SAVED := "res://scenes/bake.lightmap.res"

var _frames := 0


func test_bake() -> void:
	var scene := add_scene("res://scenes/bake.tscn")
	await frames(1)
	var lightmap: QuakeLightmap = scene.get_node("QuakeLightmap")
	# as in a copy of another scene
	var foreign := QuakeLightmapData.new()
	foreign.take_over_path("res://scenes/other.lightmap.res")
	lightmap.data = foreign
	get_tree().process_frame.connect(_count_frame)
	var path: String = await lightmap.bake()
	get_tree().process_frame.disconnect(_count_frame)

	check_equal(path, SAVED, "saved next to the scene, not into the file of the assigned data")
	check(_frames > 0, "the editor keeps running while baking")
	var meshes := Array(lightmap.data.meshes).map(func(node_path: NodePath) -> String: return str(node_path))
	check(meshes.has("../Box"), "the box is baked")
	check(not meshes.has("../Rigid/Mesh"), "meshes of moving bodies are not")
	check(Array(lightmap.data.layers.get("styles", [])).has(1), "light styles are baked too")

	var material := scene.get_node("Box").get_active_material(0) as ShaderMaterial
	check(material != null and material.shader == QuakeMaterials.WORLD_SHADER, "the box gets the world shader")
	if material:
		check_equal(material.get_shader_parameter(&"uv_scale"), Vector2(4, 4), "tiling of the StandardMaterial3D")
	check_equal(scene.get_node("Light").light_cull_mask, 0xFFFFFFFF, "the baked light keeps its cull mask")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVED))


## Built while the game runs: no scene file, two modules side by side.
func test_bake_in_the_game() -> void:
	var level := Node3D.new()
	add_child(level)
	var lightmap := QuakeLightmap.new()
	level.add_child(lightmap)
	var module: PackedScene = load("res://maps/level.map")
	for index in 2:
		var map := module.instantiate()
		map.name = "Module%d" % index
		map.position = Vector3(40.0 * index, 0.0, 0.0)
		level.add_child(map)
	await frames(1)

	check(await lightmap.bake_to(), "baked without a scene file")
	check(lightmap.data != null and lightmap.data.resource_path.is_empty(), "kept in memory only")
	var meshes := Array(lightmap.data.meshes).map(func(node_path: NodePath) -> String: return str(node_path))
	check(meshes.any(func(path: String) -> bool: return path.begins_with("../Module0/")), "the first module")
	check(meshes.any(func(path: String) -> bool: return path.begins_with("../Module1/")), "the second, in the same bake")
	check(lightmap.data.grid_size.x * lightmap.data.grid_cell_size > 40.0, "one light grid over both")

	var cache := "user://libquake_test.lightmap.res"
	check(await lightmap.bake_to(cache), "baked into a cache")
	check(load(cache) is QuakeLightmapData, "saved where asked")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cache))
	level.queue_free()


func _count_frame() -> void:
	_frames += 1


func test_only_the_world_casts_shadows() -> void:
	var scope := Node3D.new()
	add_child(scope)
	var lightmap := QuakeLightmap.new()
	scope.add_child(lightmap)
	var cases := {"worldspawn": true, "func_group": true, "func_detail_wall": true, "func_door": false}
	for classname: String in cases:
		check_equal(lightmap._entity_casts_shadow(_entity_mesh(scope, classname, {})), cases[classname], classname)
	check(lightmap._entity_casts_shadow(_entity_mesh(scope, "func_door", {"_shadow": "1"})), "func_door with _shadow 1")
	var plain := MeshInstance3D.new()
	scope.add_child(plain)
	check(lightmap._entity_casts_shadow(plain), "a mesh outside of maps")
	scope.queue_free()


static func _entity_mesh(scope: Node, classname: String, properties: Dictionary) -> MeshInstance3D:
	var entity := StaticBody3D.new()
	entity.set_meta(QuakeSceneBuilder.ENTITY_META, {"classname": classname, "properties": properties})
	scope.add_child(entity)
	var mesh := MeshInstance3D.new()
	entity.add_child(mesh)
	return mesh


## Light bounced off a lit floor reaches a wall the spot itself misses, tinted like the floor.
func test_bounce() -> void:
	var gray := _bounced_wall(0, Color(0.5, 0.5, 0.5))
	check_equal(gray.r8, 0, "the spot alone leaves the wall dark")
	var bounced := _bounced_wall(1, Color(0.5, 0.5, 0.5))
	check(bounced.r8 > 0, "one bounce lights it")
	check_equal(bounced.r8, bounced.g8, "off a gray floor in gray")


## The middle of a wall standing on the edge of a lit floor, both 8 m, a spot pointing down onto the floor.
func _bounced_wall(bounces: int, floor_color: Color) -> Color:
	var baker := QuakeLightBaker.new()
	baker.bounces = bounces
	var square := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var triangles := PackedInt32Array([0, 1, 2, 0, 2, 3])
	baker.add_surface(PackedVector3Array([Vector3(0, 0, 0), Vector3(8, 0, 0), Vector3(8, 0, 8), Vector3(0, 0, 8)]),
			PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]), square, triangles, 1.0,
			PackedColorArray([floor_color, floor_color]))
	var wall := baker.add_surface(
			PackedVector3Array([Vector3(8, 0, 0), Vector3(8, 0, 8), Vector3(8, 8, 8), Vector3(8, 8, 0)]),
			PackedVector3Array([Vector3.LEFT, Vector3.LEFT, Vector3.LEFT, Vector3.LEFT]), square, triangles, 1.0)
	baker.add_light(QuakeLightBaker.LIGHT_SPOT, Vector3(3, 4, 4), Vector3.DOWN, Color.WHITE, 600.0, 0.0, 60.0, false)
	baker.bake()
	var image := baker.get_lightmap_image()
	var uv := baker.get_surface_uv_transform(wall)
	var at := Vector2(0.5 * uv.x + uv.z, 0.5 * uv.y + uv.w) * Vector2(image.get_size())
	return image.get_pixelv(Vector2i(at))


## The world shader's albedo_color comes back as a Vector4 when it was set as one.
func test_surface_color_of_world_materials() -> void:
	var lightmap := QuakeLightmap.new()
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var material := ShaderMaterial.new()
	material.shader = QuakeMaterials.WORLD_SHADER
	material.set_shader_parameter(&"albedo_texture", ImageTexture.create_from_image(image))
	material.set_shader_parameter(&"albedo_color", Vector4(0.5, 1.0, 1.0, 1.0))
	check_equal(lightmap._surface_color(material), Color(0.5, 1.0, 1.0, 1.0), "texture average times albedo_color")
	lightmap.free()


## Ambient occlusion darkens the floor next to a wall, dirt 0 switches it off.
func test_dirt() -> void:
	var open := _floor_at_wall(0)
	var dark := _floor_at_wall(1)
	check(dark.r8 < open.r8, "darker next to the wall")


## A floor of 8 m with a wall on its edge as an occluder, a light high above; the floor texel next to the wall.
func _floor_at_wall(dirt: int) -> Color:
	var baker := QuakeLightBaker.new()
	baker.dirt = dirt
	var square := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var triangles := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var floor_surface := baker.add_surface(
			PackedVector3Array([Vector3(0, 0, 0), Vector3(8, 0, 0), Vector3(8, 0, 8), Vector3(0, 0, 8)]),
			PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]), square, triangles, 1.0)
	baker.add_occluder(PackedVector3Array([Vector3(8, 0, 0), Vector3(8, 0, 8), Vector3(8, 8, 8), Vector3(8, 8, 0)]),
			triangles, false)
	baker.add_light(QuakeLightBaker.LIGHT_POINT, Vector3(4, 10, 4), Vector3.DOWN, Color.WHITE, 900.0, 0.0, 0.0, false)
	baker.bake()
	var image := baker.get_lightmap_image()
	var uv := baker.get_surface_uv_transform(floor_surface)
	var at := Vector2(0.98 * uv.x + uv.z, 0.5 * uv.y + uv.w) * Vector2(image.get_size())
	return image.get_pixelv(Vector2i(at))


## The inspector shows the baked material: a color set there goes back to the source and survives a new bake.
func test_edits_on_the_baked_material_are_kept() -> void:
	var source := StandardMaterial3D.new()
	source.albedo_color = Color.RED
	var baked := QuakeLightmap._world_material(source)
	baked.set_meta(QuakeLightmap.SOURCE_META, source)
	baked.set_shader_parameter(&"albedo_color", Color.GREEN)
	check(QuakeLightmap._source(baked) == source, "the source comes back")
	check_equal(source.albedo_color, Color.GREEN, "with the color set on the baked material")


## Sources in the world shader keep their color as a Vector4 as well.
func test_edits_on_baked_world_materials_are_kept() -> void:
	var source := ShaderMaterial.new()
	source.shader = QuakeMaterials.WORLD_SHADER
	source.set_shader_parameter(&"albedo_color", Vector4(1, 0, 0, 1))
	var baked := source.duplicate() as ShaderMaterial
	baked.set_meta(QuakeLightmap.SOURCE_META, source)
	baked.set_shader_parameter(&"albedo_color", Vector4(0, 1, 0, 1))
	QuakeLightmap._source(baked)
	check_equal(QuakeLightmap._albedo_color(source), Color.GREEN, "the color set on the baked material")
