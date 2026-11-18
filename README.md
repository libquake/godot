# LibQuake for Godot

![LGBTQ+ Friendly][badge-lgbtq]
![Trans Rights][badge-trans]
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Build](https://github.com/libquake/godot/actions/workflows/build.yml/badge.svg)](https://github.com/libquake/godot/actions/workflows/build.yml)

Godot 4 plugin that imports Quake 1 `.map` and `.bsp` files as assets. A map becomes a scene with meshes drawn
the way Quake draws them, light baked by [libquake](https://github.com/libquake/libquake), collision per brush
and one node per entity. Save in TrenchBroom and Godot reimports it.

Experimental. Godot 4.5 or newer, Windows, macOS and Linux.

## Install

Copy `addons/libquake` into your project and enable **libquake** in the project settings' plugins, then run
**Project > Tools > Set up libquake Project**. The binaries for all three platforms are in
`addons/libquake/bin`.

The documentation is at [libquake.github.io/godot](https://libquake.github.io/godot/), the source is in
[docs/](docs/index.md).

## Building

The extension needs CMake 3.24+ and a C++20 compiler. godot-cpp is fetched by CMake, libquake is taken from a
checkout next to this one (`LIBQUAKE_DIR`).

```sh
git clone https://github.com/libquake/libquake ../libquake
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
```

The library lands in `addons/libquake/bin`.

`LIBQUAKE_VERSION` names the libquake release the committed binaries are built from. A libquake release, or a
push that changes the extension, builds them again for Windows, macOS and Linux and commits them
(`.github/workflows/build.yml`).

## Tests

```sh
tests/run.sh
```

Imports the maps of `tests/project` from scratch and runs every `test_` method in `tests/project/tests`
headless; the exit code is the number of failed tests. An error logged while a test runs fails it.
`GODOT` picks another Godot than the one on the `PATH`.

[badge-trans]: https://pride-badges.pony.workers.dev/static/v1?label=trans%20rights&stripeWidth=6&stripeColors=5BCEFA,F5A9B8,FFFFFF,F5A9B8,5BCEFA
[badge-lgbtq]: https://pride-badges.pony.workers.dev/static/v1?label=lgbtq%2B%20friendly&stripeWidth=6&stripeColors=E40303,FF8C00,FFED00,008026,24408E,732982
