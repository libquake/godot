@tool
class_name QuakeLightmapData
extends Resource
## What a QuakeLightmap baked. Paths are relative to the QuakeLightmap.

@export var texture: Texture2D
@export var meshes: Array[NodePath] = []
## Per mesh: where its UV2 lands in texture, scale xy and offset zw.
@export var uv_transforms := PackedVector4Array()
## CSG shapes by path: their mesh with UV2, drawn in their place.
@export var csg_meshes: Dictionary[NodePath, Mesh] = {}
## One RGBA layer per light style for QuakeLightStyles, empty without animated styles.
@export var layers: Dictionary = {}
## The Light3D nodes in the bake, switched off while it is applied so they do not light twice.
@export var lights: Array[NodePath] = []

@export_group("Light Grid")
@export var grid_origin := Vector3.ZERO
@export var grid_cell_size := 0.0
@export var grid_size := Vector3i.ZERO
@export var grid_rgb := PackedByteArray()
