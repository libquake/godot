# Entities

## Entity classes

What an entity becomes is set in a `QuakeEntityClasses` resource, the one in the import option
`entities/entity_classes`. It lists `QuakeEntityClass`es:

| | |
|---|---|
| `classname` | a trailing `*` makes it a prefix: `light*` covers `light`, `light_fluoro`, ... An exact name wins over a prefix, a longer prefix over a shorter one |
| `type` | Point or Brush |
| `scene`, `node_script` | what the entity becomes; the scene wins |
| `exclude` | leaves the entity out |
| `properties` | keys with default values for the FGD, on top of the `@export` variables of the script; the value's type picks the FGD type (int, float, bool, String, Color, Vector3, a `PackedStringArray` for a choice) |
| `property_descriptions`, `description`, `color`, `size` | how TrenchBroom shows it |

Without a description TrenchBroom shows the `##` comment of the script's class, without a property description
that of its `@export` variable, so a documented script needs nothing else.

The same resource is the FGD of the [TrenchBroom game config](getting-started.md#trenchbroom): **Export to
TrenchBroom** on the resource, or saving it or one of its scripts, writes it again. Prefixes are not written to
the FGD. The worldspawn and light keys libquake reads and the brush entities it knows (`func_detail`,
`func_illusionary`, `func_groundfog`, `func_ladder`) are added unless a class defines them.

## Keys are @export variables

The `@export` variables of an entity's script are its keys: they are in the FGD with their type and default,
and the import sets them from the map, parsed to their type. A door needs no more than

```gdscript
extends AnimatableBody3D
## Slides open when fired, closes after wait.

## Units per second.
@export var speed := 100.0
## Seconds before it closes, -1 stays open.
@export var wait := 3.0
```

Keys are in map units like in Quake: `speed`, `lip`, `height`. `QuakeEntity.meters(node, units)` turns them
into meters at the scale of the node's map, so a script never assumes 32 units per meter:

```gdscript
func _ready() -> void:
	var meters_per_second := QuakeEntity.meters(self, speed)
```

For keys without a variable, `QuakeEntity` reads and parses the map's values: `get_string`, `get_int`,
`get_float`, `get_vector`, `get_color` and `has_spawnflag`.

## Firing targets

`QuakeEntity.fire(node, activator)` is Quake's way of connecting entities: after the entity's `delay`, every
entity of the same map whose `targetname` is its `target` gets `_quake_triggered(activator)`, if it has that
method.

```gdscript
func _quake_triggered(activator: Node) -> void:
	open()
```

## Examples

`addons/libquake/examples` scripts four Quake entities this way, `example_entity_classes.tres` maps them:

| Script | Entity | |
|---|---|---|
| `quake_trigger.gd` | `trigger_multiple`, `trigger_once` | a character that enters fires the targets; `trigger_multiple` again after `wait` (0.2 s) |
| `quake_teleport.gd` | `trigger_teleport` | hands a body that enters to the destination it targets |
| `quake_teleport_destination.gd` | `info_teleport_destination` | places the body, turns it, sends it off with Quake's 300 units/s |

Only bodies with a method `teleport(Transform3D)` are teleported: it is their way to say they can be, the world
and doors have none.
