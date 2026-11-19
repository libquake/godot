@tool
class_name QuakeLightmap
extends Node3D
## Bakes Quake-style light for the static meshes below its parent, like LightmapGI. Meshes need gi_mode Static
## and UV2, CSG shapes get UV2. Surfaces with a Quake world material or a StandardMaterial3D get the lightmap,
## others only cast shadows. The result is saved next to the scene and applied on load.

const RECT_PARAMETER := &"lightmap_rect"
## On a baked material: its source.
const SOURCE_META := &"quake_lightmap_source"
## On a mesh node, a node above it or a Mesh: the mesh is level geometry and baked like the maps, with
## luxel_size and their full ambient occlusion, so it blends in. Pieces imported from maps carry it.
const LEVEL_META := &"quake_level_geometry"
## On a mesh node, a node above it or a Mesh: scales the maps' _dirtdepth there, 0 is no ambient occlusion.
## Wins over mesh_dirt_depth_scale and LEVEL_META.
const DIRT_META := &"quake_dirt_depth_scale"

## Clear to remove the bake.
@export var data: QuakeLightmapData:
	set(value):
		data = value
		if is_node_ready():
			_apply()
## Bakes again in the editor once the scene is unchanged for auto_bake_delay.
@export var auto_bake := false
@export_range(0.5, 30.0, 0.5, "suffix:s") var auto_bake_delay := 3.0

@export_group("Lights")
## Light3D nodes with light_bake_mode Static.
@export var godot_lights := true
## The light entities of imported maps.
@export var quake_lights := true
## Sun, sky dome, _minlight, _anglescale and _range.
@export var worldspawn := true
## Quake light value of energy 1.
@export var light_intensity := 300.0
## Added everywhere, 1 is normal brightness.
@export var ambient_light := Color.BLACK
## Like _minlight, 1 is normal brightness.
@export_range(0.0, 2.0, 0.01) var minimum_light := 0.0

@export_group("Lightmap")
## On the brushes of imported maps.
@export var luxel_size := 16.0
## On other meshes, scaled by their gi_lightmap_texel_scale.
@export var mesh_luxel_size := 2.0
## Scales the maps' _dirtdepth on other meshes. 0, no ambient occlusion, as the Quake tools treat models;
## -1 scales it like mesh_luxel_size to luxel_size, the depth that suits a map darkens a small model all over.
@export_range(-1.0, 1.0, 0.01) var mesh_dirt_depth_scale := 0.0
## Without maps; otherwise the first map's scale counts.
@export var units_per_meter := 32.0
## Meters between the points that light models, 0 is none.
@export var light_grid_cell_size := 1.0

@export_group("Quality")
## Samples per luxel along each side, 2 or 4 for smoother shadow edges in a final bake. Costs 4 or 16 times.
@export_range(1, 4) var luxel_samples := 1
## Ambient occlusion: -1 as the maps' _dirt says, 0 none, 1 everywhere.
@export_range(-1, 1) var dirt := -1
## Strength of the ambient occlusion, -1 as the maps' _dirtscale says.
@export_range(-1.0, 2.0, 0.05) var dirt_scale := -1.0
## Rays per sample for ambient occlusion, fewer bake faster.
@export_range(12, 192) var dirt_samples := 48
## Suns per sky dome (_sunlight2, _sunlight3), fewer bake faster.
@export_range(8, 2048) var sky_samples := 64
## Times light bounces off surfaces, -1 as the maps' _bounce says.
@export_range(-1, 4) var bounces := -1
## Brightness of the bounced light, -1 as the maps' _bouncescale says. Lower it for maps lit without bounce.
@export_range(-1.0, 2.0, 0.05) var bounce_scale := -1.0
## Map units per patch that bounces light, larger bake faster.
@export_range(16, 512) var bounce_subdivision := 64.0

