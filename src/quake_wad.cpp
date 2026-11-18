#include "quake_wad.h"

#include "image_util.h"
#include "texture_lookup.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace libquake_godot {

  Error QuakeWad::load(const String &path) {
    try {
      wad = quakelib::wad::QuakeWad::FromFile(path.utf8().get_data());
    } catch (const std::exception &e) {
      UtilityFunctions::push_error(vformat("libquake: %s: %s", path, e.what()));
      wad = nullptr;
    }
    return wad ? OK : ERR_FILE_CANT_OPEN;
  }

  PackedStringArray QuakeWad::get_texture_names() const {
    PackedStringArray names;
    if (!wad)
      return names;
    for (const auto &[name, entry] : wad->Textures())
      if (entry.Type() == quakelib::wad::QuakeWadEntry::QWET_MipsTexture)
        names.push_back(String(name.c_str()));
    return names;
  }

  Ref<Image> QuakeWad::get_texture_image(const String &name) const {
    auto *found = texture(name);
    return found ? image(*found, found->raw) : Ref<Image>();
  }

  Ref<Image> QuakeWad::get_texture_emission(const String &name) const {
    auto *found = texture(name);
    return found && found->hasEmission ? image(*found, found->emission) : Ref<Image>();
  }

  Ref<Image> QuakeWad::get_sky_front_image(const String &name) const {
    auto *found = texture(name);
    return found ? image(*found, found->front) : Ref<Image>();
  }

  quakelib::wad::QuakeTexture *QuakeWad::texture(const String &name) const {
    return wad ? wad->GetTexture(name.utf8().get_data()) : nullptr;
  }

  /// the width of the texture, the height from its pixels: a sky's layers are half as wide as the miptex
  Ref<Image> QuakeWad::image(const quakelib::wad::QuakeTexture &texture,
                             const quakelib::wad::cvec &pixels) const {
    if (pixels.empty() || texture.width == 0)
      return {};
    int width = static_cast<int>(texture.width);
    return MakeImage(width, static_cast<int>(pixels.size() / width), WadBytes(pixels));
  }

  void QuakeWad::_bind_methods() {
    ClassDB::bind_method(D_METHOD("load", "path"), &QuakeWad::load);
    ClassDB::bind_method(D_METHOD("get_texture_names"), &QuakeWad::get_texture_names);
    ClassDB::bind_method(D_METHOD("get_texture_image", "name"), &QuakeWad::get_texture_image);
    ClassDB::bind_method(D_METHOD("get_texture_emission", "name"), &QuakeWad::get_texture_emission);
    ClassDB::bind_method(D_METHOD("get_sky_front_image", "name"), &QuakeWad::get_sky_front_image);
  }

} // namespace libquake_godot
