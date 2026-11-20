# Import options

Each map has its options in the Import dock. Their defaults for new maps are in *Project Settings > libquake*,
**Set up libquake Project** fills in the folders. A changed option reimports the map.

## Geometry

| Option | Default | |
|---|---|---|
| `geometry/units_per_meter` | 32 | Quake units per meter, the Quake player is 1.75 m tall. Kept on the `QuakeMap` |
| `geometry/csg` | on | removes faces hidden inside other brushes: of the same entity, and across worldspawn, `func_group` and `func_detail` as the Quake compilers do |
| `geometry/pivot` | Bottom Center | origin of brush entities: Map Origin, Center, Bottom Center, Bottom Corner. An `origin` brush or the key `_pivot` (`origin`, `center`, `bottom`, `corner`) wins |

## Lighting

| Option | Default | |
|---|---|---|
| `lighting/bake` | on | bakes the map's lights (`.map` only, a `.bsp` brings its lightmap) |
| `lighting/luxel_size` | 16 | map units per lightmap texel, 16 matches Quake |
| `lighting/sky_samples` | 64 | suns per sky dome (`_sunlight2`, `_sunlight3`), fewer bake faster |
| `lighting/bounces` | -1 | times light bounces off surfaces, -1 as the map's `_bounce` says |
| `lighting/bounce_scale` | -1 | brightness of the bounced light, -1 as the map's `_bouncescale` says; lower it for maps lit without bounce |
| `lighting/bounce_subdivision` | 64 | map units per patch that bounces light, larger bake faster |
| `lighting/luxel_samples` | 1 | samples per luxel along each side, 2 or 4 for smoother shadow edges; costs 4 or 16 times |
| `lighting/dirt` | -1 | ambient occlusion: -1 as the map's `_dirt` says, 0 none, 1 everywhere |
| `lighting/dirt_scale` | -1 | strength of the ambient occlusion, -1 as the map's `_dirtscale` says |
| `lighting/dirt_samples` | 48 | rays per sample for ambient occlusion, fewer bake faster |
| `lighting/light_grid_cell_size` | 1 | meters between the points that light models, 0 leaves the grid out |

## Surfaces

| Option | Default | |
|---|---|---|
| `surfaces/draw_sky` | on | off for maps that are not sealed and show the `WorldEnvironment`'s sky instead |
| `surfaces/water_alpha`, `slime_alpha`, `lava_alpha`, `teleport_alpha` | 0.6, 0.7, 0.85, 1 | how much liquids cover; the worldspawn keys `_wateralpha`, `_slimealpha`, `_lavaalpha`, `_telealpha` win |
| `surfaces/fullbright_energy` | 1 | brightness of fullbright pixels; above the `Environment`'s `glow_hdr_threshold` they bloom |

## Textures

| Option | Default | |
|---|---|---|
| `textures/texture_directories` | `res://textures` | folders of image textures, like TrenchBroom's `textures` folder; they come before the wads |
| `textures/wad_directories` | | folders of `.wad` files outside the project; the project's own wads are always found |
| `textures/sky_directories` | `res://textures/env` | folders of skybox images, named by the worldspawn key `sky` as in a mod's `gfx/env` |

## Entities

| Option | Default | |
|---|---|---|
| `entities/entity_classes` | | a `QuakeEntityClasses` resource, see [Entities](../guide/entities.md) |
| `entities/ground_fog_styles` | | folders of `QuakeGroundFogStyle`s besides libquake's own; they win on the same name |

## Editor

| Option | Default | |
|---|---|---|
| `editor/show_hulls` | off | the collision of brushes in the editor; triggers (orange) and liquids (blue) show either way |

## Pieces

Only for maps of pieces, see [Maps](../guide/maps.md#pieces).

| Option | Default | |
|---|---|---|
| `pieces/save_as` | Scenes | what each piece is saved as: a scene of a `MeshInstance3D` with its collision, or the bare mesh |
| `pieces/folder` | | where the pieces go; empty is a folder named like the map next to it |

Pieces have no lighting, entities and editor options, a level no pieces options.

## Project settings

Besides the defaults above, *Project Settings > libquake* has:

| Setting | Default | |
|---|---|---|
| `libquake/editor/watch_maps` | on | reimports a saved map at once, also with Godot in the background |
| `libquake/trenchbroom/executable` | TrenchBroom's usual place | for *Open in TrenchBroom* and **Set up libquake Project** |
