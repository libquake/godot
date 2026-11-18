extends QuakeTest


func test_skill_removes_what_is_not_in_it() -> void:
	var map: QuakeMap = add_scene("res://maps/level.map")
	await frames(1)
	map.apply_skill(0)
	check(map.find_targets("easy_only_not").is_empty(), "not in easy is gone on easy")
	check(not map.find_targets("no_deathmatch").is_empty(), "not in deathmatch stays in single player")


func test_deathmatch_removes_what_is_not_in_it() -> void:
	var map: QuakeMap = add_scene("res://maps/level.map")
	await frames(1)
	map.apply_skill(1, true)
	check(map.find_targets("no_deathmatch").is_empty(), "not in deathmatch is gone in deathmatch")
	check(not map.find_targets("easy_only_not").is_empty(), "skill flags do not count in deathmatch")
