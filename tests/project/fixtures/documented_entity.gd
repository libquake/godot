@tool
extends "res://fixtures/documented_base.gd"
## Slides open.
## Second line.

## Seconds before closing.
@export var wait := 3.0
## Units it sticks out.
@export_range(0.0, 64.0)
var lip := 8.0
@export var bare := 1
## Not a key, no export.
var hidden := 0
