#include "light_grid.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <limits>
#include <quakelib/texture_name.h>

namespace libquake_godot {

  namespace {
    struct Hit {
      float height;
      std::array<uint8_t, 3> rgb;
    };

    /// floors only: a trace going down meets surfaces facing up
    std::vector<GridFloor> collectFloors(const quakelib::Level &level) {
      std::vector<GridFloor> floors;
      for (const auto &geometry : level.geometry) {
        for (const auto &mesh : geometry.meshes) {
          if (mesh.type != quakelib::SurfaceType::SOLID || quakelib::IsSkyTexture(mesh.textureName) ||
              quakelib::IsLiquidTexture(mesh.textureName))
            continue;
          for (size_t i = 0; i + 2 < mesh.indices.size(); i += 3) {
            GridFloor floor;
            float up = 0;
            for (int corner = 0; corner < 3; ++corner) {
              const auto &vertex = mesh.vertices[mesh.indices[i + corner]];
              floor.points[corner] = vertex.point + geometry.pivot;
              floor.lightmapUvs[corner] = vertex.lightmap_uv;
              up += vertex.normal.Y;
            }
            if (up > 0.01f)
              floors.push_back(floor);
          }
        }
      }
      return floors;
    }

    std::array<uint8_t, 3> sampleLightmap(int width, int height, const std::vector<uint8_t> &rgba,
                                          quakelib::Vec2 uv) {
      if (width <= 0 || height <= 0 || rgba.empty())
        return {128, 128, 128};

      float x = std::clamp(uv.X * width - 0.5f, 0.0f, static_cast<float>(width - 1));
      float y = std::clamp(uv.Y * height - 0.5f, 0.0f, static_cast<float>(height - 1));
      int x0 = static_cast<int>(x), y0 = static_cast<int>(y);
      int x1 = std::min(x0 + 1, width - 1), y1 = std::min(y0 + 1, height - 1);
      float fx = x - x0, fy = y - y0;

      std::array<uint8_t, 3> result{};
      for (int channel = 0; channel < 3; ++channel) {
        auto texel = [&](int tx, int ty) {
          return static_cast<float>(rgba[(ty * width + tx) * 4 + channel]);
        };
        float top = texel(x0, y0) + (texel(x1, y0) - texel(x0, y0)) * fx;
        float bottom = texel(x0, y1) + (texel(x1, y1) - texel(x0, y1)) * fx;
        result[channel] = static_cast<uint8_t>(std::lround(top + (bottom - top) * fy));
      }
      return result;
    }

    /// where a vertical line through (x, z) meets the triangle, seen from above
    bool intersect(const GridFloor &triangle, float x, float z, float &height, quakelib::Vec2 &uv) {
      const auto &a = triangle.points[0], &b = triangle.points[1], &c = triangle.points[2];
      float denominator = (b.Z - c.Z) * (a.X - c.X) + (c.X - b.X) * (a.Z - c.Z);
      if (std::abs(denominator) < 1e-6f)
        return false;

      float wa = ((b.Z - c.Z) * (x - c.X) + (c.X - b.X) * (z - c.Z)) / denominator;
      float wb = ((c.Z - a.Z) * (x - c.X) + (a.X - c.X) * (z - c.Z)) / denominator;
      float wc = 1.0f - wa - wb;
      if (wa < 0 || wb < 0 || wc < 0)
        return false;

      height = a.Y * wa + b.Y * wb + c.Y * wc;
      uv = triangle.lightmapUvs[0] * wa + triangle.lightmapUvs[1] * wb + triangle.lightmapUvs[2] * wc;
      return true;
    }
  } // namespace

  LightGrid BuildLightGrid(const quakelib::Level &level, const std::vector<uint8_t> &lightmapRgba,
                           float cellSize) {
    return BuildLightGrid(collectFloors(level), level.lightmap.width, level.lightmap.height, lightmapRgba,
                          cellSize);
  }

