#pragma once

#include "texture_lookup.h"

#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <map>
#include <quakelib/level.h>

namespace libquake_godot {

  /// A .map or .bsp loaded through libquake, converted to Godot coordinates and units.
  class QuakeLevel : public godot::RefCounted {
    GDCLASS(QuakeLevel, godot::RefCounted)

  public:
    enum HullType {
      HULL_SOLID,
      HULL_CLIP,
      HULL_LIQUID,
    };

    /// origin of the brush entities' meshes and hulls, libquake's PivotMode
    enum Pivot {
      PIVOT_MAP_ORIGIN,
      PIVOT_CENTER,
      PIVOT_BOTTOM_CENTER,
      PIVOT_BOTTOM_CORNER,
    };

    godot::Error load(const godot::String &path);

    int get_geometry_count() const;
    godot::Ref<godot::ArrayMesh> get_geometry_mesh(int index) const;
    godot::TypedArray<godot::Dictionary> get_geometry_hulls(int index) const;
    godot::Vector3 get_geometry_pivot(int index) const;

    godot::TypedArray<godot::Dictionary> get_entities() const;

    godot::PackedStringArray get_texture_names() const;
    godot::Ref<godot::Image> get_texture_image(const godot::String &name) const;
    godot::Ref<godot::Image> get_texture_emission(const godot::String &name) const;
    godot::Ref<godot::Image> get_sky_front_image(const godot::String &name) const;
    godot::Ref<godot::Image> get_lightmap_image() const;
    godot::Dictionary build_light_grid(float cell_size) const;
    godot::Dictionary get_lightmap_layers() const;

    godot::Vector3 to_godot_position(const godot::Vector3 &quake_point) const;

    static godot::PackedByteArray get_default_palette();

    void set_units_per_meter(float value) { units_per_meter = value; }

    float get_units_per_meter() const { return units_per_meter; }

    void set_bake(bool value) { bake = value; }

    bool get_bake() const { return bake; }

    void set_luxel_size(float value) { luxel_size = value; }

    float get_luxel_size() const { return luxel_size; }

    void set_sky_samples(int value) { sky_samples = value; }

    int get_sky_samples() const { return sky_samples; }

    void set_bounces(int value) { bounces = value; }

    int get_bounces() const { return bounces; }

    void set_bounce_subdivision(float value) { bounce_subdivision = value; }

    float get_bounce_subdivision() const { return bounce_subdivision; }

    void set_bounce_scale(float value) { bounce_scale = value; }

    float get_bounce_scale() const { return bounce_scale; }

    void set_luxel_samples(int value) { luxel_samples = value; }

    int get_luxel_samples() const { return luxel_samples; }

    void set_dirt(int value) { dirt = value; }

    int get_dirt() const { return dirt; }

    void set_dirt_scale(float value) { dirt_scale = value; }

    float get_dirt_scale() const { return dirt_scale; }

    void set_dirt_samples(int value) { dirt_samples = value; }

    int get_dirt_samples() const { return dirt_samples; }

    void set_csg(bool value) { csg = value; }

    bool get_csg() const { return csg; }

    void set_pivot(Pivot value) { pivot = value; }

    Pivot get_pivot() const { return pivot; }

    void set_merge_groups(bool value) { merge_groups = value; }

    bool get_merge_groups() const { return merge_groups; }

    void set_texture_size_provider(const godot::Callable &value) { texture_size_provider = value; }

    godot::Callable get_texture_size_provider() const { return texture_size_provider; }

    void set_texture_color_provider(const godot::Callable &value) { texture_color_provider = value; }

    godot::Callable get_texture_color_provider() const { return texture_color_provider; }

    void set_missing_texture_size(const godot::Vector2i &value) { missing_texture_size = value; }

    godot::Vector2i get_missing_texture_size() const { return missing_texture_size; }

    void set_sky_surfaces(bool value) { sky_surfaces = value; }

    bool get_sky_surfaces() const { return sky_surfaces; }

    void set_wad_directories(const godot::PackedStringArray &value) { wad_directories = value; }

    godot::PackedStringArray get_wad_directories() const { return wad_directories; }

  protected:
    static void _bind_methods();

  private:
    std::vector<uint8_t> composedLightmap() const;
    std::pair<int, int> textureSize(const std::string &name, TextureLookup &lookup) const;
    quakelib::Vec3 textureColor(const std::string &name, TextureLookup &lookup) const;
    const TextureImage *findTexture(const godot::String &name) const;
    godot::Vector3 toGodot(const quakelib::Vec3 &point) const;

    quakelib::Level level;
    std::map<std::string, TextureImage> textures;

    float units_per_meter = 32.0f;
    bool bake = true;
    float luxel_size = 16.0f;
    int sky_samples = 64;
    /// -1 as the map says
    int bounces = -1;
    float bounce_subdivision = 64.0f;
    /// negative as the map says
    float bounce_scale = -1.0f;
    /// samples per luxel along each side; ambient occlusion -1 as the map says, 0 off, 1 on; negative scale as
    /// the map says
    int luxel_samples = 1;
    int dirt = -1;
    float dirt_scale = -1.0f;
    int dirt_samples = 48;
    bool sky_surfaces = true;
    bool csg = true;
    Pivot pivot = PIVOT_MAP_ORIGIN;
    bool merge_groups = false;
    /// name -> Vector2i pixel size of an image texture, Vector2i() if there is none; comes before the wads
    godot::Callable texture_size_provider;
    /// name -> average Color of an image texture, alpha 0 if there is none; comes before the wads
    godot::Callable texture_color_provider;
    /// uv size of textures nobody has, the size of the placeholder that shows how they are mapped
    godot::Vector2i missing_texture_size{64, 64};
    godot::PackedStringArray wad_directories;
  };

} // namespace libquake_godot

VARIANT_ENUM_CAST(libquake_godot::QuakeLevel::HullType);
VARIANT_ENUM_CAST(libquake_godot::QuakeLevel::Pivot);
