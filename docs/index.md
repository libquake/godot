# LibQuake for Godot

Godot 4 plugin that imports Quake 1 `.map` and `.bsp` files as assets. A map becomes a scene with meshes drawn
the way Quake draws them, light baked by libquake, collision per brush and one node per entity. It is built on
[libquake](https://github.com/libquake/libquake), which does the parsing, CSG, uvs and light baking.

Edit the map in [TrenchBroom](https://trenchbroom.github.io), save, and Godot reimports it, also while the
editor is in the background. There is no build step and no extra node to press.

| | |
|---|---|
| Godot | 4.5 or newer, tested with Forward+ |
| Platforms | Windows x86_64, macOS (universal), Linux x86_64, in the editor and in exported games |
| Status | experimental |

## Install

Copy `addons/libquake` from the [repository](https://github.com/libquake/godot) into the project and enable
**libquake** under *Project > Project Settings > Plugins*. The binaries for all three platforms are in
`addons/libquake/bin`, built for every libquake release.

Then run **Project > Tools > Set up libquake Project**, see [Getting started](guide/getting-started.md).

## What gets imported

| File | Becomes |
|---|---|
| `.map` | a scene with a `QuakeMap` root: meshes per texture, collision per brush, baked light, a node per entity |
| `.map` with `_meshlib 1` | a `MeshLibrary` for GridMaps, one item per TrenchBroom group |
| `.bsp` | the same scene, with the bsp's textures, lightmap and face collision |
| `textures/*.png` | read by the maps that use them, nothing has to be imported by hand |
| `.wad` | read by the maps that name it; **Extract WAD Textures** turns it into images |

Besides importing, the plugin lights models like Quake does, animates light styles, bakes light for levels put
together in Godot, in the editor or while the game runs, and brings an underwater view and ground fog.

Start with [Getting started](guide/getting-started.md). The options of a map are in the
[import options](reference/import-options.md), the nodes and resources in the [reference](reference/nodes.md).
