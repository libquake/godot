#pragma once

#include <cstdint>
#include <godot_cpp/classes/image.hpp>
#include <vector>

namespace libquake_godot {

  /// An RGBA8 image from libquake's pixels, null if they do not fill width x height
  inline godot::Ref<godot::Image> MakeImage(int width, int height, const std::vector<uint8_t> &rgba) {
    if (width <= 0 || height <= 0 || rgba.size() != static_cast<size_t>(width) * height * 4)
      return {};
    godot::PackedByteArray data;
    data.resize(static_cast<int64_t>(rgba.size()));
    std::copy(rgba.begin(), rgba.end(), data.ptrw());
    return godot::Image::create_from_data(width, height, false, godot::Image::FORMAT_RGBA8, data);
  }

} // namespace libquake_godot
