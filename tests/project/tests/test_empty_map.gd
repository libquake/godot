extends QuakeTest


func test_an_empty_map_imports() -> void:
	var map: QuakeMap = add_scene("res://maps/empty.map")
	await frames(1)
	check(map != null, "a new map from the editor imports")
	check_equal(map.find_entities("worldspawn").size(), 1, "its worldspawn")
