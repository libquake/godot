#include "quake_light_style_animator.h"

#include <algorithm>
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

namespace libquake_godot {

  void QuakeLightStyleAnimator::setup(const Dictionary &layers) {
    lightmap = {};
    rgba.clear();
    lightmap.width = layers.get("width", 0);
    lightmap.height = layers.get("height", 0);
    PackedInt32Array styles = layers.get("styles", PackedInt32Array());
    Array data = layers.get("layers", Array());
    ERR_FAIL_COND_MSG(styles.size() != data.size(), "QuakeLightStyleAnimator: one layer per style.");
    for (int64_t i = 0; i < styles.size(); i++) {
      PackedByteArray layer = data[i];
      ERR_FAIL_COND(layer.size() != static_cast<int64_t>(lightmap.width) * lightmap.height * 4);
      lightmap.styles.push_back(styles[i]);
      lightmap.layers.emplace_back(layer.ptr(), layer.ptr() + layer.size());
    }
  }

  bool QuakeLightStyleAnimator::update(double time) {
    if (lightmap.Empty())
      return false;
    bool changed = animator.Update(time, lightmap) || rgba.empty();
    if (changed)
      animator.Recompose(lightmap, rgba);
    return changed;
  }

  PackedByteArray QuakeLightStyleAnimator::get_rgba() const {
    PackedByteArray result;
    result.resize(static_cast<int64_t>(rgba.size()));
    std::copy(rgba.begin(), rgba.end(), result.ptrw());
    return result;
  }

  void QuakeLightStyleAnimator::set_style(int style, const String &pattern) {
    ERR_FAIL_INDEX(style, quakelib::LightStyleAnimator::MaxStyles);
    animator.SetStyle(style, pattern.utf8().get_data());
  }

  String QuakeLightStyleAnimator::get_style(int style) const {
    ERR_FAIL_INDEX_V(style, quakelib::LightStyleAnimator::MaxStyles, String());
    return String(animator.Style(style).c_str());
  }

  Dictionary QuakeLightStyleAnimator::layers_to_dictionary(const quakelib::LightmapLayers &lightmap) {
    bool animated = std::ranges::any_of(lightmap.styles, [](int style) { return style != 0; });
    if (lightmap.Empty() || !animated)
      return {};
    PackedInt32Array styles;
    Array layers;
    for (size_t i = 0; i < lightmap.layers.size(); i++) {
      styles.push_back(lightmap.styles[i]);
      PackedByteArray layer;
      layer.resize(static_cast<int64_t>(lightmap.layers[i].size()));
      std::copy(lightmap.layers[i].begin(), lightmap.layers[i].end(), layer.ptrw());
      layers.push_back(layer);
    }
    Dictionary result;
    result["width"] = lightmap.width;
    result["height"] = lightmap.height;
    result["styles"] = styles;
    result["layers"] = layers;
    return result;
  }

  void QuakeLightStyleAnimator::_bind_methods() {
    ClassDB::bind_method(D_METHOD("setup", "layers"), &QuakeLightStyleAnimator::setup);
    ClassDB::bind_method(D_METHOD("update", "time"), &QuakeLightStyleAnimator::update);
    ClassDB::bind_method(D_METHOD("get_rgba"), &QuakeLightStyleAnimator::get_rgba);
    ClassDB::bind_method(D_METHOD("set_style", "style", "pattern"), &QuakeLightStyleAnimator::set_style);
    ClassDB::bind_method(D_METHOD("get_style", "style"), &QuakeLightStyleAnimator::get_style);
  }

} // namespace libquake_godot
