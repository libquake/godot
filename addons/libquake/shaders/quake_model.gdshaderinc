// Lights a model the way Quake lights its models: one light value for the whole model, read from the level
// by a QuakeLightReceiver, plus a fixed direction that shades the sides. Like the world, the math happens
// on gamma encoded colors, so pass colors as they appear (no source_color hint on textures and colors).
// The level's light is emitted, so Godot's real-time lights can add to it:
//   render_mode ambient_light_disabled, specular_disabled;
//   fragment(): EMISSION = quake_model_color(albedo, NORMAL); ALBEDO = quake_srgb_to_linear(albedo);
//   light():    DIFFUSE_LIGHT += quake_dynamic_light(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);

#include "res://addons/libquake/shaders/quake_color.gdshaderinc"
#include "res://addons/libquake/shaders/quake_dynamic_light.gdshaderinc"

// set per instance by QuakeLightReceiver, 1.0 is normal brightness
instance uniform vec3 quake_light = vec3(1.0);

// Quake shades faces towards the light up to 1.4 times, faces away down to 0.6 times
const vec3 QUAKE_SHADE_DIRECTION = vec3(0.0, 0.6, 0.8);
const float QUAKE_SHADE_AMOUNT = 0.4;

// albedo is gamma encoded, view_normal is NORMAL from fragment(); returns the linear color for EMISSION
vec3 quake_model_color(vec3 albedo, vec3 view_normal) {
	float shade = 1.0 + QUAKE_SHADE_AMOUNT * dot(normalize(view_normal), normalize(QUAKE_SHADE_DIRECTION));
	return quake_srgb_to_linear(clamp(albedo * quake_light * shade, 0.0, 1.0));
}
