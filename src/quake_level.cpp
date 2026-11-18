#include "quake_level.h"

#include "image_util.h"
#include "light_grid.h"
#include "quake_light_style_animator.h"

#include <algorithm>
#include <cctype>
#include <filesystem>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <quakelib/bsp/bsp_level.h>
#include <quakelib/map/map_document.h>
#include <quakelib/map/map_level.h>
#include <quakelib/texture_name.h>
#include <quakelib/wad/palette.h>

using namespace godot;

namespace libquake_godot {

  namespace {
    std::string lowercase(std::string text) {
      std::ranges::transform(text, text.begin(), [](unsigned char c) { return std::tolower(c); });
      return text;
    }

    bool isBsp(const std::string &path) {
      return lowercase(std::filesystem::path(path).extension().string()) == ".bsp";
    }

    Vector3 quakeDirectionToGodot(const quakelib::Vec3 &v) { return {v.X, v.Z, -v.Y}; }
  } // namespace

  Error QuakeLevel::load(const String &path) {
    std::string file = path.utf8().get_data();
    std::vector<std::string> dirs{std::filesystem::path(file).parent_path().string()};
    for (const auto &dir : wad_directories)
      dirs.emplace_back(dir.utf8().get_data());

    TextureLookup lookup;
    try {
      if (isBsp(file)) {
        quakelib::BspLoadOptions options;
        options.convertToOpenGL = true;
        level = quakelib::LoadBsp(file, options);
        lookup.LoadWads(level.wads, dirs);
      } else {
        auto document = quakelib::ParseMap(file);
        lookup.LoadWads(document.wads, dirs);
        quakelib::MapBuildOptions options;
        options.convertToOpenGL = true;
        options.csg = csg;
        options.pivot = static_cast<quakelib::PivotMode>(pivot);
        options.mergeGroups = merge_groups;
        options.bake = bake;
        options.lightmapUV.luxelSize = luxel_size;
        options.textureSize = [&](const std::string &name) { return textureSize(name, lookup); };
        level = quakelib::BuildMap(document, options);
      }
    } catch (const std::exception &e) {
      UtilityFunctions::push_error(vformat("libquake: %s: %s", path, e.what()));
      return ERR_PARSE_ERROR;
    }

    textures.clear();
    for (const auto &info : level.textures)
      textures[lowercase(info.name)] = lookup.Image(info);
    return OK;
  }

  int QuakeLevel::get_geometry_count() const { return static_cast<int>(level.geometry.size()); }

  Ref<ArrayMesh> QuakeLevel::get_geometry_mesh(int index) const {
    ERR_FAIL_INDEX_V(index, get_geometry_count(), {});
    Ref<ArrayMesh> mesh;
    mesh.instantiate();

    for (const auto &source : level.geometry[index].meshes) {
      if (source.type != quakelib::SurfaceType::SOLID || source.indices.empty())
        continue;
      if (!sky_surfaces && quakelib::IsSkyTexture(source.textureName))
        continue;

      PackedVector3Array vertices, normals;
      PackedVector2Array uvs, lightmap_uvs;
      PackedFloat32Array tangents;
      for (const auto &v : source.vertices) {
        vertices.push_back(toGodot(v.point));
        normals.push_back(Vector3(v.normal.X, v.normal.Y, v.normal.Z));
        uvs.push_back(Vector2(v.uv.X, v.uv.Y));
        lightmap_uvs.push_back(Vector2(v.lightmap_uv.X, v.lightmap_uv.Y));
        tangents.append_array({v.tangent.X, v.tangent.Y, v.tangent.Z, v.tangent.W});
      }
      PackedInt32Array indices;
      for (uint32_t index : source.indices)
        indices.push_back(static_cast<int32_t>(index));

      Array arrays;
      arrays.resize(Mesh::ARRAY_MAX);
      arrays[Mesh::ARRAY_VERTEX] = vertices;
      arrays[Mesh::ARRAY_NORMAL] = normals;
      arrays[Mesh::ARRAY_TANGENT] = tangents;
      arrays[Mesh::ARRAY_TEX_UV] = uvs;
      arrays[Mesh::ARRAY_TEX_UV2] = lightmap_uvs;
      arrays[Mesh::ARRAY_INDEX] = indices;
      mesh->add_surface_from_arrays(Mesh::PRIMITIVE_TRIANGLES, arrays);
      mesh->surface_set_name(mesh->get_surface_count() - 1, String(source.textureName.c_str()));
    }
    return mesh;
  }

