@tool
class_name QuakeGroundFogGizmo
extends EditorNode3DGizmoPlugin
## The box of a QuakeGroundFog and, lighter, the height its style's fog reaches before the hills. A fog of the
## open scene has a handle on every side: dragging one moves that side, the opposite one stays put. A fog of an
## imported map has none, its brush sets the box.

const BOX_EDGES := QuakeMapGizmo.BOX_EDGES
## Handle ids: +x, -x, +y, -y, +z, -z.
const SIDES := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
const MIN_SIZE := 0.1

var undo_redo: EditorUndoRedoManager


func _init() -> void:
	create_material("box", Color(0.75, 0.72, 0.65), false, true)
	create_material("fog_top", Color(0.75, 0.72, 0.65, 0.35), false, true)
	create_handle_material("handles")


func _get_gizmo_name() -> String:
	return "Quake Ground Fog"


func _has_gizmo(node: Node3D) -> bool:
	return node is QuakeGroundFog


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var fog := gizmo.get_node_3d() as QuakeGroundFog
	var box := AABB(fog.size * -0.5, fog.size)
	var lines := PackedVector3Array()
	for edge in BOX_EDGES:
		for corner in edge:
			lines.append(box.get_endpoint(corner))
	gizmo.add_lines(lines, get_material("box", gizmo))
	# selecting by the box's edges only, clicks inside reach what stands in the fog
	gizmo.add_collision_segments(lines)

	var style := fog.style_in_use()
	var top := minf(style.fog_height if style else 0.0, fog.size.y) - fog.size.y * 0.5
	var half := fog.size * 0.5
	var ring := PackedVector3Array()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]:
		ring.append(Vector3(corner.x * half.x, top, corner.y * half.z))
	var top_lines := PackedVector3Array()
	for index in 4:
		top_lines.append_array([ring[index], ring[index + 1]])
	gizmo.add_lines(top_lines, get_material("fog_top", gizmo))

	if _editable(fog):
		var handles := PackedVector3Array()
		for side: Vector3 in SIDES:
			handles.append(side * half)
		gizmo.add_handles(handles, get_material("handles", gizmo), [])


func _get_handle_name(_gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> String:
	return ["Right", "Left", "Top", "Bottom", "Back", "Front"][handle_id]


## The box before the drag: size, position and where the node was in the world.
func _get_handle_value(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool) -> Variant:
	var fog := gizmo.get_node_3d() as QuakeGroundFog
	return [fog.size, fog.position, fog.global_transform]


func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool, camera: Camera3D,
		screen_pos: Vector2) -> void:
	var fog := gizmo.get_node_3d() as QuakeGroundFog
	var start: Array = gizmo.get_meta(&"drag_start", [])
	if start.is_empty():
		start = _get_handle_value(gizmo, handle_id, false)
		gizmo.set_meta(&"drag_start", start)
	var start_size: Vector3 = start[0]
	var start_transform: Transform3D = start[2]
	# in the box's space at the start, along the dragged side's axis
	var to_box := start_transform.affine_inverse()
	var from: Vector3 = to_box * camera.project_ray_origin(screen_pos)
	var direction: Vector3 = to_box.basis * camera.project_ray_normal(screen_pos)
	var side: Vector3 = SIDES[handle_id]
	var points := Geometry3D.get_closest_points_between_segments(side * -4096.0, side * 4096.0, from,
			from + direction * 4096.0)
	var axis := handle_id >> 1
	var outward := side[axis]
	var fixed := -outward * start_size[axis] * 0.5
	var length := maxf(outward * (points[0][axis] - fixed), MIN_SIZE)
	var size := start_size
	size[axis] = length
	var center := Vector3.ZERO
	center[axis] = fixed + outward * length * 0.5
	fog.size = size
	fog.global_position = start_transform * center


func _commit_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, restore: Variant,
		cancel: bool) -> void:
	var fog := gizmo.get_node_3d() as QuakeGroundFog
	gizmo.remove_meta(&"drag_start")
	if cancel:
		fog.size = restore[0]
		fog.position = restore[1]
		return
	undo_redo.create_action("Resize Ground Fog")
	undo_redo.add_do_property(fog, &"size", fog.size)
	undo_redo.add_do_property(fog, &"position", fog.position)
	undo_redo.add_undo_property(fog, &"size", restore[0])
	undo_redo.add_undo_property(fog, &"position", restore[1])
	undo_redo.commit_action()


## Only a fog of the open scene, one in a placed map belongs to the map.
static func _editable(fog: Node) -> bool:
	var root := EditorInterface.get_edited_scene_root()
	return fog == root or fog.owner == root
