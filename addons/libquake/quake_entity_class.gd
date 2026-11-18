@tool
class_name QuakeEntityClass
extends Resource
## One entity class: which node the import makes of it and how TrenchBroom shows it (FGD).

enum Type { POINT, BRUSH }

## A trailing * makes it a prefix: light* covers light, light_fluoro, ... Prefixes are not exported to the FGD.
@export var classname := ""
@export var type := Type.POINT
@export_multiline var description := ""

@export_group("Import")
## Wins over node_script.
@export var scene: PackedScene
## Instantiated for the entity, e.g. a script extending AnimatableBody3D for a door.
@export var node_script: Script
## Leaves the entity out of the imported scene.
@export var exclude := false

@export_group("TrenchBroom")
## Keys with their default values, on top of the @export variables of the script, which are keys too.
## The type of a value picks the FGD type: int, float, bool, String, Color (_color style, 0-1), Vector3.
@export var properties: Dictionary[String, Variant] = {}
@export var property_descriptions: Dictionary[String, String] = {}
@export var color := Color(0.8, 0.8, 0.8)
## Point entities only, in Quake units.
@export var size := AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))


## The keys of the FGD: the @export variables of node_script or of the scene's root, then properties.
func all_properties() -> Dictionary:
	var keys := {}
	var script := entity_script()
	if script:
		keys = QuakeEntity.script_keys(script)
	keys.merge(properties, true)
	return keys


func is_prefix() -> bool:
	return classname.ends_with("*")


func matches(entity_classname: String) -> bool:
	return entity_classname.begins_with(classname.trim_suffix("*")) if is_prefix() else entity_classname == classname


## description and property_descriptions win, without them the ## comments of the script: of the class and of
## its @export variables.
func to_fgd() -> String:
	var docs := script_docs(entity_script())
	var header := "@PointClass size(%s, %s)" % [_vector(size.position), _vector(size.end)] if type == Type.POINT else "@SolidClass"
	var lines := PackedStringArray()
	var text := description if not description.is_empty() else docs.get("", "")
	lines.append('%s color(%s) = %s : "%s"' % [header, _vector(Vector3(color.r, color.g, color.b) * 255.0), classname, _escape(text)])
	lines.append("[")
	var keys := all_properties()
	for key in keys:
		lines.append("\t" + _fgd_property(key, keys[key], property_descriptions.get(key, docs.get(key, ""))))
	lines.append("]")
	return "\n".join(lines)


## node_script, or the script of the scene's root.
func entity_script() -> Script:
	if node_script:
		return node_script
	if not scene:
		return null
	var state := scene.get_state()
	for index in state.get_node_property_count(0):
		if state.get_node_property_name(0, index) == &"script":
			return state.get_node_property_value(0, index)
	return null


## The ## comments of a script and the scripts it extends: "" the class's, the others by variable. Read from its
## source, so only where that is kept: in the editor, where the FGD is made.
static func script_docs(script: Script) -> Dictionary:
	var docs := {}
	if not script:
		return docs
	var base := script.get_base_script()
	if base:
		docs = script_docs(base)
		# the class text is the script's own
		docs.erase("")
	var variable := RegEx.create_from_string("\\bvar\\s+(\\w+)")
	var comment := PackedStringArray()
	# like Godot's: the class's comment is right below class_name or extends
	var header := false
	var class_comment := false
	var exported := false
	for line in script.source_code.split("\n"):
		var code := line.strip_edges()
		if code.begins_with("##"):
			if comment.is_empty():
				class_comment = header
			comment.append(code.trim_prefix("##").strip_edges())
			continue
		if class_comment and not comment.is_empty():
			docs[""] = " ".join(comment)
			comment.clear()
		class_comment = false
		header = code.begins_with("extends ") or code.begins_with("class_name ") \
				or (header and code.begins_with("@"))
		# an annotation on its own line keeps the comment for the variable below
		if code.begins_with("@") and not code.contains(" var "):
			exported = exported or code.begins_with("@export")
			continue
		var found := variable.search(code)
		if found and (exported or code.begins_with("@export")) and not comment.is_empty():
			docs[found.get_string(1)] = " ".join(comment)
		exported = false
		comment.clear()
	return docs


static func _fgd_property(key: String, value: Variant, text: String) -> String:
	match typeof(value):
		TYPE_INT:
			return '%s(integer) : "%s" : %d' % [key, _escape(text), value]
		TYPE_FLOAT:
			return '%s(float) : "%s" : "%s"' % [key, _escape(text), value]
		TYPE_BOOL:
			return '%s(choices) : "%s" : %d = [ 0 : "No" 1 : "Yes" ]' % [key, _escape(text), int(value)]
		TYPE_COLOR:
			return '%s(color1) : "%s" : "%s %s %s"' % [key, _escape(text), value.r, value.g, value.b]
		TYPE_VECTOR3:
			return '%s(string) : "%s" : "%s"' % [key, _escape(text), _vector(value)]
		TYPE_PACKED_STRING_ARRAY:
			# the first is the default
			var choices := PackedStringArray()
			for choice: String in value:
				choices.append('"%s" : "%s"' % [_escape(choice), _escape(choice)])
			return '%s(choices) : "%s" : "%s" = [ %s ]' % [key, _escape(text),
					_escape(value[0]) if not value.is_empty() else "", " ".join(choices)]
		_:
			return '%s(string) : "%s" : "%s"' % [key, _escape(text), _escape(str(value))]


static func _vector(value: Vector3) -> String:
	return "%d %d %d" % [roundi(value.x), roundi(value.y), roundi(value.z)]


static func _escape(text: String) -> String:
	return text.replace('"', "'").replace("\n", " ")
