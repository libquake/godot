# Effects

## Underwater

`QuakeUnderwaterEffect`, a `CanvasLayer`, wobbles and tints the view and thickens the fog while its `camera` is
inside a liquid, in the liquid's color. Add one to the scene with the player's camera.

## Ground fog

`QuakeGroundFog` is fog lying on the floor of a box: its top rolls in noise hills, it fades out toward the box's
sides and stays where it was put, so nothing pops in. What stands in the box pokes out of the fog.

A `func_groundfog` brush becomes one the size of its brush's bounds (sloped or turned brushes count as their
bounding box) and is not drawn, any texture will do. Placed in a scene, `size` sets the box; it is centered on
the node and turns with it around Y.

In the editor its gizmo draws the box and, lighter, the height of its style's fog. Dragging the handle on a
side moves that side and keeps the opposite one. **Drop to Floor** in the inspector puts the box's floor on
the collision under its middle. Warnings name a box lower than the fog with its hills, whose top is cut flat,
and one floating above the floor; the import's warnings name the first for `func_groundfog` brushes too.

### Styles

The look is a `QuakeGroundFogStyle`, a resource shared by every fog using it: editing one changes them all at
once, in the editor too.

| | |
|---|---|
| Look | `fog_height`, `top_softness`, `density`, `fog_color`, `edge_fade`, `camera_fade` |
| Hills | `noise_texture` (by default `textures/quake_ground_fog_noise.tres`), `hill_amount`, `hill_scale`, `wind`, `morph_speed` |
| Retro | world aligned fog pixels (`pixel_size`), banded and dithered opacity (`alpha_steps`, `dither`, `dither_scale`), choppy animation (`anim_fps`) |
| Quality | `steps` along the view ray |

Styles are named by their file. libquake brings `ground_fog_styles/default.tres`; the folders of the import
option `entities/ground_fog_styles` add the project's own, and one with the same name wins, so a project can
make its own `default`.

In TrenchBroom the `style` key of a `func_groundfog` chooses among them; saving a style exports the game config
again, *File > Reload Entity Definitions* shows a new one. Without the key, or with a name no style has, the fog
looks like `default` and keeps following it when the project's `default` changes. Unknown names are in the
import's warnings. A `QuakeGroundFog` placed in a scene takes its `style` from the inspector, empty is
`default` the same way.

The shader marches the view ray through the box against the depth buffer. It is tested with Forward+ and does
not read the lightmap.
