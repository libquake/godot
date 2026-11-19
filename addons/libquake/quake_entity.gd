class_name QuakeEntity
extends RefCounted
## Helpers for entity scripts: parsed keys and Quake's target/targetname firing, which calls
## _quake_triggered(activator) on the targets.

const TRIGGERED := &"_quake_triggered"
## Also the @export types that become keys.
const KEY_TYPES: Array[int] = [TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_BOOL, TYPE_VECTOR3, TYPE_COLOR]


static func properties(node: Node) -> Dictionary:
	return node.get_meta(QuakeSceneBuilder.ENTITY_META, {}).get("properties", {})


static func get_string(node: Node, key: String, default := "") -> String:
	return str(properties(node).get(key, default))


static func get_float(node: Node, key: String, default := 0.0) -> float:
	return _read(node, key, TYPE_FLOAT, default)


static func get_int(node: Node, key: String, default := 0) -> int:
	return _read(node, key, TYPE_INT, default)


## As written, in Quake units and axes. The position is in the "quake_entity" meta.
static func get_vector(node: Node, key: String, default := Vector3.ZERO) -> Vector3:
	return _read(node, key, TYPE_VECTOR3, default)


static func get_color(node: Node, key: String, default := Color.WHITE) -> Color:
	return _read(node, key, TYPE_COLOR, default)


## Null if it does not parse. Colors may be 0-1 or 0-255.
static func parse(text: String, type: int) -> Variant:
	match type:
		TYPE_STRING:
			return text
		TYPE_INT:
			return int(text.to_float()) if text.is_valid_float() else null
		TYPE_FLOAT:
			return text.to_float() if text.is_valid_float() else null
		TYPE_BOOL:
			return text.to_int() != 0 if text.is_valid_int() else text.to_lower() == "true"
		TYPE_VECTOR3, TYPE_COLOR:
			var numbers := text.split_floats(" ", false)
			if numbers.size() < 3:
				return null
			if type == TYPE_VECTOR3:
				return Vector3(numbers[0], numbers[1], numbers[2])
			var scale := 255.0 if maxf(numbers[0], maxf(numbers[1], numbers[2])) > 1.0 else 1.0
			return Color(numbers[0] / scale, numbers[1] / scale, numbers[2] / scale)
	return null


## Sets every @export variable of node from the key of the same name.
## Of the node's map, outside a map the project's geometry/units_per_meter.
static func units_per_meter(node: Node) -> float:
	var map := QuakeMap.of(node)
	return map.units_per_meter if map else QuakeImportSettings.project_default("geometry/units_per_meter")


## A length or speed in map units, e.g. speed or lip, in meters.
static func meters(node: Node, units: float) -> float:
	return units / units_per_meter(node)


static func apply_keys(node: Node) -> void:
	var script := node.get_script() as Script
	if not script:
		return
	var values := properties(node)
	for property in script.get_script_property_list():
		if not _is_key(property) or not values.has(property.name):
			continue
		var value: Variant = parse(str(values[property.name]), property.type)
		if value != null:
			node.set(property.name, value)


static func script_keys(script: Script) -> Dictionary:
	var keys := {}
	for property in script.get_script_property_list():
		if _is_key(property):
			keys[property.name] = script.get_property_default_value(property.name)
	return keys


static func _is_key(property: Dictionary) -> bool:
	return property.usage & PROPERTY_USAGE_EDITOR and property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE \
			and KEY_TYPES.has(property.type)


static func _read(node: Node, key: String, type: int, default: Variant) -> Variant:
	var values := properties(node)
	var value: Variant = parse(str(values[key]), type) if values.has(key) else null
	return default if value == null else value


static func has_spawnflag(node: Node, flag: int) -> bool:
	return get_int(node, "spawnflags") & flag != 0


## Like Quake's SUB_UseTargets, after the node's "delay".
static func fire(node: Node, activator: Node = null) -> void:
	var delay := get_float(node, "delay")
	if delay > 0.0:
		await node.get_tree().create_timer(delay).timeout
	var map := QuakeMap.of(node)
	if not map:
		return
	for target in map.find_targets(get_string(node, "target")):
		if target.has_method(TRIGGERED):
			target.call(TRIGGERED, activator)
