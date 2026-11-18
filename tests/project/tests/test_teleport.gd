extends QuakeTest

const TELEPORTER := Vector3(-1.5, 1.0, 0.0)
const DESTINATION := Vector3(10.0, 0.75, 10.0)


func test_bodies_with_teleport_are_teleported() -> void:
	add_scene("res://maps/level.map")
	var body := _body(CharacterBody3D.new())
	body.set_script(_teleportable())
	add_child(body)
	body.global_position = TELEPORTER
	await physics_frames(5)
	check(body.global_position.is_equal_approx(DESTINATION), "at the destination: %s" % body.global_position)


func test_other_bodies_stay() -> void:
	add_scene("res://maps/level.map")
	var body := _body(StaticBody3D.new())
	add_child(body)
	body.global_position = TELEPORTER
	await physics_frames(5)
	check(body.global_position.is_equal_approx(TELEPORTER), "a body without teleport() stays")


static func _body(body: PhysicsBody3D) -> PhysicsBody3D:
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	body.add_child(shape)
	return body


static func _teleportable() -> GDScript:
	var script := GDScript.new()
	script.source_code = "extends CharacterBody3D\n\nfunc teleport(target: Transform3D) -> void:\n\tglobal_transform = target\n"
	script.reload()
	return script
