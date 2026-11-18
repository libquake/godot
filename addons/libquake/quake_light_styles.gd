class_name QuakeLightStyles
extends Node
## Animates the light styles of a lightmap at runtime: Quake's flickering and pulsing lights, and the
## switchable ones (styles 32 and up, lights with a targetname). The editor shows the lightmap at rest.

const GROUP := &"quake_light_styles"

@export var lightmap: ImageTexture
## One RGBA layer per style, as QuakeLevel.get_lightmap_layers() gives them.
@export var layers: Dictionary

var _animator := QuakeLightStyleAnimator.new()
var _image: Image
var _time := 0.0


static func create(texture: ImageTexture, lightmap_layers: Dictionary) -> QuakeLightStyles:
	var styles := QuakeLightStyles.new()
	styles.name = "LightStyles"
	styles.lightmap = texture
	styles.layers = lightmap_layers
	styles.add_to_group(GROUP, true)
	return styles


func _ready() -> void:
	_animator.setup(layers)
	_image = Image.create_empty(layers.width, layers.height, false, Image.FORMAT_RGBA8)


func _process(delta: float) -> void:
	_time += delta
	if _animator.update(_time):
		_image.set_data(_image.get_width(), _image.get_height(), false, Image.FORMAT_RGBA8, _animator.get_rgba())
		lightmap.update(_image)


## Quake's lightstyle(): one letter per tenth of a second, "a" is dark, "m" normal, "z" double. A switchable
## light goes off with "a" and on with "m".
func set_style(style: int, pattern: String) -> void:
	_animator.set_style(style, pattern)


func get_style(style: int) -> String:
	return _animator.get_style(style)
