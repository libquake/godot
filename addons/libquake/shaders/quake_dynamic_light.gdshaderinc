// Godot's real-time lights on Quake surfaces, for what Quake did with dynamic lights: muzzle flashes, rockets,
// explosions. No specular, and the angle only matters half, like the light tools' default _anglescale.
// Use in light(): DIFFUSE_LIGHT += quake_dynamic_light(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
#ifndef QUAKE_DYNAMIC_LIGHT
#define QUAKE_DYNAMIC_LIGHT

// below this facing the angle independent half fades out, a hard edge would show across curved models
const float QUAKE_LIGHT_TERMINATOR = 0.2;

vec3 quake_dynamic_light(vec3 normal, vec3 light_direction, vec3 light_color, float attenuation) {
	float facing = dot(normal, light_direction);
	if (facing <= 0.0) {
		return vec3(0.0);
	}
	float angle_independent = 0.5 * min(facing / QUAKE_LIGHT_TERMINATOR, 1.0);
	return light_color / PI * attenuation * (angle_independent + 0.5 * facing);
}

#endif
