#include "texture_lookup.h"

#include <cstring>

namespace libquake_godot {

  namespace {} // namespace

  std::vector<uint8_t> WadBytes(const quakelib::wad::cvec &colors) {
    static_assert(sizeof(quakelib::wad::color) == 4);
    std::vector<uint8_t> out(colors.size() * 4);
    std::memcpy(out.data(), colors.data(), out.size());
    return out;
  }

  void TextureLookup::LoadWads(const std::vector<std::string> &names, const std::vector<std::string> &dirs) {
    for (const auto &name : names) {
      auto path = quakelib::wad::QuakeWadManager::FindWadFile(name, dirs);
      if (!path.empty())
        wads.AddWadFile(path);
    }
    for (const auto &dir : dirs)
      wads.AddWadDirectory(dir);
  }

  std::pair<int, int> TextureLookup::Size(const std::string &name, std::pair<int, int> fallback) {
    if (auto *texture = wads.FindTexture(name))
      return {static_cast<int>(texture->width), static_cast<int>(texture->height)};
    return fallback;
  }

  TextureImage TextureLookup::Image(const quakelib::TextureInfo &info) {
    if (!info.rgba.empty())
      return {info.width, info.height, info.rgba, info.emission, info.skyFront};

    auto *texture = wads.FindTexture(info.name);
    if (!texture || texture->raw.empty())
      return {};

    int width = static_cast<int>(texture->width);
    int height = static_cast<int>(texture->raw.size() / width);
    return {width, height, WadBytes(texture->raw), WadBytes(texture->emission), WadBytes(texture->front)};
  }

} // namespace libquake_godot
