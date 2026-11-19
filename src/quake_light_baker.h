#pragma once

// before godot-cpp, its CMP_EPSILON macro breaks quakelib's constant of that name
#include <quakelib/lightmap_baker.h>

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/typed_array.hpp>

namespace libquake_godot {

  /// Quake-style light for the meshes of a Godot scene, each surface in one atlas through its UV2. Positions are
  /// in meters, the bake works in map units so Quake lights and luxel sizes keep their meaning.
  class QuakeLightBaker : public godot::RefCounted {
    GDCLASS(QuakeLightBaker, godot::RefCounted)

  public:
    enum LightType {
      LIGHT_POINT,
      LIGHT_SPOT,
      LIGHT_SUN,
      LIGHT_SKY_DOME,
    };

    /// colors: one per triangle, the average color of its texture for bounced light, may be empty (gray)
    int add_surface(const godot::PackedVector3Array &vertices, const godot::PackedVector3Array &normals,
                    const godot::PackedVector2Array &uv2, const godot::PackedInt32Array &indices,
                    float texel_scale, const godot::PackedColorArray &colors);
    void add_occluder(const godot::PackedVector3Array &vertices, const godot::PackedInt32Array &indices,
                      bool sky);
    void add_light(LightType type, const godot::Vector3 &position, const godot::Vector3 &direction,
                   const godot::Color &color, float intensity, float range, float cone_angle, bool shadows);
    /// The first map's _anglescale and _range apply to the whole bake, _minlight is the highest of all.
    void add_quake_entities(const godot::TypedArray<godot::Dictionary> &entities,
                            const godot::Transform3D &transform, bool add_lights, bool worldspawn);

    godot::Error bake();
    godot::Ref<godot::Image> get_lightmap_image() const;
    godot::Dictionary get_lightmap_layers() const;
    godot::Vector4 get_surface_uv_transform(int surface) const;
    godot::Dictionary build_light_grid(float cell_size) const;

    double get_bake_milliseconds() const { return bake_milliseconds; }

    void set_units_per_meter(float value) { units_per_meter = value; }

    float get_units_per_meter() const { return units_per_meter; }

    void set_luxel_size(float value) { luxel_size = value; }

    float get_luxel_size() const { return luxel_size; }

    void set_minimum_light(float value) { minimum_light = value; }

    float get_minimum_light() const { return minimum_light; }

    void set_ambient_light(const godot::Color &value) { ambient_light = value; }

    godot::Color get_ambient_light() const { return ambient_light; }

    void set_padding(int value) { padding = value; }

    int get_padding() const { return padding; }

    void set_sky_samples(int value) { sky_samples = value; }

    int get_sky_samples() const { return sky_samples; }

    void set_bounces(int value) { bounces = value; }

    int get_bounces() const { return bounces; }

    void set_bounce_subdivision(float value) { bounce_subdivision = value; }

    float get_bounce_subdivision() const { return bounce_subdivision; }

    void set_bounce_scale(float value) { bounce_scale = value; }

    float get_bounce_scale() const { return bounce_scale; }

  protected:
    static void _bind_methods();

  private:
    struct Surface {
      std::vector<quakelib::Vec3> positions; ///< map units, 3 per triangle
      std::vector<quakelib::Vec3> normals;
      std::vector<quakelib::Vec2> uvs; ///< UV2 as in the mesh
      std::vector<quakelib::Vec3> colors; ///< per triangle, may be empty
      float texelScale = 1.0f;
      quakelib::Vec2 uvMin{0, 0};
      quakelib::Vec2 uvSize{0, 0};
      // place in the atlas, without padding
      int x = 0, y = 0, width = 0, height = 0;
    };

    bool pack();
    quakelib::Vec2 atlasUv(const Surface &surface, const quakelib::Vec2 &uv) const;
    quakelib::Vec3 toBake(const godot::Vector3 &meters) const;

    std::vector<Surface> surfaces;
    quakelib::BakeOccluders occluders;
    std::vector<quakelib::BakeLight> lights;
    quakelib::BakeOptions options;
    bool has_worldspawn_options = false;

    int atlas_width = 0;
    int atlas_height = 0;
    quakelib::LightmapLayers layers;
    std::vector<uint8_t> lightmap;
    double bake_milliseconds = 0;

    float units_per_meter = 32.0f;
    float luxel_size = 16.0f;
    /// the least light every surface gets, 1 is normal brightness
    float minimum_light = 0.0f;
    /// added to the light everywhere, 1 is normal brightness
    godot::Color ambient_light{0, 0, 0};
    int padding = 2;
    /// suns per sky dome
    int sky_samples = 64;
    /// -1 as the maps say
    int bounces = -1;
    float bounce_subdivision = 64.0f;
    /// negative as the map says
    float bounce_scale = -1.0f;
  };

} // namespace libquake_godot

VARIANT_ENUM_CAST(libquake_godot::QuakeLightBaker::LightType);
