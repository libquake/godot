#pragma once

#include <array>
#include <cstdint>
#include <quakelib/level.h>
#include <vector>

namespace libquake_godot {

  /// Light sampled on a regular grid the way Quake lights models: trace down from each point and read the
  /// lightmap where the trace hits. Engine agnostic, could move into libquake.
  struct LightGrid {
    quakelib::Vec3 origin{0, 0, 0}; ///< the first point, in the coordinates of the floors
    float cellSize = 0;
    int sizeX = 0;
    int sizeY = 0;
    int sizeZ = 0;
    /// RGB per point, x fastest then z then y; lightmap values, 128 is normal brightness
    std::vector<uint8_t> rgb;
  };

  /// A floor for the grid: corners y up and where they are in the lightmap (0..1).
  struct GridFloor {
    std::array<quakelib::Vec3, 3> points;
    std::array<quakelib::Vec2, 3> lightmapUvs;
  };

  /// lightmapRgba is the composed lightmap atlas; geometry is expected y up (ConvertToOpenGL)
  LightGrid BuildLightGrid(const quakelib::Level &level, const std::vector<uint8_t> &lightmapRgba,
                           float cellSize);

  /// floors only face up, a trace going down meets them; lightmapRgba is width x height
  LightGrid BuildLightGrid(const std::vector<GridFloor> &floors, int lightmapWidth, int lightmapHeight,
                           const std::vector<uint8_t> &lightmapRgba, float cellSize);

} // namespace libquake_godot
