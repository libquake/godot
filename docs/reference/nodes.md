# Nodes and resources

## Maps

| Class | |
|---|---|
| `QuakeMap` (`Node3D`) | root of an imported map. `units_per_meter`, `import_warnings`, `find_entities(classname)`, `find_targets(targetname)`, `apply_skill(skill, deathmatch)`. `QuakeMap.of(node)` is the map a node belongs to |
| `QuakeEntity` | static helpers for the nodes of entities: `properties`, `get_string`, `get_int`, `get_float`, `get_vector`, `get_color`, `has_spawnflag`, `meters`, `units_per_meter`, `fire` |
| `QuakeEntityClasses` (`Resource`) | the entity classes of a project, `find(classname)`, `to_fgd()`, **Export to TrenchBroom** |
| `QuakeEntityClass` (`Resource`) | one class: `classname`, `type`, `scene`, `node_script`, `exclude`, `properties`, `property_descriptions`, `description`, `color`, `size` |
| `QuakeSwitchableLight` (`Marker3D`) | a `light` with a `targetname`, firing it switches its `style` |

## Light

| Class | |
|---|---|
| `QuakeLightmap` (`Node3D`) | bakes everything below its parent, see [Baking in Godot](../guide/lighting.md#baking-in-godot). `bake()`, `bake_to(path)`, `is_baking()`, `data` |
| `QuakeLightmapData` (`Resource`) | the result of a bake: the lightmap, its layers, where each surface is in it, a light grid |
| `QuakeLightStyles` (`Node`) | animates the light styles of a lightmap. `set_style(style, pattern)`, `get_style(style)` |
| `QuakeLightGrid` (`Node`) | the level's light for models. `sample(global_point)` |
| `QuakeLightReceiver` (`Node`) | lights the `model` below it from the grid: `offset`, `brightness`, `minimum_light`, `smoothing`; sets the instance uniform `quake_light` |
| `QuakeLightBaker` (`RefCounted`) | the baker: `add_surface`, `add_occluder`, `add_light`, `add_quake_entities`, `bake`, then `get_lightmap_image`, `get_lightmap_layers`, `get_surface_uv_transform`, `build_light_grid` |

## Effects

| Class | |
|---|---|
| `QuakeUnderwaterEffect` (`CanvasLayer`) | the view inside liquids, for its `camera` |
| `QuakeGroundFog` (`Node3D`) | ground fog in a box of `size`, with a `style`. **Drop to Floor**, `floor_below()`, `fit(bounds)` |
| `QuakeGroundFogStyle` (`Resource`) | the look of ground fog, see [Ground fog](../guide/effects.md#styles). `QuakeGroundFogStyle.find(name)`, `names()` |

## Files

| Class | |
|---|---|
| `QuakeLevel` (`RefCounted`) | libquake's level: `load(path)`, then geometry, entities, textures and lightmap. What the importers use |
| `QuakeWad` (`RefCounted`) | a wad: `load(path)`, `get_texture_names()`, `get_texture_image(name)`, `get_texture_emission(name)`, `get_sky_front_image(name)` |
| `QuakeWadExtractor` | `extract(wad_path, directory)`, the image files of **Extract WAD Textures** |
| `QuakePieces` (`Resource`) | what a map of pieces imports as: `names`, `files`, `previews` of its pieces, `find(name)` |
| `QuakeWadTextures` (`Resource`) | what a `.wad` imports as: `names`, `sizes`, `previews` of its textures |

## Shaders

| File | |
|---|---|
| `shaders/quake_world.gdshader` | brushes: texture times lightmap, fullbright pixels |
| `shaders/quake_liquid.gdshader`, `quake_sky.gdshader` | warped liquids, the two-layer sky |
| `shaders/quake_model.gdshader`, `quake_model.gdshaderinc` | models lit by `QuakeLightReceiver` |
| `shaders/quake_dynamic_light.gdshaderinc` | Godot lights the way the light tools light |
| `shaders/quake_ground_fog.gdshader`, `quake_underwater.gdshader` | the effects |
