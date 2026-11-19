@tool
class_name QuakeImportSettings
extends RefCounted
## Import options of Quake maps, with their defaults in Project Settings > libquake.

const PREFIX := "libquake/"
const PIVOTS := "Map Origin,Center,Bottom Center,Bottom Corner"
const LEVEL_ONLY_GROUPS := ["lighting", "entities", "editor"]
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
		# 32 makes the Quake player 1.75 m tall.
		{"name": "geometry/units_per_meter", "default": 32.0},
		# Removes faces hidden inside other brushes of the same entity.
		{"name": "geometry/csg", "default": true},
		# Origin of brush entities, an origin brush or _pivot wins.
		{"name": "geometry/pivot", "default": QuakeLevel.PIVOT_BOTTOM_CENTER,
			"hint": PROPERTY_HINT_ENUM, "hint_string": PIVOTS},
		{"name": "lighting/bake", "default": true},
		# Map units per lightmap texel.
		{"name": "lighting/luxel_size", "default": 16.0},
		# Suns per sky dome (_sunlight2, _sunlight3), fewer bake faster.
		{"name": "lighting/sky_samples", "default": 64, "hint": PROPERTY_HINT_RANGE, "hint_string": "8,2048"},
		# Times light bounces off surfaces, -1 as the map's _bounce says.
		{"name": "lighting/bounces", "default": -1, "hint": PROPERTY_HINT_RANGE, "hint_string": "-1,4"},
		# Brightness of the bounced light, -1 as the map's _bouncescale says. Lower it for maps lit without bounce.
		{"name": "lighting/bounce_scale", "default": -1.0, "hint": PROPERTY_HINT_RANGE, "hint_string": "-1,2,0.05"},
		# Samples per luxel along each side, 2 or 4 for smoother shadow edges. Costs 4 or 16 times.
		{"name": "lighting/luxel_samples", "default": 1, "hint": PROPERTY_HINT_RANGE, "hint_string": "1,4"},
		# Ambient occlusion: -1 as the map's _dirt says, 0 none, 1 everywhere.
		{"name": "lighting/dirt", "default": -1, "hint": PROPERTY_HINT_RANGE, "hint_string": "-1,1"},
		# Strength of the ambient occlusion, -1 as the map's _dirtscale says.
		{"name": "lighting/dirt_scale", "default": -1.0, "hint": PROPERTY_HINT_RANGE, "hint_string": "-1,2,0.05"},
		# Rays per sample for ambient occlusion, fewer bake faster.
		{"name": "lighting/dirt_samples", "default": 48, "hint": PROPERTY_HINT_RANGE, "hint_string": "12,192"},
		# Map units per patch that bounces light, larger bake faster.
		{"name": "lighting/bounce_subdivision", "default": 64.0, "hint": PROPERTY_HINT_RANGE,
			"hint_string": "16,512"},
		# Meters between the points that light models, 0 is none.
		{"name": "lighting/light_grid_cell_size", "default": 1.0},
		# Off shows the WorldEnvironment's sky.
		{"name": "surfaces/draw_sky", "default": true},
		# The worldspawn keys _wateralpha, ... win.
		{"name": "surfaces/water_alpha", "default": 0.6, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,1,0.01"},
		{"name": "surfaces/slime_alpha", "default": 0.7, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,1,0.01"},
		{"name": "surfaces/lava_alpha", "default": 0.85, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,1,0.01"},
		{"name": "surfaces/teleport_alpha", "default": 1.0, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,1,0.01"},
		# Above 1 fullbright pixels bloom.
		{"name": "surfaces/fullbright_energy", "default": 1.0, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,8,0.05"},
		# Image textures, used before the wads.
		{"name": "textures/texture_directories", "default": PackedStringArray(["res://textures"])},
		# Wads outside the project, the project's own are always found.
		{"name": "textures/wad_directories", "default": PackedStringArray()},
		{"name": "entities/entity_classes", "default": "",
			"hint": PROPERTY_HINT_FILE, "hint_string": "*.tres,*.res"},
		# Style folders besides libquake's own, they win on the same name.
		{"name": "entities/ground_fog_styles", "default": PackedStringArray()},
		# Brush collision in the editor, triggers and liquids always show.
		{"name": "editor/show_hulls", "default": false},
		# A scene with collision, or the bare mesh.
		{"name": "pieces/save_as", "default": Pieces.SCENES, "hint": PROPERTY_HINT_ENUM, "hint_string": SAVE_PIECES_AS},
		# Empty is a folder named like the map, next to it.
		{"name": "pieces/folder", "default": "", "hint": PROPERTY_HINT_DIR},
	]
