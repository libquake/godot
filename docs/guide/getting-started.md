# Getting started

## Set up the project

**Project > Tools > Set up libquake Project** fills in what a project needs to make maps and leaves what is
there alone, so it can run again:

- the folders `res://maps`, `res://textures` and `res://fog_styles`
- an empty entity class resource `res://entity_classes.tres`, see [Entities](entities.md)
- the [import options](../reference/import-options.md) pointing to them
- the TrenchBroom game config, see below

It says what it did and whether TrenchBroom was found (`libquake/trenchbroom/executable` in the project
settings).

## TrenchBroom

**Project > Tools > Export TrenchBroom Game Config** writes a game named like the project into TrenchBroom's
games folder:

| | |
|---|---|
| macOS | `~/Library/Application Support/TrenchBroom/games` |
| Windows | `%APPDATA%\TrenchBroom\games` |
| Linux | `~/.TrenchBroom/games` |

It holds `GameConfig.cfg`, the FGD of the project's entity classes and an icon. The project folder becomes the
game path unless TrenchBroom has one already, so TrenchBroom shows the images of `res://textures` and maps can
be saved anywhere in the project. Quit TrenchBroom before exporting, it writes its preferences when it quits.

The export runs again by itself whenever the entity classes or one of their scripts are saved. In
TrenchBroom, *File > Reload Entity Definitions* picks it up.

## The first map

In the FileSystem dock, right click a folder and pick *Create > Quake Map...*: a new map opens in TrenchBroom.
Draw some brushes, put down an `info_player_start` and a few `light`s, save. Godot imports the map right away;
drag it into a scene like any other scene.

A right click on a map opens it in TrenchBroom again. With `libquake/editor/watch_maps` on (the default) a
saved map is reimported while Godot is in the background too.

After every import, warnings name what did not resolve: missing textures, point entities without an entity
class and targets no entity answers to. They are shown once as a toast and stay in the inspector of the
placed map.

## Textures

Keep the textures as images in `res://textures`, where TrenchBroom finds them, or name wads in the
worldspawn key `wad`. See [Textures](textures.md).

## Next

- [Maps](maps.md): what an imported map is made of, mesh libraries, the map inspector
- [Lighting](lighting.md): baked light, light styles, models, baking in Godot and in the game
- [Entities](entities.md): entity classes, keys as `@export` variables, scripting
- [Effects](effects.md): underwater view and ground fog
