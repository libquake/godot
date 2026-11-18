class_name QuakeTest
extends Node
## Base of the plugin's tests: every method starting with test_ is a test, failed checks are collected.

var failures := PackedStringArray()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s: %s, expected %s" % [message, actual, expected])


func add_scene(path: String) -> Node:
	var node: Node = load(path).instantiate()
	add_child(node)
	return node


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
