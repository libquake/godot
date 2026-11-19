# Lighting

## Baked on import

A `.map` is lit when it is imported: libquake bakes its `light` entities the way the Quake light tools do it,
with Quake's keys (`light`, `_color`, `wait`, `delay`, `mangle` for spotlights) and the worldspawn's
`_sunlight`, `_sun_mangle`, `_sunlight_color`, `_minlight` and the sky domes `_sunlight2` and `_sunlight3`
(light from the whole sky, with `_sunlight2_color` and `_sunlight3_color`). `lighting/luxel_size` sets the map
units per lightmap texel, 16 matches Quake, `lighting/sky_samples` the suns per sky dome. A `.bsp` brings its
lightmap.

The light is emitted by the surfaces. The `Environment`'s ambient light does not add to it, the baked light
covers that; Godot's lights do, see [Dynamic lights](#dynamic-lights).

## Light styles

Lights with a `style` flicker or pulse like in Quake. Lights with a `targetname` become
`QuakeSwitchableLight`s: [firing](entities.md#firing-targets) one switches it, spawnflag 1 starts it off. The
bake gives every such targetname its own style from 32 up.

A map with such lights gets a `LightStyles` node (`QuakeLightStyles`): in the game it composes the lightmap
from its layers ten times a second, rewriting only the texels of styles that changed. The editor shows the
lightmap at rest.

`set_style(style, pattern)` is Quake's `lightstyle()`: one letter per tenth of a second, `a` dark, `m` normal,
`z` double.

```gdscript
var styles: QuakeLightStyles = map.get_node("LightStyles")
styles.set_style(32, "a")     # the first switchable light goes dark
styles.set_style(1, "mmamammmmammamamaaamammma")
```

## Models

A `LightGrid` node (`QuakeLightGrid`) holds the level's light on a grid of `lighting/light_grid_cell_size`
meters, read the way Quake lights its models: straight down from each point, from the lightmap where it hits
the floor. A `QuakeLightReceiver` next to a model samples it every frame and sets the instance uniform
`quake_light` on every `GeometryInstance3D` below its `model`.

The model's material reads it through `shaders/quake_model.gdshaderinc`. `shaders/quake_model.gdshader` covers
the usual case, texture times color; for a shader of your own:

```glsl
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;

#include "res://addons/libquake/shaders/quake_model.gdshaderinc"

uniform sampler2D albedo_texture : filter_nearest_mipmap;

void fragment() {
	vec3 albedo = texture(albedo_texture, UV).rgb;
	EMISSION = quake_model_color(albedo, NORMAL);
	ALBEDO = quake_srgb_to_linear(albedo);
}

void light() {
	DIFFUSE_LIGHT += quake_dynamic_light(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
```

Colors stay gamma encoded (no `source_color`), like Quake did the math. With `render_mode unshaded`,
`ALBEDO = quake_model_color(...)` and no `light()`, the model ignores Godot's lights.

## Dynamic lights

Godot's `OmniLight3D`, `SpotLight3D` and `DirectionalLight3D` add to the baked light of levels and models, for
what Quake did with dynamic lights: muzzle flashes, rockets, explosions.
`shaders/quake_dynamic_light.gdshaderinc` lights without specular and with half the angle, like the light
tools. Level meshes cast shadows, so lights with `shadow_enabled` stop at walls.

A light only exists for cameras that see one of its `layers`. A weapon drawn by its own camera on its own
layer needs that layer on the light as well.

## Baking in Godot

A level put together in Godot, from imported maps, pieces and models, gets its light from a
`QuakeLightmap` node with the same baker. Like `LightmapGI` it covers its parent and everything below it:
select it and press **Bake Quake Light** in the 3D editor's toolbar. The result is saved next to the scene as
`<scene>.lightmap.res` and applied when the scene loads; clear `data` to remove it.

The bake runs in a thread, the editor keeps working and the last bake stays visible until the new one is done.
With `auto_bake` on, the editor bakes by itself once the scene has not changed for `auto_bake_delay` seconds,
and after a map of the scene was reimported.

What is baked:

- **Meshes**: visible `MeshInstance3D`s with `gi_mode` Static and UV2, and root CSG shapes, which get UV2
  when they are baked. Meshes below a `RigidBody3D` or `CharacterBody3D` move and are left out; doors
  (`AnimatableBody3D`) are lit where they stand. Surfaces with a Quake world material or a
  `StandardMaterial3D` get the lightmap, every other surface only casts shadows. Liquids let light through,
  sky only lets the sun in. Brush entities cast shadows with the key `_shadow 1`.
- **Lights**, each group with its own switch: `Light3D`s with `light_bake_mode` Static (`godot_lights`), the
  `light*` entities of imported maps (`quake_lights`) and their worldspawn (`worldspawn`). A Godot light with
  energy 1 is a Quake light of `light_intensity` (300) fading out linearly at its range, with shadows if
  `shadow_enabled` is on. Baked Godot lights are switched off while the bake is applied.
- `ambient_light` is added everywhere, `minimum_light` raises dark spots like `_minlight`.
- `luxel_size` (16 map units) for the brushes of imported maps, `mesh_luxel_size` (2) for every other mesh,
  scaled by its `gi_lightmap_texel_scale`.
- Quality: `sky_samples` (64) suns per sky dome, fewer bake faster.
- Models are lit by a light grid built from the bake, it replaces the grids of the maps it covers.

GridMaps are not baked, their cells are no nodes of their own.

### In the game

The game can bake too, for a level put together while loading, such as the rooms of a dungeon generator, or a
map a player made:

```gdscript
await lightmap.bake_to()                                   # applied, not saved
await lightmap.bake_to("user://levels/42.lightmap.res")    # applied and kept
lightmap.data = load("user://levels/42.lightmap.res")      # next time
```

One `QuakeLightmap` above all rooms bakes them together, so light reaches across them; the rooms bring none of
their own. Two Quake episode maps side by side bake in about a third of a second.

### The baker on its own

`QuakeLightBaker` does the work and can be used without a `QuakeLightmap`: add surfaces (world positions,
normals, UV2), occluders and lights, `bake()`, then read the image, every surface's place in it and a light
grid.
