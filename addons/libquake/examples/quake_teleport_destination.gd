class_name QuakeTeleportDestination
extends Marker3D
## Example of a scripted point entity: Quake's info_teleport_destination. Places a body where it stands,
## turns it the way it faces and pushes it forward like Quake does.
## Map it in a QuakeEntityClasses resource: classname info_teleport_destination, node_script this file.

## Units per second, Quake sends the player out with 300.
@export var exit_speed := 300.0


## body has a method teleport(Transform3D), FPSController for one.
func receive(body: Node3D) -> void:
	body.teleport(global_transform)
	if "velocity" in body:
		body.velocity = -global_basis.z * QuakeEntity.meters(self, exit_speed)
