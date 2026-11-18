#include "quake_level.h"
#include "quake_light_baker.h"
#include "quake_light_style_animator.h"
#include "quake_wad.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

namespace {
  void initialize(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE)
      return;
    GDREGISTER_CLASS(libquake_godot::QuakeLevel);
    GDREGISTER_CLASS(libquake_godot::QuakeLightBaker);
    GDREGISTER_CLASS(libquake_godot::QuakeLightStyleAnimator);
    GDREGISTER_CLASS(libquake_godot::QuakeWad);
  }

  void uninitialize(ModuleInitializationLevel) {}
} // namespace

extern "C" GDExtensionBool GDE_EXPORT
libquake_library_init(GDExtensionInterfaceGetProcAddress get_proc_address, GDExtensionClassLibraryPtr library,
                      GDExtensionInitialization *initialization) {
  GDExtensionBinding::InitObject init(get_proc_address, library, initialization);
  init.register_initializer(initialize);
  init.register_terminator(uninitialize);
  init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
  return init.init();
}
