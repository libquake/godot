class_name QuakeSwitchableLight
extends Marker3D
## A light entity with a targetname: firing it switches its light like Quake's light_use. It starts off
## with spawnflag 1. The import gives it the style the bake gave its targetname, 32 and up.

const START_OFF := 1

@export var style := 0

var _on := true


func _ready() -> void:
	_on = not QuakeEntity.has_spawnflag(self, START_OFF)
	_switch()


func _quake_triggered(_activator: Node) -> void:
	_on = not _on
	_switch()


## Style numbers belong to a map; maps baked together by one QuakeLightmap may share them.
func _switch() -> void:
	get_tree().call_group(QuakeLightStyles.GROUP, &"set_style", style, "m" if _on else "a")
