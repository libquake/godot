@tool
@icon("icons/quake_map.svg")
class_name QuakeMap
extends Node3D
## Root of an imported map. Entities are children in a group named after their classname.


const NOT_IN_EASY := 256
const NOT_IN_NORMAL := 512
const NOT_IN_HARD := 1024
const NOT_IN_DEATHMATCH := 2048

## geometry/units_per_meter of its import.
@export var units_per_meter := 32.0
## What its import could not resolve.
@export_storage var import_warnings := PackedStringArray()


## Removes entities not spawned at this skill (0 easy to 3 nightmare) or in deathmatch, as Quake does. Call it
## before the level starts.
func apply_skill(skill: int, deathmatch := false) -> void:
	var excluded: int = NOT_IN_DEATHMATCH if deathmatch else [NOT_IN_EASY, NOT_IN_NORMAL, NOT_IN_HARD][clampi(skill, 0, 2)]
	for node in get_children():
		if node.has_meta(QuakeSceneBuilder.ENTITY_META) and QuakeEntity.has_spawnflag(node, excluded):
			# right away, so find_targets() no longer sees it
			remove_child(node)
			node.queue_free()


## The map an entity node belongs to.
static func of(node: Node) -> QuakeMap:
	var current := node.get_parent()
	while current and not current is QuakeMap:
		current = current.get_parent()
	return current


## The entities whose "targetname" is targetname.
func find_targets(targetname: String) -> Array[Node]:
	var found: Array[Node] = []
	if targetname.is_empty():
		return found
	for node in find_children("*", "", true, false):
		var entity: Dictionary = node.get_meta(QuakeSceneBuilder.ENTITY_META, {})
		if entity.get("properties", {}).get("targetname", "") == targetname:
			found.append(node)
	return found


func find_entities(classname: String) -> Array[Node]:
	var found: Array[Node] = []
	for node in get_tree().get_nodes_in_group(classname):
		if is_ancestor_of(node):
			found.append(node)
	return found
