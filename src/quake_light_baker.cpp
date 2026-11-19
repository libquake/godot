#include "quake_light_baker.h"

#include "light_grid.h"
#include "quake_light_style_animator.h"

#include <algorithm>
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <numeric>

using namespace godot;

namespace libquake_godot {

  namespace {
    // Godot's Image limit
    constexpr int MAX_ATLAS_SIZE = 16384;
    // lightmap value of normal brightness
    constexpr float NORMAL_LIGHT = 128.0f;

    quakelib::Vec3 vec3(const Vector3 &v) { return {v.x, v.y, v.z}; }

    int nextPowerOfTwo(int value) {
      int result = 1;
      while (result < value)
        result *= 2;
      return result;
    }
  } // namespace

  int QuakeLightBaker::add_surface(const PackedVector3Array &vertices, const PackedVector3Array &normals,
                                   const PackedVector2Array &uv2, const PackedInt32Array &indices,
                                   float texel_scale) {
    ERR_FAIL_COND_V(normals.size() != vertices.size() || uv2.size() != vertices.size(), -1);
    Surface surface;
    surface.texelScale = texel_scale > 0 ? texel_scale : 1.0f;
    quakelib::Vec2 uvMax{-1e30f, -1e30f};
    surface.uvMin = {1e30f, 1e30f};
    for (int64_t i = 0; i + 2 < indices.size(); i += 3) {
      for (int corner = 0; corner < 3; corner++) {
        int32_t index = indices[i + corner];
        ERR_FAIL_INDEX_V(index, vertices.size(), -1);
        surface.positions.push_back(toBake(vertices[index]));
        surface.normals.push_back(quakelib::math::Norm(vec3(normals[index])));
        quakelib::Vec2 uv{uv2[index].x, uv2[index].y};
        surface.uvs.push_back(uv);
        surface.uvMin = {std::min(surface.uvMin.X, uv.X), std::min(surface.uvMin.Y, uv.Y)};
        uvMax = {std::max(uvMax.X, uv.X), std::max(uvMax.Y, uv.Y)};
      }
    }
    surface.uvSize = uvMax - surface.uvMin;
    surfaces.push_back(std::move(surface));
    return static_cast<int>(surfaces.size()) - 1;
  }

  void QuakeLightBaker::add_occluder(const PackedVector3Array &vertices, const PackedInt32Array &indices,
                                     bool sky) {
    for (int64_t i = 0; i + 2 < indices.size(); i += 3) {
      for (int corner = 0; corner < 3; corner++) {
        int32_t index = indices[i + corner];
        ERR_FAIL_INDEX(index, vertices.size());
        occluders.triangles.push_back(toBake(vertices[index]));
      }
      occluders.isSky.push_back(sky);
    }
  }

  void QuakeLightBaker::add_light(LightType type, const Vector3 &position, const Vector3 &direction,
                                  const Color &color, float intensity, float range, float cone_angle,
                                  bool shadows) {
    quakelib::BakeLight light;
    light.type = static_cast<quakelib::BakeLight::Type>(type);
    light.position = toBake(position);
    light.direction = quakelib::math::Norm(vec3(direction));
    light.color = {color.r, color.g, color.b};
    light.intensity = intensity;
    // linear falloff that reaches zero at the range, like Godot's lights end there
    if (type != LIGHT_SUN && type != LIGHT_SKY_DOME && range > 0)
      light.distanceScale = std::abs(intensity) / (range * units_per_meter);
    light.coneAngle = cone_angle;
    light.castShadows = shadows;
    lights.push_back(light);
  }

