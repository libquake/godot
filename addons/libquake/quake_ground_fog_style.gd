@tool
class_name QuakeGroundFogStyle
extends Resource
## The look of QuakeGroundFog. Found by file name, the project's styles in entities/ground_fog_styles win over
## libquake's. Unknown names look like default.

const DEFAULT := "default"
const BUILTIN_DIRECTORY := "res://addons/libquake/ground_fog_styles"
## Passed to the shader uniforms of the same name.
const PARAMS: Array[StringName] = [
	&"fog_height",
	&"top_softness",
	&"density",
	&"fog_color",
	&"edge_fade",
	&"camera_fade",
	&"noise_texture",
	&"hill_amount",
	&"hill_scale",
	&"wind",
	&"morph_speed",
	&"pixel_size",
	&"alpha_steps",
	&"dither",
	&"dither_scale",
	&"anim_fps",
	&"steps",
]

@export_group("Look")
## Meters above the box's floor, before the hills.
@export_range(0.05, 4.0, 0.01) var fog_height := 0.6:
	set(value):
		fog_height = value
		emit_changed()
## Meters below its top where the fog reaches full density.
@export_range(0.01, 2.0, 0.01) var top_softness := 0.4:
	set(value):
		top_softness = value
		emit_changed()
@export_range(0.0, 16.0, 0.05) var density := 1.2:
	set(value):
		density = value
		emit_changed()
@export var fog_color := Color(0.36, 0.32, 0.27):
	set(value):
		fog_color = value
		emit_changed()
## Meters over which the fog fades out toward the box's sides.
@export_range(0.0, 8.0, 0.05) var edge_fade := 1.0:
	set(value):
		edge_fade = value
		emit_changed()
## Meters around the camera without fog.
@export_range(0.0, 4.0, 0.05) var camera_fade := 0.5:
	set(value):
		camera_fade = value
		emit_changed()

@export_group("Hills")
## Grayscale hill map, tiled across the world. Empty is flat.
@export var noise_texture: Texture2D = preload("textures/quake_ground_fog_noise.tres"):
	set(value):
		noise_texture = value
		emit_changed()
## How far the top rolls up and down, as a share of fog_height.
@export_range(0.0, 1.0, 0.01) var hill_amount := 0.5:
	set(value):
		hill_amount = value
		emit_changed()
## Hills per meter.
@export_range(0.01, 2.0, 0.01) var hill_scale := 0.15:
	set(value):
		hill_scale = value
		emit_changed()
@export var wind := Vector2(0.03, 0.012):
	set(value):
		wind = value
		emit_changed()
@export_range(0.0, 1.0, 0.01) var morph_speed := 0.15:
	set(value):
		morph_speed = value
		emit_changed()

@export_group("Retro")
## Meters per fog pixel, 0 is smooth. A Quake texel is 1/32 m.
@export_range(0.0, 1.0, 0.03125) var pixel_size := 0.125:
	set(value):
		pixel_size = value
		emit_changed()
## Opacity levels, 0 is smooth, 1 a screen door.
@export_range(0, 16) var alpha_steps := 4:
	set(value):
		alpha_steps = value
		emit_changed()
## 0 gives hard bands between the opacity levels, 1 an ordered dither between them.
@export_range(0.0, 1.0, 0.01) var dither := 1.0:
	set(value):
		dither = value
		emit_changed()
## Screen pixels per dither cell.
@export_range(1, 8) var dither_scale := 2:
	set(value):
		dither_scale = value
		emit_changed()
## Frames per second the fog animates at, 0 is every frame.
@export_range(0.0, 60.0, 1.0) var anim_fps := 12.0:
	set(value):
		anim_fps = value
		emit_changed()
## Samples along the view ray.
@export_range(1, 32) var steps := 8:
	set(value):
		steps = value
		emit_changed()


## Meters above the box's floor the highest hill reaches.
func top() -> float:
	return fog_height * (1.0 + hill_amount)


## Null if there is none. directories defaults to entities/ground_fog_styles.
static func find(style_name: String, directories: Variant = null) -> QuakeGroundFogStyle:
	var path: String = _paths(directories).get(style_name, "")
	return load(path) if not path.is_empty() else null


## Default first.
static func names(directories: Variant = null) -> PackedStringArray:
	var result := PackedStringArray(_paths(directories).keys())
	result.sort()
	if result.has(DEFAULT):
		result.remove_at(result.find(DEFAULT))
		result.insert(0, DEFAULT)
	return result


## Name to path, the project's override libquake's.
static func _paths(directories: Variant) -> Dictionary:
	var folders := PackedStringArray([BUILTIN_DIRECTORY])
	folders.append_array(directories if directories != null \
			else QuakeImportSettings.project_default("entities/ground_fog_styles"))
	var paths := {}
	for folder in folders:
		if not DirAccess.dir_exists_absolute(folder):
			continue
		# sees through the remaps of an exported game
		for file in ResourceLoader.list_directory(folder):
			if file.get_extension() not in ["tres", "res"]:
				continue
			var path := folder.path_join(file)
			if load(path) is QuakeGroundFogStyle:
				paths[file.get_basename()] = path
	return paths