var _applied: Array[Dictionary] = []
var _switched_off_lights: Array[Light3D] = []
var _replaced_grids: Array[QuakeLightGrid] = []
var _grid: QuakeLightGrid
var _paused_styles: Array[QuakeLightStyles] = []
var _styles: QuakeLightStyles
var _materials: Dictionary[Material, Material] = {}
var _surface_colors: Dictionary[Material, Color] = {}
var _bake_thread: Thread


func _ready() -> void:
	_apply()


## Deferred, add_child() is blocked during tree notifications.
func _enter_tree() -> void:
	if is_node_ready():
		_apply.call_deferred()


func _exit_tree() -> void:
	if _bake_thread:
		_bake_thread.wait_to_finish()
		_bake_thread = null
	_revert()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_revert()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_apply.call_deferred()


func is_baking() -> bool:
	return _bake_thread != null


## Saves next to the scene, returns the path or "". Runs in a thread: await it.
func bake() -> String:
	var scene_path := owner.scene_file_path if owner else scene_file_path
	if scene_path.is_empty():
		push_error("QuakeLightmap: save the scene before baking.")
		return ""
	# not data's path: a copied scene still refers to the original's file
	var path := scene_path.get_basename() + ".lightmap.res"
	return path if await bake_to(path) else ""


## Also in the game. A path saves it there, user:// in an exported game. Returns whether it worked, await it.
func bake_to(path := "") -> bool:
	if is_baking():
		return false

	var baker := QuakeLightBaker.new()
	_surface_colors.clear()
	baker.units_per_meter = _units_per_meter()
	baker.luxel_size = luxel_size
	baker.minimum_light = minimum_light
	baker.ambient_light = ambient_light
	baker.sky_samples = sky_samples
	baker.bounces = bounces
	baker.bounce_subdivision = bounce_subdivision
	baker.bounce_scale = bounce_scale
	baker.luxel_samples = luxel_samples
	baker.dirt = dirt
	baker.dirt_scale = dirt_scale
	baker.dirt_samples = dirt_samples
	var result := QuakeLightmapData.new()
	var groups := {}
	for source in _static_geometry():
		var node: GeometryInstance3D = source.node
		var key: Variant = _atlas_key(source)
		var level: bool = key is Array or _model_meta(source, LEVEL_META, false)
		var texel_scale := node.gi_lightmap_texel_scale
		if not level:
			texel_scale *= luxel_size / mesh_luxel_size
		var group: Dictionary = groups.get_or_add(key, {
			"vertices": PackedVector3Array(), "normals": PackedVector3Array(), "uv2": PackedVector2Array(),
			"indices": PackedInt32Array(), "colors": PackedColorArray(), "nodes": [], "texel_scale": texel_scale,
			"dirt_depth_scale": 1.0 if key is Array else _dirt_depth_scale(source, level),
			# maps and their pieces share an atlas laid out by libquake, only models bring a UV2 of their own
			"own_uv2": not level,
		})
		if _add_mesh(baker, source, group):
			group.nodes.append(node)
			if node is CSGShape3D:
				result.csg_meshes[get_path_to(node)] = source.mesh
	var surfaces: Array[int] = []
	for group: Dictionary in groups.values():
		if group.indices.is_empty():
			continue
		var surface := baker.add_surface(group.vertices, group.normals, group.uv2, group.indices, group.texel_scale,
				group.colors, group.dirt_depth_scale)
		for node: Node in group.nodes:
			surfaces.append(surface)
			result.meshes.append(get_path_to(node))
	if godot_lights:
		for light in _static_lights():
			_add_light(baker, light)
			result.lights.append(get_path_to(light))
	if quake_lights or worldspawn:
		for map in _maps():
			baker.add_quake_entities(_entities(map), _to_local(map), quake_lights, worldspawn)

	var tree := get_tree()
	_bake_thread = Thread.new()
	_bake_thread.start(baker.bake)
	while _bake_thread and _bake_thread.is_alive():
		await tree.process_frame
	# null when the node left the tree meanwhile
	if not _bake_thread:
		return false
	var error: Error = _bake_thread.wait_to_finish()
	_bake_thread = null
	if error != OK:
		return false
	result.texture = ImageTexture.create_from_image(baker.get_lightmap_image())
	result.layers = baker.get_lightmap_layers()
	for surface in surfaces:
		result.uv_transforms.append(baker.get_surface_uv_transform(surface))
	if light_grid_cell_size > 0.0:
		var grid := baker.build_light_grid(light_grid_cell_size)
		result.grid_origin = grid.origin
		result.grid_cell_size = grid.cell_size
		result.grid_size = grid.size
		result.grid_rgb = grid.rgb

	if not path.is_empty():
		# keeps the uid the scene refers to
		var uid := ResourceLoader.get_resource_uid(path) if ResourceLoader.exists(path) else ResourceUID.INVALID_ID
		error = ResourceSaver.save(result, path)
		if error != OK:
			push_error("QuakeLightmap: could not save %s." % path)
			return false
		if uid != ResourceUID.INVALID_ID:
			ResourceSaver.set_uid(path, uid)
		result.take_over_path(path)
	data = result
	print("QuakeLightmap: %d meshes, %dx%d texels in %.2f s." % [
		surfaces.size(), result.texture.get_width(), result.texture.get_height(),
		baker.get_bake_milliseconds() / 1000.0])
	return true