  void QuakeLightBaker::add_quake_entities(const TypedArray<Dictionary> &entities,
                                           const Transform3D &transform, bool add_lights, bool worldspawn) {
    std::vector<quakelib::LevelEntity> levelEntities;
    for (int64_t i = 0; i < entities.size(); i++) {
      Dictionary source = entities[i];
      quakelib::LevelEntity entity;
      entity.classname = String(source.get("classname", "")).utf8().get_data();
      Dictionary properties = source.get("properties", Dictionary());
      Array keys = properties.keys();
      for (int64_t k = 0; k < keys.size(); k++)
        entity.attributes[String(keys[k]).utf8().get_data()] = String(properties[keys[k]]).utf8().get_data();
      levelEntities.push_back(std::move(entity));
    }

    quakelib::BakeOptions mapOptions;
    // map units with Godot's axes, relative to the map
    for (auto light : quakelib::QuakeLightsFromEntities(levelEntities, true, &mapOptions)) {
      bool sky = light.type == quakelib::BakeLight::Type::Sun || light.type == quakelib::BakeLight::Type::SkyDome;
      if (sky ? !worldspawn : !add_lights)
        continue;
      Vector3 position(light.position.X, light.position.Y, light.position.Z);
      Vector3 direction(light.direction.X, light.direction.Y, light.direction.Z);
      light.position = toBake(transform.xform(position / units_per_meter));
      light.direction = quakelib::math::Norm(vec3(transform.basis.xform(direction)));
      lights.push_back(light);
    }
    if (!worldspawn)
      return;
    if (mapOptions.minLight > options.minLight) {
      options.minLight = mapOptions.minLight;
      options.minLightColor = mapOptions.minLightColor;
    }
    if (!has_worldspawn_options) {
      options.angleScale = mapOptions.angleScale;
      options.rangeScale = mapOptions.rangeScale;
      has_worldspawn_options = true;
    }
  }

  Error QuakeLightBaker::bake() {
    ERR_FAIL_COND_V_MSG(surfaces.empty(), ERR_UNCONFIGURED, "QuakeLightBaker: nothing to bake.");
    if (!pack())
      return ERR_PARAMETER_RANGE_ERROR;

    quakelib::BakeSurfaces input;
    input.width = atlas_width;
    input.height = atlas_height;
    input.padding = padding;
    for (const auto &surface : surfaces) {
      if (surface.width == 0)
        continue;
      input.positions.insert(input.positions.end(), surface.positions.begin(), surface.positions.end());
      input.normals.insert(input.normals.end(), surface.normals.begin(), surface.normals.end());
      for (const auto &uv : surface.uvs) {
        quakelib::Vec2 atlas = atlasUv(surface, uv);
        input.uvs.push_back({atlas.X * atlas_width, atlas.Y * atlas_height});
      }
    }

    quakelib::BakeOptions bakeOptions = options;
    bakeOptions.ambient = quakelib::Vec3{ambient_light.r, ambient_light.g, ambient_light.b} * NORMAL_LIGHT;
    if (minimum_light * NORMAL_LIGHT > bakeOptions.minLight) {
      bakeOptions.minLight = minimum_light * NORMAL_LIGHT;
      bakeOptions.minLightColor = {1, 1, 1};
    }
    bakeOptions.quality.skySamples = sky_samples;
    auto baked = quakelib::BakeLightmap(input, occluders, lights, bakeOptions);
    bake_milliseconds = baked.bakeMilliseconds;

    quakelib::LightStyleAnimator animator;
    animator.Update(0.0, baked);
    lightmap = animator.Compose(baked);
    layers = std::move(baked);
    return OK;
  }

  Ref<Image> QuakeLightBaker::get_lightmap_image() const {
    ERR_FAIL_COND_V(lightmap.empty(), {});
    PackedByteArray data;
    data.resize(static_cast<int64_t>(lightmap.size()));
    std::copy(lightmap.begin(), lightmap.end(), data.ptrw());
    return Image::create_from_data(atlas_width, atlas_height, false, Image::FORMAT_RGBA8, data);
  }

  Dictionary QuakeLightBaker::get_lightmap_layers() const {
    return QuakeLightStyleAnimator::layers_to_dictionary(layers);
  }

  Vector4 QuakeLightBaker::get_surface_uv_transform(int index) const {
    ERR_FAIL_INDEX_V(index, static_cast<int>(surfaces.size()), Vector4(1, 1, 0, 0));
    const auto &surface = surfaces[index];
    if (surface.width == 0)
      return Vector4(1, 1, 0, 0);
    quakelib::Vec2 origin = atlasUv(surface, {0, 0});
    quakelib::Vec2 one = atlasUv(surface, {1, 1});
    return Vector4(one.X - origin.X, one.Y - origin.Y, origin.X, origin.Y);
  }

