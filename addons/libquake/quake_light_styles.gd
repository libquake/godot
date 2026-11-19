class_name QuakeLightStyles
extends Node
## Animates a lightmap's light styles in the game, switchable ones from 32 up.

const GROUP := &"quake_light_styles"

@export var lightmap: ImageTexture
## One RGBA layer per style.
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


## Quake's lightstyle(): a letter per tenth of a second, "a" dark, "m" normal, "z" double.
func set_style(style: int, pattern: String) -> void:
	_animator.set_style(style, pattern)


func get_style(style: int) -> String:
	return _animator.get_style(style)
