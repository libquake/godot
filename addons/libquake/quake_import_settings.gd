@tool
class_name QuakeImportSettings
extends RefCounted
## Import options of Quake maps. Their defaults live in Project Settings > libquake, a newly imported map
## starts with them and can override every one in the Import dock.

const PREFIX := "libquake/"
const PIVOTS := "Map Origin,Center,Bottom Center,Bottom Corner"
## Groups pieces have no use for: they are lit by Godot and have no entities.
const LEVEL_ONLY_GROUPS := ["lighting", "entities", "editor"]
## Groups only pieces have.
const PIECES_ONLY_GROUPS := ["pieces"]
const SAVE_PIECES_AS := "Scenes,Meshes"
enum Pieces { SCENES, MESHES }


static func register() -> void:
	for option in _options():
		var setting: String = PREFIX + option.name
		if not ProjectSettings.has_setting(setting):
			ProjectSettings.set_setting(setting, option.default)
		ProjectSettings.set_initial_value(setting, option.default)
		ProjectSettings.set_as_basic(setting, true)
		ProjectSettings.add_property_info({
			"name": setting,
			"type": typeof(option.default),
			"hint": option.get("hint", PROPERTY_HINT_NONE),
			"hint_string": option.get("hint_string", ""),
		})


static func level_options() -> Array[Dictionary]:
	var options := _options().filter(func(option: Dictionary) -> bool:
		return not PIECES_ONLY_GROUPS.has(option.name.get_slice("/", 0)))
	return _import_options(options)


static func pieces_options() -> Array[Dictionary]:
	var options := _options().filter(func(option: Dictionary) -> bool:
		return not LEVEL_ONLY_GROUPS.has(option.name.get_slice("/", 0)))
	return _import_options(options)


## The project's default for an option, e.g. "entities/entity_classes".
static func project_default(name: String) -> Variant:
	for option in _options():
		if option.name == name:
			return ProjectSettings.get_setting(PREFIX + name, option.default)
	return null


static func _import_options(options: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for option in options:
		result.append({
			"name": option.name,
			"default_value": ProjectSettings.get_setting(PREFIX + option.name, option.default),
			"property_hint": option.get("hint", PROPERTY_HINT_NONE),
			"hint_string": option.get("hint_string", ""),
		})
	return result


static func _options() -> Array[Dictionary]:
	return [
		# Quake units per Godot meter, 32 makes the Quake player 1.75 m tall.
		{"name": "geometry/units_per_meter", "default": 32.0},
		# Removes faces hidden inside other brushes of the same entity.
		{"name": "geometry/csg", "default": true},
		# Origin of brush entities. An origin brush or the key _pivot on an entity wins.
		{"name": "geometry/pivot", "default": QuakeLevel.PIVOT_BOTTOM_CENTER,
			"hint": PROPERTY_HINT_ENUM, "hint_string": PIVOTS},
		{"name": "lighting/bake", "default": true},
		# Map units per lightmap texel, 16 matches Quake.
		{"name": "lighting/luxel_size", "default": 16.0},
		# Meters between the points that light models, 0 leaves the grid out.
		{"name": "lighting/light_grid_cell_size", "default": 1.0},
		# Off for maps that are not sealed and show the WorldEnvironment's sky instead.
		{"name": "surfaces/draw_sky", "default": true},
		# How much liquids cover, the worldspawn keys _wateralpha, _slimealpha, ... win.
		{"name": "surfaces/water_alpha", "default": 0.6, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,1,0.01"},
		{"name": "surfaces/slime_alpha", "default": 0.7, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,1,0.01"},
		{"name": "surfaces/lava_alpha", "default": 0.85, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,1,0.01"},
		{"name": "surfaces/teleport_alpha", "default": 1.0, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,1,0.01"},
		# Brightness of fullbright texture pixels, above 1 they bloom with the Environment's glow.
		{"name": "surfaces/fullbright_energy", "default": 1.0, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,8,0.05"},
		# Folders of image textures, like TrenchBroom's textures folder. They come before the wads.
		{"name": "textures/texture_directories", "default": PackedStringArray(["res://textures"])},
		# Folders searched for .wad files besides the map's own.
		{"name": "textures/wad_directories", "default": PackedStringArray()},
		{"name": "entities/entity_classes", "default": "",
			"hint": PROPERTY_HINT_FILE, "hint_string": "*.tres,*.res"},
		# Folders of QuakeGroundFogStyles, named by their file, besides libquake's own. They win on the same name.
		{"name": "entities/ground_fog_styles", "default": PackedStringArray()},
		# The collision of brushes in the editor; triggers and liquids show either way.
		{"name": "editor/show_hulls", "default": false},
		# What a map of pieces saves each piece as, to drag into a scene: a MeshInstance3D with its collision, or
		# the bare mesh, which Godot drops as a MeshInstance3D.
		{"name": "pieces/save_as", "default": Pieces.SCENES, "hint": PROPERTY_HINT_ENUM, "hint_string": SAVE_PIECES_AS},
		# Where the pieces go, empty is a folder named like the map next to it.
		{"name": "pieces/folder", "default": "", "hint": PROPERTY_HINT_DIR},
	]