  TypedArray<Dictionary> QuakeLevel::get_geometry_hulls(int index) const {
    ERR_FAIL_INDEX_V(index, get_geometry_count(), {});
    TypedArray<Dictionary> hulls;
    for (const auto &source : level.geometry[index].hulls) {
      PackedVector3Array points;
      for (const auto &point : source.points)
        points.push_back(toGodot(point));

      Dictionary hull;
      hull["type"] = static_cast<HullType>(source.type);
      hull["texture"] = String(source.textureName.c_str());
      hull["points"] = points;
      hulls.push_back(hull);
    }
    return hulls;
  }

  Vector3 QuakeLevel::get_geometry_pivot(int index) const {
    ERR_FAIL_INDEX_V(index, get_geometry_count(), {});
    return toGodot(level.geometry[index].pivot);
  }

  TypedArray<Dictionary> QuakeLevel::get_entities() const {
    TypedArray<Dictionary> entities;
    for (const auto &source : level.entities) {
      Dictionary properties;
      for (const auto &[key, value] : source.attributes)
        properties[String(key.c_str())] = String(value.c_str());

      Dictionary entity;
      entity["classname"] = String(source.classname.c_str());
      entity["geometry"] = source.geometry;
      entity["properties"] = properties;
      entity["origin"] = to_godot_position(Vector3(source.Origin().X, source.Origin().Y, source.Origin().Z));
      entity["angles"] = Vector3(source.Angles().X, source.Angles().Y, source.Angles().Z);
      entity["move_dir"] = quakeDirectionToGodot(source.MoveDir());
      entities.push_back(entity);
    }
    return entities;
  }

  PackedStringArray QuakeLevel::get_texture_names() const {
    PackedStringArray names;
    for (const auto &info : level.textures)
      names.push_back(String(info.name.c_str()));
    return names;
  }

  Ref<Image> QuakeLevel::get_texture_image(const String &name) const {
    const auto *texture = findTexture(name);
    return texture ? MakeImage(texture->width, texture->height, texture->rgba) : Ref<Image>();
  }

  Ref<Image> QuakeLevel::get_texture_emission(const String &name) const {
    const auto *texture = findTexture(name);
    return texture ? MakeImage(texture->width, texture->height, texture->emission) : Ref<Image>();
  }

  Ref<Image> QuakeLevel::get_sky_front_image(const String &name) const {
    const auto *texture = findTexture(name);
    return texture ? MakeImage(texture->width, texture->height, texture->skyFront) : Ref<Image>();
  }

  Ref<Image> QuakeLevel::get_lightmap_image() const {
    if (level.lightmap.Empty())
      return MakeImage(1, 1, {128, 128, 128, 255});
    return MakeImage(level.lightmap.width, level.lightmap.height, composedLightmap());
  }

  Dictionary QuakeLevel::build_light_grid(float cell_size) const {
    LightGrid grid = BuildLightGrid(level, composedLightmap(), cell_size * units_per_meter);
    PackedByteArray rgb;
    rgb.resize(static_cast<int64_t>(grid.rgb.size()));
    std::copy(grid.rgb.begin(), grid.rgb.end(), rgb.ptrw());

    Dictionary result;
    result["origin"] = toGodot(grid.origin);
    result["cell_size"] = cell_size;
    result["size"] = Vector3i(grid.sizeX, grid.sizeY, grid.sizeZ);
    result["rgb"] = rgb;
    return result;
  }

