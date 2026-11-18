@tool
class_name QuakeMapGizmo
extends EditorNode3DGizmoPlugin
## Draws the entity picked in the inspector of a QuakeMap: a box around it, lines to the entities it fires
## (orange) and from the entities that fire it (cyan), like TrenchBroom shows links.

const POINT_SIZE := 0.5
## Corners of an AABB as get_endpoint() numbers them, paired along its twelve edges.
const BOX_EDGES := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]

var _map: QuakeMap
var _picked: Node3D


func _init() -> void:
	create_material("picked", Color(1.0, 0.9, 0.2), false, true)
	create_material("targets", Color(1.0, 0.55, 0.1), false, true)
	create_material("sources", Color(0.2, 0.8, 1.0), false, true)


func _get_gizmo_name() -> String:
	return "Quake Map"


func _has_gizmo(node: Node3D) -> bool:
	return node is QuakeMap


func pick(map: QuakeMap, entity: Node) -> void:
	var previous := _map
	_map = map
	_picked = entity as Node3D
	if is_instance_valid(previous) and previous != map:
		previous.update_gizmos()
	map.update_gizmos()


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var map := gizmo.get_node_3d() as QuakeMap
	if map != _map or not is_instance_valid(_picked) or not map.is_ancestor_of(_picked):
		return
	gizmo.add_lines(_box(map, _picked), get_material("picked", gizmo))
	var center := _center(map, _picked)
	var targets := PackedVector3Array()
	for target in map.find_targets(QuakeEntity.get_string(_picked, "target")):
		targets.append_array([center, _center(map, target)])
	gizmo.add_lines(targets, get_material("targets", gizmo))
	var sources := PackedVector3Array()
	var targetname := QuakeEntity.get_string(_picked, "targetname")
	if not targetname.is_empty():
		for node in map.find_children("*", "Node3D", false, false):
			if QuakeEntity.get_string(node, "target") == targetname:
				sources.append_array([_center(map, node), center])
	gizmo.add_lines(sources, get_material("sources", gizmo))


## Where the lines meet an entity: the middle of its mesh or, for triggers, of its collision.
static func _center(map: QuakeMap, entity: Node) -> Vector3:
	return map.to_local((entity as Node3D).global_transform * _bounds(entity).get_center())


static func _box(map: QuakeMap, entity: Node3D) -> PackedVector3Array:
	var bounds := _bounds(entity)
	var lines := PackedVector3Array()
	for edge in BOX_EDGES:
		for corner in edge:
			lines.append(map.to_local(entity.global_transform * bounds.get_endpoint(corner)))
	return lines


## In the entity's space: its mesh, else its convex collision (triggers are not drawn), else a small cube.
## Ground fog has neither, its box is the size it was given.
static func _bounds(entity: Node) -> AABB:
	if entity is QuakeGroundFog:
		return AABB(entity.size * -0.5, entity.size)
	for child in entity.get_children():
		if child is MeshInstance3D and child.mesh:
			return child.mesh.get_aabb()
	var bounds := AABB()
	var found := false
	for child in entity.get_children():
		if child is CollisionShape3D and child.shape is ConvexPolygonShape3D:
			for point: Vector3 in child.shape.points:
				var corner: Vector3 = child.transform * point
				bounds = bounds.expand(corner) if found else AABB(corner, Vector3.ZERO)
				found = true
	return bounds if found else AABB(Vector3.ONE * -POINT_SIZE * 0.5, Vector3.ONE * POINT_SIZE)
