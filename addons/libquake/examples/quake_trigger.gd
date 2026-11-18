class_name QuakeTrigger
extends Area3D
## Example of Quake's trigger_multiple and trigger_once: a character that enters fires the trigger's targets.
## trigger_multiple can fire again after "wait" seconds (0.2), trigger_once never again.
## Map it in a QuakeEntityClasses resource: classnames trigger_multiple and trigger_once, node_script this file.

var _available_at := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not body is CharacterBody3D or now < _available_at:
		return
	QuakeEntity.fire(self, body)
	if is_in_group(&"trigger_once"):
		set_deferred(&"monitoring", false)
	else:
		_available_at = now + QuakeEntity.get_float(self, "wait", 0.2)