  Dictionary QuakeLevel::get_lightmap_layers() const {
    return QuakeLightStyleAnimator::layers_to_dictionary(level.lightmap);
  }

  std::vector<uint8_t> QuakeLevel::composedLightmap() const {
    if (level.lightmap.Empty())
      return {};
    quakelib::LightStyleAnimator animator;
    animator.Update(0.0, level.lightmap);
    return animator.Compose(level.lightmap);
  }

  Vector3 QuakeLevel::to_godot_position(const Vector3 &quake_point) const {
    return Vector3(quake_point.x, quake_point.z, -quake_point.y) / units_per_meter;
  }

  std::pair<int, int> QuakeLevel::textureSize(const std::string &name, TextureLookup &lookup) const {
    if (texture_size_provider.is_valid()) {
      Vector2i pixels = texture_size_provider.call(String(name.c_str()));
      if (pixels.x > 0 && pixels.y > 0)
        return {pixels.x, pixels.y};
    }
    return lookup.Size(name, {missing_texture_size.x, missing_texture_size.y});
  }

  PackedByteArray QuakeLevel::get_default_palette() {
    PackedByteArray palette;
    palette.resize(quakelib::wad::default_palette_size);
    std::copy_n(quakelib::wad::default_palette_lmp, quakelib::wad::default_palette_size, palette.ptrw());
    return palette;
  }

  const TextureImage *QuakeLevel::findTexture(const String &name) const {
    auto found = textures.find(lowercase(name.utf8().get_data()));
    return found != textures.end() && !found->second.rgba.empty() ? &found->second : nullptr;
  }

  Vector3 QuakeLevel::toGodot(const quakelib::Vec3 &point) const {
    return Vector3(point.X, point.Y, point.Z) / units_per_meter;
  }

