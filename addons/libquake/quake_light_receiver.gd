class_name QuakeLightReceiver
extends Node
## Samples the QuakeLightGrid at the parent and sets the instance uniform quake_light on everything below
## model. Their materials use shaders/quake_model.gdshaderinc.

const PARAMETER := &"quake_light"

@export var model: Node3D
## Relative to the parent.
@export var offset := Vector3(0.0, 0.25, 0.0)
@export var brightness := 1.0
## Quake's weapon minlight, 24 of 128, is about 0.2.
@export var minimum_light := 0.0
@export var smoothing := 8.0

var light := Color.WHITE

var _grid: QuakeLightGrid
var _geometry: Array[GeometryInstance3D] = []


func _ready() -> void:
	model.child_entered_tree.connect(_refresh_geometry.unbind(1), CONNECT_DEFERRED)
	model.child_exiting_tree.connect(_refresh_geometry.unbind(1), CONNECT_DEFERRED)
	_refresh_geometry()


func _process(delta: float) -> void:
	if not _grid:
		_grid = get_tree().get_first_node_in_group(QuakeLightGrid.GROUP)
		if not _grid:
			return
	var point: Vector3 = get_parent().global_position + offset
	light = light.lerp(_grid.sample(point), 1.0 - exp(-smoothing * delta))
	var value := _model_light()
	for geometry in _geometry:
		geometry.set_instance_shader_parameter(PARAMETER, value)


## Raised to minimum_light, keeping the color.
func _model_light() -> Vector3:
	var value := Vector3(light.r, light.g, light.b) * brightness
	var strength := maxf(value.x, maxf(value.y, value.z))
	if strength >= minimum_light:
		return value
	return Vector3.ONE * minimum_light if strength <= 0.0 else value * (minimum_light / strength)


## Models may be added later, e.g. a weapon.
func _refresh_geometry() -> void:
	_geometry.clear()
	_collect_geometry(model)


func _collect_geometry(node: Node) -> void:
	if node is GeometryInstance3D:
		_geometry.append(node)
	for child in node.get_children():
		_collect_geometry(child)
