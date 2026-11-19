@tool
class_name QuakeMaterials
extends RefCounted
## One material per texture, from image files first, then wads or the bsp. QUAKE uses the baked lightmap,
## GODOT is a StandardMaterial3D lit by Godot. Sky and liquids look like Quake in both.

enum Style { QUAKE, GODOT }

const WORLD_SHADER := preload("shaders/quake_world.gdshader")
const SKY_SHADER := preload("shaders/quake_sky.gdshader")
const SKYBOX_SHADER := preload("shaders/quake_skybox.gdshader")
const LIQUID_SHADER := preload("shaders/quake_liquid.gdshader")
const MISSING_TEXTURE_PATH := "res://addons/libquake/textures/missing_texture.jpg"

## Above 1 fullbright pixels bloom.
var fullbright_energy := 1.0

## Null for the Godot style.
var lightmap: ImageTexture
## The six images of a skybox (QuakeSkybox), sky surfaces draw it instead of Quake's two layers.
var skybox := {}
## Shown with the missing texture.
var missing_textures := PackedStringArray()

var _level: QuakeLevel
var _files: QuakeTextureFiles
var _style: Style
var _liquid_alphas: Dictionary
var _materials := {}
var _liquid_colors := {}


## liquid_alphas: kind ("water", "slime", "lava", "teleport") -> alpha
func _init(level: QuakeLevel, files: QuakeTextureFiles, style: Style, liquid_alphas: Dictionary) -> void:
	_level = level
	_files = files
	_style = style
	_liquid_alphas = liquid_alphas
	if style == Style.QUAKE:
		lightmap = ImageTexture.create_from_image(level.get_lightmap_image())


func get_material(texture_name: String) -> Material:
	if not _materials.has(texture_name):
		if texture_name.to_lower().begins_with("sky"):
			_materials[texture_name] = _sky(texture_name)
		elif QuakeLiquids.is_liquid(texture_name):
			_materials[texture_name] = _liquid(texture_name)
		elif _style == Style.QUAKE:
			_materials[texture_name] = _quake_surface(texture_name)
		else:
			_materials[texture_name] = _godot_surface(texture_name)
	return _materials[texture_name]


## Tints the view inside the liquid.
func liquid_color(texture_name: String) -> Color:
	if _liquid_colors.has(texture_name):
		return _liquid_colors[texture_name]
	var color: Color = QuakeLiquids.FALLBACK_COLORS[QuakeLiquids.kind_of(texture_name)]
	var albedo := _albedo(texture_name)
	if albedo:
		var image := albedo.get_image()
		image.decompress()
		var sum := Color(0, 0, 0, 0)
		for y in image.get_height():
			for x in image.get_width():
				sum += image.get_pixel(x, y)
		color = sum / float(image.get_width() * image.get_height())
		color.a = 1.0
	_liquid_colors[texture_name] = color
	return color


func _quake_surface(texture_name: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WORLD_SHADER
	material.set_shader_parameter(&"albedo_texture", _albedo(texture_name, true))
	material.set_shader_parameter(&"emission_texture", _emission(texture_name))
	material.set_shader_parameter(&"lightmap_texture", lightmap)
	material.set_shader_parameter(&"fullbright_energy", fullbright_energy)
	return material


## Matte, sharp pixels, glowing fullbrights.
func _godot_surface(texture_name: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = _albedo(texture_name, true)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.roughness = 1.0
	material.metallic_specular = 0.0
	if texture_name.begins_with("{"):
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var emission := _emission(texture_name)
	if emission:
		material.emission_enabled = true
		material.emission_texture = emission
		material.emission_energy_multiplier = fullbright_energy
	return material


func _sky(texture_name: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	if not skybox.is_empty():
		material.shader = SKYBOX_SHADER
		for suffix: String in skybox:
			material.set_shader_parameter(suffix, skybox[suffix])
		return material
	material.shader = SKY_SHADER
	material.set_shader_parameter(&"back_layer", _albedo(texture_name))
	var front := _files.sky_front(texture_name)
	material.set_shader_parameter(&"front_layer", front if front else _image_texture(_level.get_sky_front_image(texture_name)))
	return material


func _liquid(texture_name: String) -> ShaderMaterial:
	var kind := QuakeLiquids.kind_of(texture_name)
	var material := ShaderMaterial.new()
	material.shader = LIQUID_SHADER
	material.set_shader_parameter(&"albedo_texture", _albedo(texture_name))
	material.set_shader_parameter(&"alpha", _liquid_alphas.get(kind, 1.0))
	material.set_shader_parameter(&"brightness", QuakeLiquids.BRIGHTNESS.get(kind, 1.0))
	return material


func _albedo(texture_name: String, mipmaps := false) -> Texture2D:
	if _files.has(texture_name):
		return _files.texture(texture_name)
	var image := _level.get_texture_image(texture_name)
	if image:
		return _image_texture(image, mipmaps)
	if not missing_textures.has(texture_name):
		missing_textures.append(texture_name)
	return missing_texture()


func _emission(texture_name: String) -> Texture2D:
	if _files.has(texture_name):
		return _files.emission(texture_name)
	return _image_texture(_level.get_texture_emission(texture_name), true)


static func _image_texture(image: Image, mipmaps := false) -> Texture2D:
	if not image:
		return null
	if mipmaps:
		image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## A grey grid that still shows the mapping.
## The average of a texture's pixels, what light bounced off it takes on. Gray without a texture.
static func average_color(texture: Texture2D) -> Color:
	var image := texture.get_image() if texture else null
	if not image:
		return Color(0.5, 0.5, 0.5)
	image = image.duplicate()
	if image.is_compressed():
		image.decompress()
	# each halving averages 2 x 2 pixels
	while image.get_width() > 1 or image.get_height() > 1:
		image.shrink_x2()
	var color := image.get_pixel(0, 0)
	color.a = 1.0
	return color


static func missing_texture() -> Texture2D:
	return load(MISSING_TEXTURE_PATH)