  void QuakeLevel::_bind_methods() {
    ClassDB::bind_method(D_METHOD("load", "path"), &QuakeLevel::load);
    ClassDB::bind_method(D_METHOD("get_geometry_count"), &QuakeLevel::get_geometry_count);
    ClassDB::bind_method(D_METHOD("get_geometry_mesh", "index"), &QuakeLevel::get_geometry_mesh);
    ClassDB::bind_method(D_METHOD("get_geometry_hulls", "index"), &QuakeLevel::get_geometry_hulls);
    ClassDB::bind_method(D_METHOD("get_geometry_pivot", "index"), &QuakeLevel::get_geometry_pivot);
    ClassDB::bind_method(D_METHOD("get_entities"), &QuakeLevel::get_entities);
    ClassDB::bind_method(D_METHOD("get_texture_names"), &QuakeLevel::get_texture_names);
    ClassDB::bind_method(D_METHOD("get_texture_image", "name"), &QuakeLevel::get_texture_image);
    ClassDB::bind_method(D_METHOD("get_texture_emission", "name"), &QuakeLevel::get_texture_emission);
    ClassDB::bind_method(D_METHOD("get_sky_front_image", "name"), &QuakeLevel::get_sky_front_image);
    ClassDB::bind_method(D_METHOD("get_lightmap_image"), &QuakeLevel::get_lightmap_image);
    ClassDB::bind_method(D_METHOD("build_light_grid", "cell_size"), &QuakeLevel::build_light_grid);
    ClassDB::bind_method(D_METHOD("get_lightmap_layers"), &QuakeLevel::get_lightmap_layers);
    ClassDB::bind_method(D_METHOD("to_godot_position", "quake_point"), &QuakeLevel::to_godot_position);

    ClassDB::bind_method(D_METHOD("set_units_per_meter", "value"), &QuakeLevel::set_units_per_meter);
    ClassDB::bind_method(D_METHOD("get_units_per_meter"), &QuakeLevel::get_units_per_meter);
    ClassDB::bind_method(D_METHOD("set_bake", "value"), &QuakeLevel::set_bake);
    ClassDB::bind_method(D_METHOD("get_bake"), &QuakeLevel::get_bake);
    ClassDB::bind_method(D_METHOD("set_luxel_size", "value"), &QuakeLevel::set_luxel_size);
    ClassDB::bind_method(D_METHOD("get_luxel_size"), &QuakeLevel::get_luxel_size);
    ClassDB::bind_method(D_METHOD("set_csg", "value"), &QuakeLevel::set_csg);
    ClassDB::bind_method(D_METHOD("get_csg"), &QuakeLevel::get_csg);
    ClassDB::bind_method(D_METHOD("set_pivot", "value"), &QuakeLevel::set_pivot);
    ClassDB::bind_method(D_METHOD("get_pivot"), &QuakeLevel::get_pivot);
    ClassDB::bind_method(D_METHOD("set_merge_groups", "value"), &QuakeLevel::set_merge_groups);
    ClassDB::bind_method(D_METHOD("get_merge_groups"), &QuakeLevel::get_merge_groups);
    ClassDB::bind_method(D_METHOD("set_texture_size_provider", "value"),
                         &QuakeLevel::set_texture_size_provider);
    ClassDB::bind_method(D_METHOD("get_texture_size_provider"), &QuakeLevel::get_texture_size_provider);
    ClassDB::bind_static_method("QuakeLevel", D_METHOD("get_default_palette"),
                                &QuakeLevel::get_default_palette);
    ClassDB::bind_method(D_METHOD("set_missing_texture_size", "value"),
                         &QuakeLevel::set_missing_texture_size);
    ClassDB::bind_method(D_METHOD("get_missing_texture_size"), &QuakeLevel::get_missing_texture_size);
    ClassDB::bind_method(D_METHOD("set_sky_surfaces", "value"), &QuakeLevel::set_sky_surfaces);
    ClassDB::bind_method(D_METHOD("get_sky_surfaces"), &QuakeLevel::get_sky_surfaces);
    ClassDB::bind_method(D_METHOD("set_wad_directories", "value"), &QuakeLevel::set_wad_directories);
    ClassDB::bind_method(D_METHOD("get_wad_directories"), &QuakeLevel::get_wad_directories);

    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "units_per_meter"), "set_units_per_meter",
                 "get_units_per_meter");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "bake"), "set_bake", "get_bake");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "luxel_size"), "set_luxel_size", "get_luxel_size");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "csg"), "set_csg", "get_csg");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "pivot", PROPERTY_HINT_ENUM,
                              "Map Origin,Center,Bottom Center,Bottom Corner"),
                 "set_pivot", "get_pivot");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "merge_groups"), "set_merge_groups", "get_merge_groups");
    ADD_PROPERTY(PropertyInfo(Variant::CALLABLE, "texture_size_provider"), "set_texture_size_provider",
                 "get_texture_size_provider");
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR2I, "missing_texture_size"), "set_missing_texture_size",
                 "get_missing_texture_size");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "sky_surfaces"), "set_sky_surfaces", "get_sky_surfaces");
    ADD_PROPERTY(PropertyInfo(Variant::PACKED_STRING_ARRAY, "wad_directories"), "set_wad_directories",
                 "get_wad_directories");

    BIND_ENUM_CONSTANT(HULL_SOLID);
    BIND_ENUM_CONSTANT(HULL_CLIP);
    BIND_ENUM_CONSTANT(HULL_LIQUID);
    BIND_ENUM_CONSTANT(PIVOT_MAP_ORIGIN);
    BIND_ENUM_CONSTANT(PIVOT_CENTER);
    BIND_ENUM_CONSTANT(PIVOT_BOTTOM_CENTER);
    BIND_ENUM_CONSTANT(PIVOT_BOTTOM_CORNER);
  }

} // namespace libquake_godot