  Dictionary QuakeLightBaker::build_light_grid(float cell_size) const {
    std::vector<GridFloor> floors;
    for (const auto &surface : surfaces) {
      if (surface.width == 0)
        continue;
      for (size_t t = 0; t + 2 < surface.positions.size(); t += 3) {
        if (surface.normals[t].Y + surface.normals[t + 1].Y + surface.normals[t + 2].Y <= 0.01f)
          continue;
        GridFloor floor;
        for (int corner = 0; corner < 3; corner++) {
          floor.points[corner] = surface.positions[t + corner] / units_per_meter;
          floor.lightmapUvs[corner] = atlasUv(surface, surface.uvs[t + corner]);
        }
        floors.push_back(floor);
      }
    }
    LightGrid grid = BuildLightGrid(floors, atlas_width, atlas_height, lightmap, cell_size);

    PackedByteArray rgb;
    rgb.resize(static_cast<int64_t>(grid.rgb.size()));
    std::copy(grid.rgb.begin(), grid.rgb.end(), rgb.ptrw());
    Dictionary result;
    result["origin"] = Vector3(grid.origin.X, grid.origin.Y, grid.origin.Z);
    result["cell_size"] = cell_size;
    result["size"] = Vector3i(grid.sizeX, grid.sizeY, grid.sizeZ);
    result["rgb"] = rgb;
    return result;
  }

  /// Every surface gets a rectangle sized by its area, shelves of rectangles sorted by height.
  bool QuakeLightBaker::pack() {
    int64_t area = 0;
    int widest = 1;
    for (auto &surface : surfaces) {
      // map units per UV2 unit along u and v, weighted by UV2 area: UV2 may stretch, e.g. a 1024 x 352 atlas
      float alongU = 0, alongV = 0, weight = 0;
      for (size_t t = 0; t + 2 < surface.positions.size(); t += 3) {
        quakelib::Vec3 e1 = surface.positions[t + 1] - surface.positions[t];
        quakelib::Vec3 e2 = surface.positions[t + 2] - surface.positions[t];
        quakelib::Vec2 d1 = surface.uvs[t + 1] - surface.uvs[t];
        quakelib::Vec2 d2 = surface.uvs[t + 2] - surface.uvs[t];
        float det = d1.X * d2.Y - d2.X * d1.Y;
        if (std::abs(det) < 1e-12f)
          continue;
        float uvArea = std::abs(det) * 0.5f;
        alongU += quakelib::math::Len((e1 * d2.Y - e2 * d1.Y) / det) * uvArea;
        alongV += quakelib::math::Len((e2 * d1.X - e1 * d2.X) / det) * uvArea;
        weight += uvArea;
      }
      surface.width = surface.height = 0;
      if (weight <= 0 || surface.uvSize.X <= 0 || surface.uvSize.Y <= 0)
        continue;
      float texelsPerUnit = surface.texelScale / luxel_size;
      int limit = MAX_ATLAS_SIZE - 2 * padding;
      surface.width = std::clamp(
          static_cast<int>(std::ceil(surface.uvSize.X * alongU / weight * texelsPerUnit)), 1, limit);
      surface.height = std::clamp(
          static_cast<int>(std::ceil(surface.uvSize.Y * alongV / weight * texelsPerUnit)), 1, limit);
      area += static_cast<int64_t>(surface.width + 2 * padding) * (surface.height + 2 * padding);
      widest = std::max(widest, surface.width + 2 * padding);
    }

    std::vector<size_t> order(surfaces.size());
    std::iota(order.begin(), order.end(), 0);
    std::ranges::stable_sort(order,
                             [&](size_t a, size_t b) { return surfaces[a].height > surfaces[b].height; });

    atlas_width = std::min(MAX_ATLAS_SIZE,
                           std::max(widest, nextPowerOfTwo(static_cast<int>(std::ceil(std::sqrt(area))))));
    int x = 0, y = 0, shelf = 0;
    for (size_t index : order) {
      auto &surface = surfaces[index];
      if (surface.width == 0)
        continue;
      int width = surface.width + 2 * padding, height = surface.height + 2 * padding;
      if (x + width > atlas_width) {
        x = 0;
        y += shelf;
        shelf = 0;
      }
      surface.x = x + padding;
      surface.y = y + padding;
      x += width;
      shelf = std::max(shelf, height);
    }
    atlas_height = std::max(1, y + shelf);
    ERR_FAIL_COND_V_MSG(atlas_height > MAX_ATLAS_SIZE, false,
                        vformat("QuakeLightBaker: the lightmap would be %dx%d, raise luxel_size.",
                                atlas_width, atlas_height));
    return true;
  }

