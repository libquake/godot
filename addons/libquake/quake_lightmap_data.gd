@tool
class_name QuakeLightmapData
extends Resource
## Paths are relative to the QuakeLightmap.

@export var texture: Texture2D
@export var meshes: Array[NodePath] = []
## Per mesh: UV2 scale xy and offset zw in texture.
@export var uv_transforms := PackedVector4Array()
## CSG shapes by path: their mesh with UV2.
@export var csg_meshes: Dictionary[NodePath, Mesh] = {}
## One RGBA layer per light style, empty without animated styles.
@export var layers: Dictionary = {}
## Switched off while applied, so they do not light twice.
@export var lights: Array[NodePath] = []

@export_group("Light Grid")
@export var grid_origin := Vector3.ZERO
@export var grid_cell_size := 0.0
@export var grid_size := Vector3i.ZERO
@export var grid_rgb := PackedByteArray()