func _apply() -> void:
	_revert()
	if not data or not data.texture or not is_inside_tree():
		return
	for index in mini(data.meshes.size(), data.uv_transforms.size()):
		var node := get_node_or_null(data.meshes[index])
		if node is CSGShape3D and data.csg_meshes.has(data.meshes[index]):
			_apply_csg(node, data.csg_meshes[data.meshes[index]], data.uv_transforms[index])
		elif node is MeshInstance3D and node.mesh:
			_apply_mesh(node, data.uv_transforms[index])
	# on the rendering server only, the node keeps its cull mask
	for path in data.lights:
		var light := get_node_or_null(path) as Light3D
		if light:
			RenderingServer.light_set_cull_mask(light.get_base(), 0)
			_switched_off_lights.append(light)
	if data.grid_cell_size > 0.0:
		_replace_grids()
	_replace_light_styles()


func _revert() -> void:
	for applied in _applied:
		# a reimported map frees its nodes, which fails a typed assignment
		var alive := is_instance_valid(applied.node)
		if applied.has("csg"):
			if is_instance_valid(applied.csg):
				var csg: CSGShape3D = applied.csg
				RenderingServer.instance_set_visible(csg.get_instance(), csg.is_visible_in_tree())
			if alive:
				applied.node.queue_free()
			continue
		if not alive:
			continue
		var mesh_instance: MeshInstance3D = applied.node
		# what was set on the baked materials goes back to their sources
		_source(mesh_instance.material_override)
		for surface in mesh_instance.get_surface_override_material_count():
			_source(mesh_instance.get_surface_override_material(surface))
		mesh_instance.material_override = applied.material_override
		var overrides: Array = applied.overrides
		for surface in mini(overrides.size(), mesh_instance.get_surface_override_material_count()):
			mesh_instance.set_surface_override_material(surface, overrides[surface])
		mesh_instance.set_instance_shader_parameter(RECT_PARAMETER, null)
	_applied.clear()
	for light in _switched_off_lights:
		if is_instance_valid(light):
			RenderingServer.light_set_cull_mask(light.get_base(), light.light_cull_mask)
	_switched_off_lights.clear()
	for grid in _replaced_grids:
		if is_instance_valid(grid):
			grid.add_to_group(QuakeLightGrid.GROUP, true)
	_replaced_grids.clear()
	if _grid:
		_grid.queue_free()
		_grid = null
	for styles in _paused_styles:
		if is_instance_valid(styles):
			styles.process_mode = Node.PROCESS_MODE_INHERIT
	_paused_styles.clear()
	if _styles:
		_styles.queue_free()
		_styles = null
	_materials.clear()


