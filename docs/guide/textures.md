# Textures

For every texture a map uses, the import takes the first of:

1. an image in the `textures/texture_directories` (`res://textures`): `textures/base/wall1.png` is
   `base/wall1`, and `wall1` too. Liquids may be written with `#` instead of `*` (`#water1.png`). The
   material uses the imported texture itself, so a changed image shows without reimporting the map.
2. a wad: every `.wad` in the project counts, wherever it is, and those in `textures/wad_directories`, which
   may be outside the project. The wads named in the worldspawn key `wad` come first, found by their file name
   in any case, whatever path the key has from the mapper's machine. A texture none of them has is looked for in
   all the others by its name. A `.bsp` brings its own textures.
3. a grey grid, `textures/missing_texture.jpg`; the uvs follow its size of 128 pixels. The import's warnings
   name the texture.

| Next to `wall1.png` | |
|---|---|
| `wall1_luma.png` or `wall1_glow.png` | the glowing pixels, as in Quakespasm and ironwail |
| `sky1_front.png` | the cloud layer of the sky `sky1`, without it the sky is one layer |

## Wads

Textures from a wad keep Quake's palette: fullbright pixels glow, skies are split into their two layers.

A `.wad` in the project imports as a `QuakeWadTextures`, the names, sizes and previews of its textures: the
FileSystem dock lists it, and selecting it shows its textures in the **Quake** panel at the bottom of the editor.
Maps do not use the import, they read the wad itself.

**Extract WAD Textures** in the wad's context menu, the Quake panel or *Project > Tools* turns a wad into image
files, `textures/<wad>/<name>.png` with `#` for `*`, `_luma` and `_front` next to them. TrenchBroom then shows them without the wad, and they can be
edited like any image. `QuakeWadExtractor.extract(wad_path, directory)` does the same from a script.

## How surfaces are drawn

Brushes are drawn like Quake does it: texture times lightmap in gamma space, nearest filtering, fullbright
pixels unaffected by the light. `surfaces/fullbright_energy` sets how bright they are; above the
`Environment`'s `glow_hdr_threshold` they bloom.

| Texture | |
|---|---|
| `sky*` | Quake's scrolling two-layer sky, unless `surfaces/draw_sky` is off |
| `*water`, `*slime`, `*lava`, `*tele` | warped liquids, covering by `surfaces/*_alpha` or the worldspawn keys `_wateralpha`, ... |
| `{name` | a hole where the palette's last color is, or the image is transparent |
| `clip` | not drawn, collides |
| `trigger`, `skip`, `hint`, `nodraw`, `caulk`, `origin` | not drawn |
