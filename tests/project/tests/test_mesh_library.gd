extends QuakeTest


func test_groups_become_items() -> void:
	var library: MeshLibrary = load("res://maps/pieces.map")
	var names := []
	for id in library.get_item_list():
		names.append(library.get_item_name(id))
		check_equal(id, library.get_item_name(id).hash() & 0xffff, "id of %s from its name" % library.get_item_name(id))
	names.sort()
	check_equal(names, ["crate", "pillar", "worldspawn"], "items")


func test_items_stand_on_their_pivot() -> void:
	var library: MeshLibrary = load("res://maps/pieces.map")
	var crate := library.find_item_by_name("crate")
	var bounds := library.get_item_mesh(crate).get_aabb()
	check_equal(bounds.position.y, 0.0, "bottom of the crate")
	check(bounds.size.is_equal_approx(Vector3(2, 1, 1)), "both brushes of the group: %s" % bounds.size)
	check_equal(library.get_item_shapes(crate).size(), 4, "a shape and its transform per brush")
