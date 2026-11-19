class_name QuakeSwitchableLight
extends Marker3D
## A light with a targetname, firing it switches it like Quake's light_use. Spawnflag 1 starts it off.

const START_OFF := 1

@export var style := 0

var _on := true


func _ready() -> void:
	_on = not QuakeEntity.has_spawnflag(self, START_OFF)
	_switch()


func _quake_triggered(_activator: Node) -> void:
	_on = not _on
	_switch()


## Style numbers belong to a map, maps baked together may share them.
func _switch() -> void:
	get_tree().call_group(QuakeLightStyles.GROUP, &"set_style", style, "m" if _on else "a")
