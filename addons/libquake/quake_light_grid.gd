@tool
class_name QuakeLightGrid
extends Node
## The level's light on a regular grid, sampled the way Quake lights its models: straight down from each
## point, read from the lightmap where it hits the floor. QuakeLightReceiver reads it.

const GROUP := &"quake_light_grid"

@export var origin := Vector3.ZERO
@export var cell_size := 1.0
@export var size := Vector3i.ZERO
## RGB per point, x fastest then z then y. 128 is normal brightness.
@export var rgb := PackedByteArray()


static func from_level(level: QuakeLevel, grid_cell_size: float) -> QuakeLightGrid:
	var data := level.build_light_grid(grid_cell_size)
	var grid := QuakeLightGrid.new()
	grid.name = "LightGrid"
	grid.origin = data.origin
	grid.cell_size = data.cell_size
	grid.size = data.size
	grid.rgb = data.rgb
	grid.add_to_group(GROUP, true)
	return grid


## Light at a point in world space, trilinear between the grid points. 1.0 is normal brightness.
func sample(global_point: Vector3) -> Color:
	if rgb.is_empty():
		return Color.WHITE
	var level := get_parent() as Node3D
	var point := level.to_local(global_point) if level else global_point
	var cell := ((point - origin) / cell_size).clamp(Vector3.ZERO, Vector3(size - Vector3i.ONE))
	var base := Vector3i(cell.floor()).min(size - Vector3i(2, 2, 2)).max(Vector3i.ZERO)
	var weight := cell - Vector3(base)

	var result := Color(0, 0, 0)
	for corner in 8:
		var offset := Vector3i(corner & 1, (corner >> 1) & 1, (corner >> 2) & 1)
		var corner_weight := (
			(weight.x if offset.x else 1.0 - weight.x)
			* (weight.y if offset.y else 1.0 - weight.y)
			* (weight.z if offset.z else 1.0 - weight.z))
		result += _point(base + offset) * corner_weight
	return result


func _point(index: Vector3i) -> Color:
	var offset := ((index.y * size.z + index.z) * size.x + index.x) * 3
	const SCALE := 2.0 / 255.0
	return Color(rgb[offset] * SCALE, rgb[offset + 1] * SCALE, rgb[offset + 2] * SCALE)
