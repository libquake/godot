@tool
extends EditorInspectorPlugin
## On a QuakeMap: its entities, the picked one's keys and connections. On an entity node: its keys.

const CONNECTION_KEYS := ["target", "targetname", "killtarget"]

var gizmo: QuakeMapGizmo


func _can_handle(object: Object) -> bool:
	return object is QuakeMap or (object is Node and object.has_meta(QuakeSceneBuilder.ENTITY_META))


func _parse_begin(object: Object) -> void:
	if object is QuakeMap:
		add_custom_control(_map_panel(object))
	else:
		add_custom_control(_entity_panel(object, func(node: Node) -> void: EditorInterface.edit_node(node)))


func _map_panel(map: QuakeMap) -> Control:
	var panel := VBoxContainer.new()
	if not map.import_warnings.is_empty():
		panel.add_child(_warnings(map.import_warnings))
	var filter := LineEdit.new()
	filter.placeholder_text = "Filter entities"
	filter.clear_button_enabled = true
	var list := ItemList.new()
	list.custom_minimum_size.y = 200.0
	var details := VBoxContainer.new()
	panel.add_child(filter)
	panel.add_child(list)
	panel.add_child(details)

	var entities := _entities(map)
	var pick := func(node: Node) -> void:
		gizmo.pick(map, node)
		for child in details.get_children():
			child.queue_free()
		details.add_child(_entity_panel(node, func(target: Node) -> void: gizmo.pick(map, target)))
	var fill := func(text: String) -> void:
		list.clear()
		for node in entities:
			var label := _label(node)
			if text.is_empty() or label.containsn(text):
				list.set_item_metadata(list.add_item(label), node)
	filter.text_changed.connect(fill)
	list.item_selected.connect(func(index: int) -> void: pick.call(list.get_item_metadata(index)))
	fill.call("")
	return panel


## One short line per kind, the whole text in the tooltip and the Output.
func _warnings(lines: PackedStringArray) -> Control:
	var label := Label.new()
	label.text = "Import warnings, the Output lists them all:\n- " + "\n- ".join(summarize_warnings(lines))
	label.tooltip_text = "\n".join(lines)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 100.0
	label.add_theme_color_override(&"font_color", EditorInterface.get_editor_theme().get_color(&"warning_color", &"Editor"))
	return label


## "missing textures (37)" for "missing textures: a, b, ...", lines without a list count one each.
static func summarize_warnings(lines: PackedStringArray) -> PackedStringArray:
	var counts := {}
	for line in lines:
		var listed := line.contains(": ")
		var kind := line.get_slice(": ", 0) if listed else "targets that no targetname matches"
		counts[kind] = counts.get(kind, 0) + (line.get_slice(": ", 1).split(", ").size() if listed else 1)
	var summary := PackedStringArray()
	for kind: String in counts:
		summary.append("%s (%d)" % [kind, counts[kind]])
	return summary


## target, targetname and killtarget are buttons to the other end.
func _entity_panel(node: Node, open: Callable) -> Control:
	var panel := VBoxContainer.new()
	var title := Label.new()
	title.text = _label(node)
	title.add_theme_font_override(&"font", EditorInterface.get_editor_theme().get_font(&"bold", &"EditorFonts"))
	panel.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	panel.add_child(grid)

	var properties := QuakeEntity.properties(node)
	var keys := properties.keys()
	keys.sort()
	var map := QuakeMap.of(node)
	for key: String in keys:
		var name_label := Label.new()
		name_label.text = key
		grid.add_child(name_label)
		var value := str(properties[key])
		if CONNECTION_KEYS.has(key) and map:
			var others := map.find_targets(value) if key != "targetname" else _sources(map, value)
			var button := MenuButton.new() if others.size() > 1 else Button.new()
			button.text = value
			button.flat = true
			button.disabled = others.is_empty()
			if button is MenuButton:
				for other in others:
					button.get_popup().add_item(_label(other))
				button.get_popup().index_pressed.connect(func(index: int) -> void: open.call(others[index]))
			elif not others.is_empty():
				button.pressed.connect(func() -> void: open.call(others[0]))
			grid.add_child(button)
		else:
			var value_label := Label.new()
			value_label.text = value
			grid.add_child(value_label)
	return panel


static func _label(node: Node) -> String:
	var targetname := QuakeEntity.get_string(node, "targetname")
	return node.name if targetname.is_empty() else "%s (%s)" % [node.name, targetname]


static func _entities(map: QuakeMap) -> Array[Node]:
	var entities: Array[Node] = []
	for child in map.get_children():
		if child.has_meta(QuakeSceneBuilder.ENTITY_META):
			entities.append(child)
	return entities


static func _sources(map: QuakeMap, targetname: String) -> Array[Node]:
	var sources: Array[Node] = []
	for node in _entities(map):
		if targetname in [QuakeEntity.get_string(node, "target"), QuakeEntity.get_string(node, "killtarget")]:
			sources.append(node)
	return sources
