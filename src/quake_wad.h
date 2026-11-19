#pragma once

// before godot-cpp, its CMP_EPSILON macro breaks quakelib's constant of that name
#include <quakelib/qmath.h>
#include <quakelib/wad/wad.h>

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/ref_counted.hpp>

namespace libquake_godot {

  /// The textures of a .wad file as images.
  class QuakeWad : public godot::RefCounted {
    GDCLASS(QuakeWad, godot::RefCounted)

  public:
    godot::Error load(const godot::String &path);
    godot::PackedStringArray get_texture_names() const;
    godot::Ref<godot::Image> get_texture_image(const godot::String &name) const;
    /// black except the fullbright pixels, null without any
    godot::Ref<godot::Image> get_texture_emission(const godot::String &name) const;
    /// sky textures: the cloud layer, alpha 0 where the back layer shows
    godot::Ref<godot::Image> get_sky_front_image(const godot::String &name) const;

  protected:
    static void _bind_methods();

  private:
    quakelib::wad::QuakeTexture *texture(const godot::String &name) const;
    godot::Ref<godot::Image> image(const quakelib::wad::QuakeTexture &texture,
                                   const quakelib::wad::cvec &pixels) const;

    quakelib::wad::QuakeWadPtr wad;
  };

} // namespace libquake_godot
