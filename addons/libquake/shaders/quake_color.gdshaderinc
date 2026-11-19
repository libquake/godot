// Quake did its color math on gamma encoded colors, this turns the result into the linear color Godot expects.
#ifndef QUAKE_COLOR
#define QUAKE_COLOR

vec3 quake_srgb_to_linear(vec3 color) {
	return mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)), step(0.04045, color));
}

// for source_color uniforms, which Godot hands over linear
vec3 quake_linear_to_srgb(vec3 color) {
	return mix(color * 12.92, 1.055 * pow(color, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, color));
}

#endif
