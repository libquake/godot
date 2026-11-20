cmake_minimum_required(VERSION 3.24)
project(libquake_godot LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
if(APPLE)
  # universal; FORCE, project() already made the cache entries
  set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "" FORCE)
  set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0" CACHE STRING "" FORCE)
endif()

set(LIBQUAKE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../libquake" CACHE PATH "libquake checkout")
set(ADDON_BIN_DIR "${CMAKE_CURRENT_SOURCE_DIR}/addons/libquake/bin")

include(FetchContent)
FetchContent_Declare(
  godot-cpp
  GIT_REPOSITORY https://github.com/godotengine/godot-cpp.git
  GIT_TAG godot-4.5-stable
  GIT_SHALLOW TRUE
)
# libquake reports broken files with exceptions
set(GODOTCPP_DISABLE_EXCEPTIONS OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(godot-cpp)

# libquake only builds as a shared library, so its sources are compiled into a static one here
file(READ "${LIBQUAKE_DIR}/src/CMakeLists.txt" LIBQUAKE_SOURCE_LIST)
string(REGEX MATCHALL "[A-Za-z0-9_/]+\\.cpp" LIBQUAKE_SOURCES "${LIBQUAKE_SOURCE_LIST}")
list(TRANSFORM LIBQUAKE_SOURCES PREPEND "${LIBQUAKE_DIR}/src/")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${LIBQUAKE_DIR}/src/CMakeLists.txt")
add_library(quakelib_static STATIC ${LIBQUAKE_SOURCES})
target_include_directories(quakelib_static PUBLIC "${LIBQUAKE_DIR}/include")
find_package(Threads REQUIRED)
target_link_libraries(quakelib_static PUBLIC Threads::Threads)

# the baker's ray backend: Embree where libquake has a prebuilt for the platform, its own bvh elsewhere.
# Releases up to v1.1.0 keep the bvh inside the baker.
if(EXISTS "${LIBQUAKE_DIR}/cmake/embree.cmake")
  # godot-cpp links the C runtime statically on Windows, Embree has to match
  if(MSVC AND GODOTCPP_USE_STATIC_CPP)
    set(QLIB_EMBREE_STATIC_RUNTIME ON CACHE BOOL "" FORCE)
  endif()
  include("${LIBQUAKE_DIR}/cmake/embree.cmake")
  target_sources(quakelib_static PRIVATE ${QLIB_BVH_SOURCE})
  if(TARGET quakelib_embree)
    target_link_libraries(quakelib_static PUBLIC quakelib_embree)
  endif()
endif()

add_library(libquake_godot SHARED
  src/register_types.cpp
  src/quake_level.cpp
  src/quake_light_baker.cpp
  src/texture_lookup.cpp
  src/light_grid.cpp
  src/quake_light_style_animator.cpp
  src/quake_wad.cpp
)
target_link_libraries(libquake_godot PRIVATE godot-cpp quakelib_static)
set_target_properties(libquake_godot PROPERTIES
  OUTPUT_NAME "libquake"
  PREFIX ""
  LIBRARY_OUTPUT_DIRECTORY "${ADDON_BIN_DIR}"
  RUNTIME_OUTPUT_DIRECTORY "${ADDON_BIN_DIR}"
)
foreach(config ${CMAKE_CONFIGURATION_TYPES})
  string(TOUPPER ${config} config)
  set_target_properties(libquake_godot PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY_${config} "${ADDON_BIN_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_${config} "${ADDON_BIN_DIR}")
endforeach()
