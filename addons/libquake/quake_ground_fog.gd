@tool
class_name QuakeGroundFog
extends Node3D
## Fog lying on the floor of a box: its top rolls in hills, it fades out toward the box's sides and stays where
## it was put. What stands in the box pokes out of the fog. A func_groundfog becomes one the size of its brush;
## placed in a scene, size sets the box. The box is centered on the node and turns with it. Its look is a
## QuakeGroundFogStyle.

const CLASSNAME := "func_groundfog"
const SHADER := preload("shaders/quake_ground_fog.gdshader")
## Drop to Floor sinks the box this far into the floor, so no gap shows under the fog.
const FLOOR_SINK := 0.02
## A box floor this far above the floor under it floats.
const FLOAT_TOLERANCE := 0.1
const FLOOR_SEARCH := 100.0

## The box in meters, a bit taller than the fog with its hills. A func_groundfog takes its brush's.
@export var size := Vector3(8.0, 2.0, 8.0):
	set(value):
		size = value.max(Vector3.ONE * 0.1)
		_update_box()
		update_gizmos()
		update_configuration_warnings()
## The look, shared with every fog using the same style. Empty looks like the style named default.
@export var style: QuakeGroundFogStyle:
	set(value):
		style = value
		_use_style()
## Puts the box's floor on the lowest floor under it.
@export_tool_button("Drop to Floor", "ArrowDown") var drop_to_floor := _drop_to_floor

var _mesh: MeshInstance3D
var _material: ShaderMaterial
## The style the shader has: style, or the default one.
var _active_style: QuakeGroundFogStyle


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_mesh = MeshInstance3D.new()
	_mesh.name = "FogBox"
	_mesh.mesh = BoxMesh.new()
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# a QuakeLightmap above leaves it out
	_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# internal and without an owner: never saved, not in the scene tree dock
	add_child(_mesh, false, Node.INTERNAL_MODE_BACK)
	_use_style()
	_update_box()
	if Engine.is_editor_hint():
		set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var active := style_in_use()
	if active and size.y < active.top():
		warnings.append("The box is %.2f m high, the fog with its hills reaches %.2f m: its top is cut flat."
				% [size.y, active.top()])
	# it rests when any of the rays finds floor at its own; a lower one may be a neighbouring area
	var floors := _floors_below()
	if not floors.is_empty():
		var gap: float = _box_floor() - Array(floors).max()
		if gap > FLOAT_TOLERANCE:
			warnings.append("The box floats %.2f m above the floor under it, and the fog with it. Drop to Floor puts it down."
					% gap)
	return warnings


## The style the fog looks like: its own or the default one.
func style_in_use() -> QuakeGroundFogStyle:
	if _active_style:
		return _active_style
	return style if style else QuakeGroundFogStyle.find(QuakeGroundFogStyle.DEFAULT)


## The height of the floor under the box's middle, where Drop to Floor puts it; -INF without one.
func floor_below() -> float:
	if not is_inside_tree():
		return -INF
	return _floor_at(Vector2.ZERO)


## The floors under the box's middle and halfway to its corners, those the rays found.
func _floors_below() -> PackedFloat32Array:
	var floors := PackedFloat32Array()
	if not is_inside_tree():
		return floors
	for offset in [Vector2.ZERO, Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var height := _floor_at(offset * 0.25)
		if height != -INF:
			floors.append(height)
	return floors


## A ray from the box's middle height down to collision, at offset times the box's size from its middle.
func _floor_at(offset: Vector2) -> float:
	var from := global_transform * Vector3(offset.x * size.x, 0.0, offset.y * size.z)
	var to := from + Vector3.DOWN * (size.y * 0.5 + FLOOR_SEARCH)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	return hit.position.y if not hit.is_empty() else -INF


## Makes the box the brush's bounds, given in the node's space: the node moves to their center.
func fit(bounds: AABB) -> void:
	position += bounds.get_center()
	size = bounds.size


## Follows the style's changes, so editing it shows on every fog using it at once.
func _use_style() -> void:
	if not _material:
		return
	var active := style if style else QuakeGroundFogStyle.find(QuakeGroundFogStyle.DEFAULT)
	if active != _active_style:
		if _active_style:
			_active_style.changed.disconnect(_send_style)
		_active_style = active
		if _active_style:
			_active_style.changed.connect(_send_style)
	_send_style()


func _send_style() -> void:
	for param in QuakeGroundFogStyle.PARAMS:
		# null puts the shader's own default back
		_material.set_shader_parameter(param, _active_style.get(param) if _active_style else null)
	update_gizmos()
	update_configuration_warnings()


func _box_floor() -> float:
	return global_position.y - size.y * 0.5


func _drop_to_floor() -> void:
	if has_meta(QuakeSceneBuilder.ENTITY_META):
		push_warning("%s: the brush in the map sets the box of a func_groundfog." % name)
		return
	var floor_y := floor_below()
	if floor_y == -INF:
		push_warning("%s: no collision under the box to drop to." % name)
		return
	var target := global_position + Vector3.UP * (floor_y - FLOOR_SINK - _box_floor())
	var parent := get_parent_node_3d()
	var new_position := parent.global_transform.affine_inverse() * target if parent else target
	# a script of the game cannot name the editor's classes
	if not Engine.is_editor_hint():
		position = new_position
		return
	var undo_redo: Object = Engine.get_singleton(&"EditorInterface").get_editor_undo_redo()
	undo_redo.create_action("Drop Ground Fog to Floor")
	undo_redo.add_do_property(self, &"position", new_position)
	undo_redo.add_undo_property(self, &"position", position)
	undo_redo.commit_action()


func _update_box() -> void:
	if not _mesh:
		return
	(_mesh.mesh as BoxMesh).size = size
	_material.set_shader_parameter("half_size", size * 0.5)
