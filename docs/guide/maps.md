# Maps

## The imported scene

The root is a `QuakeMap`. Every entity becomes a node named `classname_index`, in a group named after its
classname, with the libquake entity as meta `quake_entity`:

| Key | |
|---|---|
| `classname` | |
| `properties` | the key / value pairs as written in the map |
| `origin` | in Godot coordinates and meters |
| `angles` | pitch, yaw, roll in Quake degrees |
| `move_dir` | Quake's movedir (angle -1 up, -2 down) in Godot coordinates |

Which node an entity becomes is up to its [entity class](entities.md). Without one:

| Entity | Node |
|---|---|
| point entity | `Marker3D` |
| `trigger_*` | `Area3D`, not drawn |
| `func_ladder` | `Area3D` in the group `func_ladder`, not drawn |
| `func_illusionary` | `Node3D`, drawn, no collision |
| `func_groundfog` | `QuakeGroundFog`, see [Ground fog](effects.md#ground-fog) |
| other brush entities | `StaticBody3D` with a convex shape per brush |

`QuakeMap.find_entities(classname)` and `find_targets(targetname)` search one map only.

Triggers are never drawn, like Quake's `InitTrigger` hides them: their brushes may carry any texture, START.MAP
has one with the sky. A `func_ladder` is only the volume to climb: draw the rungs with the wall behind it and
let the volume end a little above the upper floor, so a character climbing out has its feet over the edge.

Liquids are `Area3D`s in the group `quake_liquid` with the meta `quake_liquid_kind` (`water`, `slime`, `lava`)
and `quake_liquid_color`. Teleporter surfaces get an `Area3D` without the group.

Like FitzQuake's `gl_zfix`, the meshes of brush entities other than the world sit 1/32 unit off on every axis,
so a door resting flush with the floor never fights with it: the world wins.

### Scale and pivots

`geometry/units_per_meter` (32) scales the map; the Quake player is 56 units, 1.75 m. The map keeps it in
`QuakeMap.units_per_meter`, `QuakeEntity.meters(node, units)` converts keys in map units.

Brush entities get their origin from an `origin` brush, the key `_pivot` (`origin`, `center`, `bottom`,
`corner`) or `geometry/pivot`.

## bsp files

A `.bsp` keeps no brushes: its faces are the collision, one `ConcavePolygonShape3D` per brush entity, liquids
left out. Clip brushes and liquid volumes are lost in a compiled bsp, so it has neither. It brings its own
textures and lightmap (with a `.lit` file next to it, colored), version 29 and BSP2.

## Mesh libraries

A map of pieces becomes a mesh library with the worldspawn key `_meshlib` set to `1`: the level import
switches the map to the mesh library importer and reimports it. **Import As > Quake Mesh Library** in the
Import dock does the same by hand; switching back to a level is always by hand.

Every TrenchBroom group becomes one item named like the group, brush entities inside it included, with its
pivot as the item's origin. Brush entities outside groups get their own item, loose world brushes the item
`worldspawn`. Bottom Center puts pieces on the floor of a GridMap cell, Bottom Corner snaps pieces of any size
to the grid.

An item's id is derived from its name, so placed GridMaps keep their pieces across reimports as long as the
group names stay. Mesh libraries are lit by Godot: their materials are matte `StandardMaterial3D`s with sharp
pixels.

## In the editor

Selecting a placed map shows its entities in the inspector: a list to filter, the picked entity with its keys,
and `target`, `targetname` and `killtarget` as buttons to the entities on the other end. The viewport marks the
picked entity and draws lines to the entities it fires (orange) and from those that fire it (cyan). Brush
collision stays hidden, triggers show orange and liquids blue (`editor/show_hulls` shows all).

Changing only the plugin does not reimport a map, **Reimport** in the Import dock does.

## Skill levels

`QuakeMap.apply_skill(skill, deathmatch)` removes what the map does not have at a skill (0 easy to 3
nightmare) or in deathmatch, by the spawnflags *not in easy / normal / hard / deathmatch*. Call it before the
level starts.
