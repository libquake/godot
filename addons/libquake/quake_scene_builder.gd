@tool
class_name QuakeSceneBuilder
extends RefCounted
## Builds a QuakeMap scene: a node per entity, collision per brush, Area3Ds for liquids, the light grid. Entity
## nodes carry the meta "quake_entity" and are in a group named after their classname.

const ENTITY_META := &"quake_entity"

const TRIGGER_COLOR := Color(1.0, 0.55, 0.1, 0.35)
const LIQUID_COLOR := Color(0.2, 0.5, 1.0, 0.3)
# not 0: a scene does not store the default debug_color and loads the project's
const HIDDEN := Color(0.0, 0.0, 0.0, 1.0 / 255.0)
## FitzQuake's gl_zfix in map units: brush entities are drawn this far off against z-fighting.
const BRUSH_ENTITY_OFFSET := 1.0 / 32.0

var entity_classes: QuakeEntityClasses
var light_grid_cell_size := 1.0
var show_hulls := false

var _level: QuakeLevel
var _materials: QuakeMaterials
var _switchable_styles := {}
var _unmapped := {}
var _missing_fog_styles := {}
var _low_fogs := PackedStringArray()
var _fog_style_directories := PackedStringArray()
var _dangling_targets := PackedStringArray()


func build(loader: QuakeMapLoader, options: Dictionary, root_name: String) -> QuakeMap:
	_level = loader.level
	_materials = QuakeMaterials.new(_level, loader.texture_files, QuakeMaterials.Style.QUAKE,
			loader.liquid_alphas(options))
	_materials.fullbright_energy = options.get("surfaces/fullbright_energy", 1.0)
	_materials.skybox = QuakeSkybox.of_level(_level, options.get("textures/sky_directories",
			QuakeImportSettings.project_default("textures/sky_directories")))
	_fog_style_directories = options.get("entities/ground_fog_styles",
			QuakeImportSettings.project_default("entities/ground_fog_styles"))

	var root := QuakeMap.new()
	root.name = root_name
	root.units_per_meter = _level.get_units_per_meter()
	var entities := _level.get_entities()
	_switchable_styles = _switchable_light_styles(entities)
	for index in entities.size():
		var node := _build_entity(entities[index], index)
		if not node:
			continue
		root.add_child(node)
		_set_owner(node, root)
	if light_grid_cell_size > 0.0:
		var grid := QuakeLightGrid.from_level(_level, light_grid_cell_size)
		root.add_child(grid)
		grid.owner = root
	_report_targets(entities)
	var layers := _level.get_lightmap_layers()
	if not layers.is_empty():
		var styles := QuakeLightStyles.create(_materials.lightmap, layers)
		root.add_child(styles)
		styles.owner = root
	return root


## The lines of current not in previous, ignoring counts.
static func new_warnings(previous: PackedStringArray, current: PackedStringArray) -> PackedStringArray:
	var counts := RegEx.create_from_string(" \\(\\d+\\)")
	var known := {}
	for line in previous:
		for part in counts.sub(line, "", true).split(", "):
			known[part] = true
	var added := PackedStringArray()
	for line in current:
		var parts := counts.sub(line, "", true).split(", ")
		if Array(parts).any(func(part: String) -> bool: return not known.has(part)):
			added.append(line)
	return added


## One line per kind of problem.
func report() -> PackedStringArray:
	var lines := PackedStringArray()
	if not _materials.missing_textures.is_empty():
		lines.append("missing textures: " + ", ".join(_materials.missing_textures))
	if not _unmapped.is_empty():
		var counts := PackedStringArray()
		for classname in _unmapped:
			counts.append("%s (%d)" % [classname, _unmapped[classname]])
		lines.append("point entities without an entity class, placeholders only: " + ", ".join(counts))
	if not _missing_fog_styles.is_empty():
		lines.append("ground fog styles not found, default used: " + ", ".join(_missing_fog_styles.keys()))
	if not _low_fogs.is_empty():
		lines.append("ground fog boxes lower than their fog with its hills, its top is cut flat: " + ", ".join(_low_fogs))
	lines.append_array(_dangling_targets)
	return lines


