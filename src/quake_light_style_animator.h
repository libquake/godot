#pragma once

// before godot-cpp, its CMP_EPSILON macro breaks quakelib's constant of that name
#include <quakelib/level.h>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/typed_array.hpp>

namespace libquake_godot {

  /// Quake's light styles on a lightmap split into one layer per style: composes them with the current value
  /// of each style, ten steps per second like the engine. Only texels of styles that changed are rewritten.
  class QuakeLightStyleAnimator : public godot::RefCounted {
    GDCLASS(QuakeLightStyleAnimator, godot::RefCounted)

  public:
    /// layers: RGBA per style, the result of get_lightmap_layers() on QuakeLevel or QuakeLightBaker
    void setup(const godot::Dictionary &layers);
    /// true if the lightmap changed, get_rgba() has it then
    bool update(double time);
    godot::PackedByteArray get_rgba() const;

    /// Quake's lightstyle(): one letter per tenth of a second, 'a' is dark, 'm' normal, 'z' double
    void set_style(int style, const godot::String &pattern);
    godot::String get_style(int style) const;

    /// the lightmap's layers as setup() takes them, empty without animated styles
    static godot::Dictionary layers_to_dictionary(const quakelib::LightmapLayers &lightmap);

  protected:
    static void _bind_methods();

  private:
    quakelib::LightmapLayers lightmap;
    quakelib::LightStyleAnimator animator;
    std::vector<uint8_t> rgba;
  };

} // namespace libquake_godot
