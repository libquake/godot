// Quake did its color math on gamma encoded colors, this turns the result into the linear color Godot expects.
#ifndef QUAKE_COLOR
#define QUAKE_COLOR

vec3 quake_srgb_to_linear(vec3 color) {
	return mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)), step(0.04045, color));
}

#endif