func _build_entity(entity: Dictionary, index: int) -> Node3D:
	var classname: String = entity.classname
	var entity_class := entity_classes.find(classname) if entity_classes else null
	if not entity_class and entity.geometry < 0 and not classname.begins_with("light"):
		_unmapped[classname] = _unmapped.get(classname, 0) + 1
	if entity_class and entity_class.exclude:
		return null

	var geometry: int = entity.geometry
	var node := _create_node(entity_class, entity)
	node.name = "%s_%d" % [classname, index]
	node.set_meta(ENTITY_META, entity)
	node.add_to_group(classname, true)
	QuakeEntity.apply_keys(node)

	if geometry >= 0:
		node.position = _level.get_geometry_pivot(geometry)
		if node is QuakeGroundFog:
			# the brush is only the fog's box
			node.fit(_brush_bounds(geometry))
			_pick_fog_style(node)
		else:
			# Quake's InitTrigger hides triggers whatever their texture
			_add_geometry(node, geometry, not _is_volume(classname), is_world(classname))
	else:
		node.position = entity.origin
		node.rotation_degrees = _rotation_from_angles(entity.angles)
	return node


func _create_node(entity_class: QuakeEntityClass, entity: Dictionary) -> Node3D:
	var classname: String = entity.classname
	if entity_class and entity_class.scene:
		return entity_class.scene.instantiate()
	if entity_class and entity_class.node_script:
		return entity_class.node_script.new()
	var targetname: String = entity.properties.get("targetname", "")
	if classname.begins_with("light") and _switchable_styles.has(targetname):
		var light := QuakeSwitchableLight.new()
		light.style = _switchable_styles[targetname]
		return light
	if entity.geometry < 0:
		return Marker3D.new()
	if _is_volume(classname):
		return Area3D.new()
	if classname == "func_illusionary":
		return Node3D.new()
	if classname == QuakeGroundFog.CLASSNAME:
		return QuakeGroundFog.new()
	return StaticBody3D.new()


static func _is_volume(classname: String) -> bool:
	return classname.begins_with("trigger_") or classname == QuakeBuiltinEntities.LADDER


## Part of the world as in the light tools: they block light and are not offset.
static func is_world(classname: String) -> bool:
	return classname in ["worldspawn", "func_group"] or classname.begins_with("func_detail")


## Without a style key the fog follows the default style.
func _pick_fog_style(fog: QuakeGroundFog) -> void:
	var style_name := QuakeEntity.get_string(fog, "style")
	if not style_name.is_empty() and style_name != QuakeGroundFogStyle.DEFAULT:
		fog.style = QuakeGroundFogStyle.find(style_name, _fog_style_directories)
		if not fog.style:
			_missing_fog_styles[style_name] = true
	var looks := fog.style if fog.style else QuakeGroundFogStyle.find(QuakeGroundFogStyle.DEFAULT,
			_fog_style_directories)
	if looks and fog.size.y < looks.top():
		_low_fogs.append("%s (%.2f m of %.2f m)" % [fog.name, fog.size.y, looks.top()])


