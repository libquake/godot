@tool
class_name QuakeEntityClasses
extends Resource
## The entity classes of a game: which node a Quake classname becomes, and the FGD TrenchBroom shows.
## An exact classname wins over a prefix, a longer prefix over a shorter one.

@export var classes: Array[QuakeEntityClass] = []
@export_tool_button("Export to TrenchBroom", "Save") var export_to_trenchbroom := _export_to_trenchbroom


func find(classname: String) -> QuakeEntityClass:
	var best: QuakeEntityClass
	for entity_class in classes:
		if not entity_class or not entity_class.matches(classname):
			continue
		if not entity_class.is_prefix():
			return entity_class
		if not best or entity_class.classname.length() > best.classname.length():
			best = entity_class
	return best


func uses_script(script: Script) -> bool:
	return classes.any(func(entity_class: QuakeEntityClass) -> bool:
		return entity_class and entity_class.entity_script() == script)


## Exact classes only; the worldspawn and light keys libquake reads come along unless defined here.
func to_fgd() -> String:
	var parts := PackedStringArray()
	for entity_class in QuakeBuiltinEntities.classes():
		if not find(entity_class.classname) or find(entity_class.classname).is_prefix():
			parts.append(entity_class.to_fgd())
	for entity_class in classes:
		if entity_class and not entity_class.is_prefix():
			parts.append(entity_class.to_fgd())
	return "\n\n".join(parts) + "\n"


func _export_to_trenchbroom() -> void:
	QuakeTrenchBroom.export_game_config(self)
