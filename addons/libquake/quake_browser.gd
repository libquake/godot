@tool
extends VBoxContainer
## The Quake panel: shows what is selected in the FileSystem dock, the pieces of a map to drag into the 3D
## viewport, or the textures of a wad.

## Extract Textures was pressed for the wad shown.
signal extract_requested(wad_path: String)

const DEFAULT_SIZE := 96.0

## The file shown, empty before one was selected.
var path := ""

var _names := PackedStringArray()
var _icons: Array[Texture2D] = []
var _tooltips := PackedStringArray()
## The file each entry drags, empty for textures.
var _files := PackedStringArray()

var _title := Label.new()
var _filter := LineEdit.new()
var _size := HSlider.new()
var _extract := Button.new()
var _list := ItemList.new()
var _hint := Label.new()


func _init() -> void:
	name = "Quake"
	custom_minimum_size.y = 180.0
	var bar := HBoxContainer.new()
	add_child(bar)
	_title.size_flags_horizontal = SIZE_EXPAND_FILL
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar.add_child(_title)
	_filter.placeholder_text = "Filter"
	_filter.clear_button_enabled = true
	_filter.custom_minimum_size.x = 180.0
	_filter.text_changed.connect(func(_text: String) -> void: _fill())
	bar.add_child(_filter)
	_size.min_value = 48.0
	_size.max_value = 256.0
	_size.step = 8.0
	_size.value = DEFAULT_SIZE
	_size.custom_minimum_size.x = 120.0
	_size.size_flags_vertical = SIZE_SHRINK_CENTER
	_size.tooltip_text = "Preview size"
	_size.value_changed.connect(_resize)
	bar.add_child(_size)
	_extract.text = "Extract Textures"
	_extract.tooltip_text = "Write the textures as image files to the first texture directory"
	_extract.hide()
	_extract.pressed.connect(func() -> void: extract_requested.emit(path))
	bar.add_child(_extract)

	_list.size_flags_vertical = SIZE_EXPAND_FILL
	_list.icon_mode = ItemList.ICON_MODE_TOP
	_list.max_columns = 0
	_list.same_column_width = true
	_list.max_text_lines = 1
	_list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# the textures are pixel art, so are the pieces' previews
	_list.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_list.set_drag_forwarding(_drag, Callable(), Callable())
	add_child(_list)
	_hint.text = "Select a map of pieces or a wad in the FileSystem dock."
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.size_flags_vertical = SIZE_EXPAND_FILL
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_hint)
	_list.hide()
	_resize(DEFAULT_SIZE)


func show_pieces(pieces: QuakePieces, pieces_path: String) -> void:
	path = pieces_path
	_names = pieces.names
	_icons.assign(pieces.previews)
	_files = pieces.files
	_tooltips = pieces.files
	_title.text = "%s: %d pieces, drag them into the 3D viewport" % [pieces_path.get_file(), pieces.size()]
	_extract.hide()
	_fill()


func show_wad(textures: QuakeWadTextures, wad_path: String) -> void:
	path = wad_path
	_names = textures.names
	_icons.assign(textures.previews)
	_files = PackedStringArray()
	_files.resize(textures.size())
	_tooltips = PackedStringArray()
	for index in textures.size():
		_tooltips.append("%s, %d × %d" % [textures.names[index], textures.sizes[index].x, textures.sizes[index].y])
	_title.text = "%s: %d textures" % [wad_path.get_file(), textures.size()]
	_extract.show()
	_fill()


func _fill() -> void:
	_list.clear()
	for index in _names.size():
		if not _filter.text.is_empty() and not _names[index].containsn(_filter.text):
			continue
		var item := _list.add_item(_names[index], _icons[index] if index < _icons.size() else null)
		_list.set_item_metadata(item, index)
		_list.set_item_tooltip(item, _tooltips[index])
	_list.visible = not _names.is_empty()
	_hint.visible = not _list.visible


func _resize(value: float) -> void:
	_list.fixed_icon_size = Vector2i(roundi(value), roundi(value))
	_list.fixed_column_width = roundi(value) + 8


## Pieces drag as their file, like from the FileSystem dock: the viewport places them under the mouse.
func _drag(at_position: Vector2) -> Variant:
	var item := _list.get_item_at_position(at_position, true)
	if item < 0:
		return null
	var file := _files[_list.get_item_metadata(item)]
	if file.is_empty():
		return null
	var preview := TextureRect.new()
	preview.texture = _list.get_item_icon(item)
	preview.custom_minimum_size = Vector2(64, 64)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_list.set_drag_preview(preview)
	return {"type": "files", "files": PackedStringArray([file]), "from": self}