  quakelib::Vec2 QuakeLightBaker::atlasUv(const Surface &surface, const quakelib::Vec2 &uv) const {
    float x = surface.x + (uv.X - surface.uvMin.X) / surface.uvSize.X * surface.width;
    float y = surface.y + (uv.Y - surface.uvMin.Y) / surface.uvSize.Y * surface.height;
    return {x / atlas_width, y / atlas_height};
  }

  quakelib::Vec3 QuakeLightBaker::toBake(const Vector3 &meters) const {
    return vec3(meters * units_per_meter);
  }

  void QuakeLightBaker::_bind_methods() {
    ClassDB::bind_method(D_METHOD("add_surface", "vertices", "normals", "uv2", "indices", "texel_scale"),
                         &QuakeLightBaker::add_surface);
    ClassDB::bind_method(D_METHOD("add_occluder", "vertices", "indices", "sky"),
                         &QuakeLightBaker::add_occluder);
    ClassDB::bind_method(D_METHOD("add_light", "type", "position", "direction", "color", "intensity", "range",
                                  "cone_angle", "shadows"),
                         &QuakeLightBaker::add_light);
    ClassDB::bind_method(D_METHOD("add_quake_entities", "entities", "transform", "add_lights", "worldspawn"),
                         &QuakeLightBaker::add_quake_entities);
    ClassDB::bind_method(D_METHOD("bake"), &QuakeLightBaker::bake);
    ClassDB::bind_method(D_METHOD("get_lightmap_image"), &QuakeLightBaker::get_lightmap_image);
    ClassDB::bind_method(D_METHOD("get_lightmap_layers"), &QuakeLightBaker::get_lightmap_layers);
    ClassDB::bind_method(D_METHOD("get_surface_uv_transform", "surface"),
                         &QuakeLightBaker::get_surface_uv_transform);
    ClassDB::bind_method(D_METHOD("build_light_grid", "cell_size"), &QuakeLightBaker::build_light_grid);
    ClassDB::bind_method(D_METHOD("get_bake_milliseconds"), &QuakeLightBaker::get_bake_milliseconds);

    ClassDB::bind_method(D_METHOD("set_units_per_meter", "value"), &QuakeLightBaker::set_units_per_meter);
    ClassDB::bind_method(D_METHOD("get_units_per_meter"), &QuakeLightBaker::get_units_per_meter);
    ClassDB::bind_method(D_METHOD("set_luxel_size", "value"), &QuakeLightBaker::set_luxel_size);
    ClassDB::bind_method(D_METHOD("get_luxel_size"), &QuakeLightBaker::get_luxel_size);
    ClassDB::bind_method(D_METHOD("set_minimum_light", "value"), &QuakeLightBaker::set_minimum_light);
    ClassDB::bind_method(D_METHOD("get_minimum_light"), &QuakeLightBaker::get_minimum_light);
    ClassDB::bind_method(D_METHOD("set_ambient_light", "value"), &QuakeLightBaker::set_ambient_light);
    ClassDB::bind_method(D_METHOD("get_ambient_light"), &QuakeLightBaker::get_ambient_light);
    ClassDB::bind_method(D_METHOD("set_padding", "value"), &QuakeLightBaker::set_padding);
    ClassDB::bind_method(D_METHOD("get_padding"), &QuakeLightBaker::get_padding);
    ClassDB::bind_method(D_METHOD("set_sky_samples", "value"), &QuakeLightBaker::set_sky_samples);
    ClassDB::bind_method(D_METHOD("get_sky_samples"), &QuakeLightBaker::get_sky_samples);

    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "units_per_meter"), "set_units_per_meter",
                 "get_units_per_meter");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "luxel_size"), "set_luxel_size", "get_luxel_size");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "minimum_light"), "set_minimum_light", "get_minimum_light");
    ADD_PROPERTY(PropertyInfo(Variant::COLOR, "ambient_light"), "set_ambient_light", "get_ambient_light");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "padding"), "set_padding", "get_padding");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "sky_samples"), "set_sky_samples", "get_sky_samples");

    BIND_ENUM_CONSTANT(LIGHT_POINT);
    BIND_ENUM_CONSTANT(LIGHT_SPOT);
    BIND_ENUM_CONSTANT(LIGHT_SUN);
    BIND_ENUM_CONSTANT(LIGHT_SKY_DOME);
  }

} // namespace libquake_godot