  LightGrid BuildLightGrid(const std::vector<GridFloor> &triangles, int lightmapWidth, int lightmapHeight,
                           const std::vector<uint8_t> &lightmapRgba, float cellSize) {
    LightGrid grid;
    if (triangles.empty() || cellSize <= 0)
      return grid;

    quakelib::Vec3 min{std::numeric_limits<float>::max(), std::numeric_limits<float>::max(),
                       std::numeric_limits<float>::max()};
    quakelib::Vec3 max = min * -1.0f;
    for (const auto &triangle : triangles)
      for (const auto &point : triangle.points)
        for (int axis = 0; axis < 3; ++axis) {
          min[axis] = std::min(min[axis], point[axis]);
          max[axis] = std::max(max[axis], point[axis]);
        }

    grid.cellSize = cellSize;
    for (int axis = 0; axis < 3; ++axis)
      grid.origin[axis] = std::floor(min[axis] / cellSize) * cellSize;
    grid.sizeX = static_cast<int>(std::ceil((max.X - grid.origin.X) / cellSize)) + 1;
    grid.sizeY = static_cast<int>(std::ceil((max.Y - grid.origin.Y) / cellSize)) + 2;
    grid.sizeZ = static_cast<int>(std::ceil((max.Z - grid.origin.Z) / cellSize)) + 1;

    // every column of points only tests the triangles whose footprint covers it
    std::vector<std::vector<uint32_t>> columns(static_cast<size_t>(grid.sizeX) * grid.sizeZ);
    for (uint32_t index = 0; index < triangles.size(); ++index) {
      const auto &points = triangles[index].points;
      auto [minX, maxX] = std::minmax({points[0].X, points[1].X, points[2].X});
      auto [minZ, maxZ] = std::minmax({points[0].Z, points[1].Z, points[2].Z});
      int fromX = std::max(0, static_cast<int>(std::ceil((minX - grid.origin.X) / cellSize)));
      int toX = std::min(grid.sizeX - 1, static_cast<int>(std::floor((maxX - grid.origin.X) / cellSize)));
      int fromZ = std::max(0, static_cast<int>(std::ceil((minZ - grid.origin.Z) / cellSize)));
      int toZ = std::min(grid.sizeZ - 1, static_cast<int>(std::floor((maxZ - grid.origin.Z) / cellSize)));
      for (int z = fromZ; z <= toZ; ++z)
        for (int x = fromX; x <= toX; ++x)
          columns[z * grid.sizeX + x].push_back(index);
    }

    grid.rgb.assign(static_cast<size_t>(grid.sizeX) * grid.sizeY * grid.sizeZ * 3, 0);
    std::vector<Hit> hits;
    for (int z = 0; z < grid.sizeZ; ++z) {
      for (int x = 0; x < grid.sizeX; ++x) {
        float worldX = grid.origin.X + x * cellSize;
        float worldZ = grid.origin.Z + z * cellSize;
        hits.clear();
        for (uint32_t index : columns[z * grid.sizeX + x]) {
          float height;
          quakelib::Vec2 uv;
          if (intersect(triangles[index], worldX, worldZ, height, uv))
            hits.push_back({height, sampleLightmap(lightmapWidth, lightmapHeight, lightmapRgba, uv)});
        }
        std::ranges::sort(hits, [](const Hit &a, const Hit &b) { return a.height > b.height; });

        // a point takes the light of the first floor below it, a small tolerance keeps points on a floor
        for (int y = 0; y < grid.sizeY; ++y) {
          float worldY = grid.origin.Y + y * cellSize + cellSize * 0.05f;
          auto below = std::ranges::find_if(hits, [&](const Hit &hit) { return hit.height <= worldY; });
          if (below == hits.end())
            continue;
          size_t offset = ((static_cast<size_t>(y) * grid.sizeZ + z) * grid.sizeX + x) * 3;
          std::ranges::copy(below->rgb, grid.rgb.begin() + static_cast<std::ptrdiff_t>(offset));
        }
      }
    }
    return grid;
  }

} // namespace libquake_godot
