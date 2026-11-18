class_name QuakeTeleport
extends Area3D
## Example of a scripted brush entity: Quake's trigger_teleport. A body that enters is handed to the
## info_teleport_destination whose "targetname" is this entity's "target". Only bodies with a method
## teleport(Transform3D) are teleported, the area also overlaps the world and doors.
## Map it in a QuakeEntityClasses resource: classname trigger_teleport, node_script this file.

var _target := ""


func _ready() -> void:
	var entity: Dictionary = get_meta(QuakeSceneBuilder.ENTITY_META, {})
	_target = entity.get("properties", {}).get("target", "")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method(&"teleport"):
		return
	var map := QuakeMap.of(self)
	if not map: return
	for target in map.find_targets(_target):
		if target is QuakeTeleportDestination:
			target.receive(body)
			return
	push_warning('%s: no info_teleport_destination named "%s"' % [name, _target])