## From the hulls, tool textures leave no faces.
func _brush_bounds(geometry: int) -> AABB:
	var points := PackedVector3Array()
	for hull: Dictionary in _level.get_geometry_hulls(geometry):
		points.append_array(hull.points)
	if points.is_empty():
		return _level.get_geometry_mesh(geometry).get_aabb()
	var bounds := AABB(points[0], Vector3.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


func _add_geometry(node: Node3D, geometry: int, drawn: bool, world: bool) -> void:
	var mesh := _level.get_geometry_mesh(geometry)
	if drawn and mesh.get_surface_count() > 0:
		for surface in mesh.get_surface_count():
			mesh.surface_set_material(surface, _materials.get_material(mesh.surface_get_name(surface)))
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		mesh_instance.mesh = mesh
		if not world:
			# Quake's -x, -y, -z
			mesh_instance.position = Vector3(-1.0, -1.0, 1.0) * BRUSH_ENTITY_OFFSET / _level.get_units_per_meter()
		node.add_child(mesh_instance)

	var hulls := _level.get_geometry_hulls(geometry)
	var trigger := node is Area3D
	if hulls.is_empty() and node is CollisionObject3D and mesh.get_surface_count() > 0:
		node.add_child(_tinted(_face_collision(mesh), TRIGGER_COLOR if trigger else _hull_color()))
	for index in hulls.size():
		var hull: Dictionary = hulls[index]
		var shape := CollisionShape3D.new()
		shape.name = "Hull_%d" % index
		shape.shape = ConvexPolygonShape3D.new()
		shape.shape.points = hull.points
		if hull.type == QuakeLevel.HULL_LIQUID:
			node.add_child(_create_liquid(hull.texture, _tinted(shape, LIQUID_COLOR), index))
		elif node is CollisionObject3D:
			node.add_child(_tinted(shape, TRIGGER_COLOR if trigger else _hull_color()))


func _hull_color() -> Color:
	return ProjectSettings.get_setting("debug/shapes/collision/shape_color") if show_hulls else HIDDEN


static func _tinted(shape: CollisionShape3D, color: Color) -> CollisionShape3D:
	shape.debug_color = color
	shape.debug_fill = color != HIDDEN
	return shape


## A bsp keeps no brushes, so its faces collide. Liquids stay walkable.
static func _face_collision(mesh: ArrayMesh) -> CollisionShape3D:
	var faces := PackedVector3Array()
	for surface in mesh.get_surface_count():
		if QuakeLiquids.is_liquid(mesh.surface_get_name(surface)):
			continue
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for index: int in arrays[Mesh.ARRAY_INDEX]:
			faces.append(vertices[index])
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collision := CollisionShape3D.new()
	collision.name = "Faces"
	collision.shape = shape
	return collision


func _create_liquid(texture_name: String, shape: CollisionShape3D, index: int) -> Area3D:
	var kind := QuakeLiquids.kind_of(texture_name)
	var area := Area3D.new()
	area.name = "Liquid_%d" % index
	area.monitoring = false
	if kind != "teleport":
		area.add_to_group(QuakeLiquids.GROUP, true)
	area.set_meta(QuakeLiquids.KIND_META, kind)
	area.set_meta(QuakeLiquids.COLOR_META, _materials.liquid_color(texture_name))
	area.add_child(shape)
	return area


func _report_targets(entities: Array[Dictionary]) -> void:
	var names := {}
	for entity in entities:
		names[entity.properties.get("targetname", "")] = true
	for entity in entities:
		var target: String = entity.properties.get("target", "")
		if not target.is_empty() and not names.has(target):
			_dangling_targets.append("%s targets \"%s\", no entity has that targetname" % [entity.classname, target])


## By targetname, numbered from 32 in order of appearance like libquake's QuakeLightsFromEntities.
static func _switchable_light_styles(entities: Array[Dictionary]) -> Dictionary:
	var styles := {}
	for entity in entities:
		var properties: Dictionary = entity.properties
		var targetname: String = properties.get("targetname", "")
		if entity.classname.begins_with("light") and str(properties.get("style", "0")).to_int() == 0 \
				and not targetname.is_empty() and not styles.has(targetname):
			styles[targetname] = 32 + styles.size()
	return styles


## Pitch (positive looks down), yaw, roll. Yaw 0 looks along Quake's +x.
static func _rotation_from_angles(angles: Vector3) -> Vector3:
	return Vector3(-angles.x, angles.y - 90.0, angles.z)


static func _set_owner(node: Node, owner: Node) -> void:
	node.owner = owner
	if not node.scene_file_path.is_empty():
		return
	for child in node.get_children():
		_set_owner(child, owner)