func _apply_mesh(mesh_instance: MeshInstance3D, uv_transform: Vector4) -> void:
	var applied := {
		"node": mesh_instance,
		"material_override": _source(mesh_instance.material_override),
		"overrides": [],
	}
	if mesh_instance.material_override:
		mesh_instance.material_override = _baked_material(applied.material_override)
	for surface in mesh_instance.get_surface_override_material_count():
		var current := _source(mesh_instance.get_surface_override_material(surface))
		if current == mesh_instance.mesh.surface_get_material(surface):
			current = null
		applied.overrides.append(current)
		var baked := _baked_material(_source(mesh_instance.get_active_material(surface)))
		if baked:
			mesh_instance.set_surface_override_material(surface, baked)
	mesh_instance.set_instance_shader_parameter(RECT_PARAMETER, uv_transform)
	_applied.append(applied)


## CSG meshes lack UV2, so the baked copy is drawn instead. Only the shape's own drawing is hidden.
func _apply_csg(csg: CSGShape3D, mesh: Mesh, uv_transform: Vector4) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = csg.material_override
	mesh_instance.cast_shadow = csg.cast_shadow
	mesh_instance.layers = csg.layers
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	csg.add_child(mesh_instance, false, INTERNAL_MODE_BACK)
	RenderingServer.instance_set_visible(csg.get_instance(), false)
	_apply_mesh(mesh_instance, uv_transform)
	_applied.back().csg = csg


## Models read the baked light instead of the light grids of the maps in the bake.
func _replace_grids() -> void:
	for grid: QuakeLightGrid in get_tree().get_nodes_in_group(QuakeLightGrid.GROUP):
		if _scope().is_ancestor_of(grid):
			grid.remove_from_group(QuakeLightGrid.GROUP)
			_replaced_grids.append(grid)
	_grid = QuakeLightGrid.new()
	_grid.name = "LightGrid"
	_grid.origin = data.grid_origin
	_grid.cell_size = data.grid_cell_size
	_grid.size = data.grid_size
	_grid.rgb = data.grid_rgb
	add_child(_grid, false, INTERNAL_MODE_BACK)
	_grid.add_to_group(QuakeLightGrid.GROUP)


## The bake's light styles replace the maps' own, in the game only.
func _replace_light_styles() -> void:
	if Engine.is_editor_hint():
		return
	# not set_process(): a map's _ready() would switch it back on
	for styles: QuakeLightStyles in get_tree().get_nodes_in_group(QuakeLightStyles.GROUP):
		if _scope().is_ancestor_of(styles):
			styles.process_mode = Node.PROCESS_MODE_DISABLED
			_paused_styles.append(styles)
	if data.layers.is_empty():
		return
	_styles = QuakeLightStyles.create(data.texture as ImageTexture, data.layers)
	add_child(_styles, false, INTERNAL_MODE_BACK)


## Null for materials that take no lightmap.
func _baked_material(source: Material) -> Material:
	if not source:
		return null
	if _materials.has(source):
		return _materials[source]
	var baked: ShaderMaterial = null
	if source is ShaderMaterial and source.shader == QuakeMaterials.WORLD_SHADER:
		baked = source.duplicate()
	elif source is BaseMaterial3D:
		baked = _world_material(source)
	if baked:
		baked.set_shader_parameter(&"lightmap_texture", data.texture)
		baked.set_meta(SOURCE_META, source)
	_materials[source] = baked
	return baked


