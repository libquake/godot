#pragma once

#include <cstdint>
#include <quakelib/level.h>
#include <quakelib/wad/wad_manager.h>
#include <string>
#include <utility>
#include <vector>

namespace libquake_godot {

  struct TextureImage {
    int width = 0;
    int height = 0;
    std::vector<uint8_t> rgba;
    std::vector<uint8_t> emission; ///< black except fullbright pixels, empty without any
    std::vector<uint8_t> skyFront; ///< sky only, alpha 0 where the back layer shows
  };

  /// RGBA bytes of a wad texture's pixels
  std::vector<uint8_t> WadBytes(const quakelib::wad::cvec &colors);

  /// finds texture pixels in the level itself (bsp) or in .wad files (map)
  class TextureLookup {
  public:
    /// the wads a level names come first, then every wad in the folders
    void LoadWads(const std::vector<std::string> &names, const std::vector<std::string> &dirs);

    /// size in pixels for the texture uvs of .map files, fallback when no wad has the texture
    std::pair<int, int> Size(const std::string &name, std::pair<int, int> fallback);

    TextureImage Image(const quakelib::TextureInfo &info);

    /// average color of a wad texture (0..1), gray when no wad has it
    quakelib::Vec3 AverageColor(const std::string &name);

  private:
    quakelib::wad::QuakeWadManager wads;
  };

} // namespace libquake_godot
