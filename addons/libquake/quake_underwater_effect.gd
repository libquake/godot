class_name QuakeUnderwaterEffect
extends CanvasLayer
## Tints, wobbles and fogs the view while the camera is inside a liquid of an imported Quake level.

const SHADER := preload("shaders/quake_underwater.gdshader")

@export var camera: Camera3D

var _overlay: ColorRect
var _material: ShaderMaterial
var _kind := ""
var _dry_fog := {}


func _ready() -> void:
	layer = 0
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_overlay = ColorRect.new()
	_overlay.material = _material
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.hide()
	add_child(_overlay)


func _physics_process(_delta: float) -> void:
	var liquid := _liquid_at(camera.global_position)
	var kind: String = liquid.get_meta(QuakeLiquids.KIND_META, "") if liquid else ""
	if not QuakeLiquids.VIEWS.has(kind):
		kind = ""
	if kind == _kind:
		return
	_kind = kind
	if kind.is_empty():
		_leave_liquid()
	else:
		_enter_liquid(liquid)


func _enter_liquid(liquid: Node) -> void:
	var view: Dictionary = QuakeLiquids.VIEWS[_kind]
	var color: Color = liquid.get_meta(QuakeLiquids.COLOR_META, QuakeLiquids.FALLBACK_COLORS[_kind])
	_material.set_shader_parameter(&"shift_color", Vector3(color.r, color.g, color.b))
	_material.set_shader_parameter(&"shift", view.shift)
	_overlay.show()

	var environment := _environment()
	if not environment:
		return
	if _dry_fog.is_empty():
		_dry_fog = {
			"enabled": environment.fog_enabled,
			"color": environment.fog_light_color,
			"density": environment.fog_density,
		}
	environment.fog_enabled = true
	environment.fog_light_color = color
	environment.fog_density = view.fog_density


func _leave_liquid() -> void:
	_overlay.hide()
	var environment := _environment()
	if environment and not _dry_fog.is_empty():
		environment.fog_enabled = _dry_fog.enabled
		environment.fog_light_color = _dry_fog.color
		environment.fog_density = _dry_fog.density
	_dry_fog = {}


func _liquid_at(point: Vector3) -> Node:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = point
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in camera.get_world_3d().direct_space_state.intersect_point(query):
		if hit.collider.is_in_group(QuakeLiquids.GROUP):
			return hit.collider
	return null


func _environment() -> Environment:
	return camera.get_world_3d().environment