## Duplicated nodes copy the baked material as a real override. A color or texture set on the baked material
## goes back to its source, the inspector shows the baked one and a new bake would lose it otherwise.
static func _source(material: Material) -> Material:
	if not material or not material.has_meta(SOURCE_META):
		return material
	var source: Material = material.get_meta(SOURCE_META)
	var color: Variant = _albedo_color(material)
	var texture: Variant = material.get_shader_parameter(&"albedo_texture")
	if source is BaseMaterial3D:
		if color is Color and color != source.albedo_color:
			source.albedo_color = color
		if texture != source.albedo_texture:
			source.albedo_texture = texture
	elif source is ShaderMaterial:
		if color is Color and color != _albedo_color(source):
			source.set_shader_parameter(&"albedo_color", color)
		if texture != source.get_shader_parameter(&"albedo_texture"):
			source.set_shader_parameter(&"albedo_texture", texture)
	return source


## The albedo_color of a shader material, null when it has none. A vec4 uniform comes back as Color or
## Vector4, depending on how it was set.
static func _albedo_color(material: ShaderMaterial) -> Variant:
	var value: Variant = material.get_shader_parameter(&"albedo_color")
	if value is Vector4:
		return Color(value.x, value.y, value.z, value.w)
	return value if value is Color else null


## Takes textures, colors and tiling of a StandardMaterial3D.
static func _world_material(source: BaseMaterial3D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = QuakeMaterials.WORLD_SHADER
	material.set_shader_parameter(&"albedo_texture", source.albedo_texture)
	material.set_shader_parameter(&"albedo_color", source.albedo_color)
	material.set_shader_parameter(&"uv_scale", Vector2(source.uv1_scale.x, source.uv1_scale.y))
	material.set_shader_parameter(&"uv_offset", Vector2(source.uv1_offset.x, source.uv1_offset.y))
	if source.emission_enabled:
		material.set_shader_parameter(&"emission_texture", source.emission_texture)
		material.set_shader_parameter(&"fullbright_energy", source.emission_energy_multiplier)
	return material


## True if the source had lit surfaces. Other surfaces but liquids only block light.
func _add_mesh(baker: QuakeLightBaker, source: Dictionary, group: Dictionary) -> bool:
	var node: GeometryInstance3D = source.node
	var mesh: Mesh = source.mesh
	var transform := _to_local(node)
	var normal_basis := transform.basis.inverse().transposed()
	var casts_shadow := node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and _entity_casts_shadow(node)
	var lit := false
	for surface in mesh.get_surface_count():
		var material: Material = source.materials[surface]
		if material is ShaderMaterial and material.shader == QuakeMaterials.LIQUID_SHADER:
			continue
		var arrays := mesh.surface_get_arrays(surface)
		var surface_vertices := transform * (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
		var surface_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] \
				else PackedInt32Array(range(surface_vertices.size()))
		var sky: bool = material is ShaderMaterial and material.shader == QuakeMaterials.SKY_SHADER
		if casts_shadow or sky:
			baker.add_occluder(surface_vertices, surface_indices, sky)
		if sky or not _takes_lightmap(material) or not arrays[Mesh.ARRAY_TEX_UV2] or not arrays[Mesh.ARRAY_NORMAL]:
			continue
		var problem := uv2_problem(arrays[Mesh.ARRAY_TEX_UV2], surface_indices) if group.own_uv2 else ""
		if problem:
			push_warning("QuakeLightmap: %s, surface %d: its UV2 %s, the baked light on it will be wrong. Import it with "
					% [_scope().get_path_to(node), surface, problem] + "Light Baking set to Static Lightmaps.")
		var offset: int = group.vertices.size()
		group.vertices.append_array(surface_vertices)
		for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
			group.normals.append((normal_basis * normal).normalized())
		group.uv2.append_array(arrays[Mesh.ARRAY_TEX_UV2])
		for index in surface_indices:
			group.indices.append(index + offset)
		var color := _surface_color(material)
		for corner in range(0, surface_indices.size(), 3):
			group.colors.append(color)
		lit = true
	return lit


## DIRT_META, else the maps' depth for level geometry, else mesh_dirt_depth_scale.
func _dirt_depth_scale(source: Dictionary, level: bool) -> float:
	var meta: Variant = _model_meta(source, DIRT_META, null)
	if meta != null:
		return meta
	if level:
		return 1.0
	return mesh_dirt_depth_scale if mesh_dirt_depth_scale >= 0.0 else mesh_luxel_size / luxel_size


## A meta on the mesh node or a node above it, up to this node's scope, then on its mesh.
func _model_meta(source: Dictionary, name: StringName, default: Variant) -> Variant:
	var node: Node = source.node
	while node:
		if node.has_meta(name):
			return node.get_meta(name)
		if node == _scope():
			break
		node = node.get_parent()
	var mesh: Mesh = source.mesh
	return mesh.get_meta(name) if mesh and mesh.has_meta(name) else default


## Why a model's UV2 can not hold a lightmap, empty if it can. UV sets from elsewhere often reach past 0..1,
## leave the space they span nearly empty, so the mesh gets few texels, or lay parts over each other. The baker
## gives the space a UV2 spans the size its density asks for, how much of 0..1 it uses does not matter.
static func uv2_problem(uv2: PackedVector2Array, indices: PackedInt32Array) -> String:
	var low := Vector2(INF, INF)
	var high := -low
	for uv in uv2:
		if uv.x < -0.01 or uv.y < -0.01 or uv.x > 1.01 or uv.y > 1.01:
			return "reaches outside 0..1"
		low = low.min(uv)
		high = high.max(uv)
	var span := (high - low).x * (high - low).y
	if span <= 0.0:
		return ""
	var area := 0.0
	for i in range(0, indices.size() - 2, 3):
		var a := uv2[indices[i]]
		area += absf((uv2[indices[i + 1]] - a).cross(uv2[indices[i + 2]] - a)) * 0.5
	if area < 0.05 * span:
		return "covers only %d%% of the space it spans" % maxi(1, roundi(area / span * 100.0))
	if area > 1.01 * span:
		return "lays parts over each other"
	return ""


## The average color of a material's albedo, what bounced light takes on.
func _surface_color(material: Material) -> Color:
	if _surface_colors.has(material):
		return _surface_colors[material]
	var color := Color(0.5, 0.5, 0.5)
	var texture: Texture2D
	var albedo := Color.WHITE
	if material is BaseMaterial3D:
		texture = material.albedo_texture
		albedo = material.albedo_color
	elif material is ShaderMaterial and material.shader == QuakeMaterials.WORLD_SHADER:
		texture = material.get_shader_parameter(&"albedo_texture")
		var parameter: Variant = _albedo_color(material)
		if parameter != null:
			albedo = parameter
	if material is BaseMaterial3D or texture:
		color = (QuakeMaterials.average_color(texture) if texture else Color.WHITE) * albedo
	_surface_colors[material] = color
	return color


## A map's meshes share its layout and bake as one, other meshes get their own place.
func _atlas_key(source: Dictionary) -> Variant:
	var map := QuakeMap.of(source.node)
	if map:
		for material: Material in source.materials:
			if material is ShaderMaterial and material.shader == QuakeMaterials.WORLD_SHADER:
				var lightmap: Texture2D = material.get_shader_parameter(&"lightmap_texture")
				if lightmap:
					return [map, lightmap]
	return source.node


func _add_light(baker: QuakeLightBaker, light: Light3D) -> void:
	var transform := _to_local(light)
	var direction := -transform.basis.z
	var intensity := light.light_energy * light_intensity
	var shadows := light.shadow_enabled
	if light is OmniLight3D:
		baker.add_light(QuakeLightBaker.LIGHT_POINT, transform.origin, direction, light.light_color, intensity,
				light.omni_range, 0.0, shadows)
	elif light is SpotLight3D:
		baker.add_light(QuakeLightBaker.LIGHT_SPOT, transform.origin, direction, light.light_color, intensity,
				light.spot_range, light.spot_angle * 2.0, shadows)
	elif light is DirectionalLight3D:
		baker.add_light(QuakeLightBaker.LIGHT_SUN, transform.origin, direction, light.light_color, intensity,
				0.0, 0.0, shadows)


static func _takes_lightmap(material: Material) -> bool:
	return material is BaseMaterial3D or (material is ShaderMaterial and material.shader == QuakeMaterials.WORLD_SHADER)


func _scope() -> Node:
	return get_parent() if get_parent() else self


## Node, mesh and surface materials of everything baked.
func _static_geometry() -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	for node in _scope().find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if not geometry.is_visible_in_tree() or geometry.gi_mode != GeometryInstance3D.GI_MODE_STATIC:
			continue
		if _moves(geometry):
			continue
		if geometry is MeshInstance3D and geometry.mesh:
			var materials: Array[Material] = []
			for surface in geometry.mesh.get_surface_count():
				materials.append(_source(geometry.get_active_material(surface)))
			sources.append({"node": geometry, "mesh": geometry.mesh, "materials": materials})
		elif geometry is CSGShape3D and geometry.is_root_shape():
			var mesh := _unwrapped_csg_mesh(geometry)
			if mesh:
				var materials: Array[Material] = []
				for surface in mesh.get_surface_count():
					materials.append(_source(geometry.material_override) if geometry.material_override \
							else mesh.surface_get_material(surface))
				sources.append({"node": geometry, "mesh": mesh, "materials": materials})
	return sources


## As in ericw-tools, only the world and its groups block light, other brush entities with "_shadow" "1".
func _entity_casts_shadow(node: Node) -> bool:
	var parent := node
	while parent and parent != _scope():
		if parent.has_meta(QuakeSceneBuilder.ENTITY_META):
			var classname: String = parent.get_meta(QuakeSceneBuilder.ENTITY_META).get("classname", "")
			return QuakeSceneBuilder.is_world(classname) or QuakeEntity.get_int(parent, "_shadow") != 0
		parent = parent.get_parent()
	return true


## Static is only Godot's default below moving bodies. Doors (AnimatableBody3D) stay in, as in Quake.
func _moves(node: Node) -> bool:
	var parent := node.get_parent()
	while parent and parent != _scope():
		if parent is RigidBody3D or parent is CharacterBody3D:
			return true
		parent = parent.get_parent()
	return false


func _unwrapped_csg_mesh(csg: CSGShape3D) -> ArrayMesh:
	var meshes := csg.get_meshes()
	if meshes.size() < 2 or not meshes[1] is ArrayMesh:
		return null
	var mesh: ArrayMesh = meshes[1].duplicate()
	if mesh.lightmap_unwrap(csg.global_transform, mesh_luxel_size / _units_per_meter()) != OK:
		push_warning("QuakeLightmap: could not unwrap %s." % csg.name)
		return null
	return mesh


func _static_lights() -> Array[Light3D]:
	var lights: Array[Light3D] = []
	for node in _scope().find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light.is_visible_in_tree() and light.light_bake_mode == Light3D.BAKE_STATIC:
			lights.append(light)
	return lights


func _units_per_meter() -> float:
	var maps := _maps()
	return maps[0].units_per_meter if not maps.is_empty() else units_per_meter


func _maps() -> Array[QuakeMap]:
	var maps: Array[QuakeMap] = []
	for node in _scope().find_children("*", "Node3D", true, false):
		if node is QuakeMap:
			maps.append(node)
	return maps


static func _entities(map: QuakeMap) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	for node in map.find_children("*", "", true, false):
		if node.has_meta(QuakeSceneBuilder.ENTITY_META):
			entities.append(node.get_meta(QuakeSceneBuilder.ENTITY_META))
	return entities


func _to_local(node: Node3D) -> Transform3D:
	return global_transform.affine_inverse() * node.global_transform
