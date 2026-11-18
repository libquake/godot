// A model lit like Quake's models, see quake_model.gdshaderinc. Needs a QuakeLightReceiver.
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;

#include "res://addons/libquake/shaders/quake_model.gdshaderinc"

uniform sampler2D albedo_texture : filter_nearest_mipmap, hint_default_white;
uniform vec4 albedo_color = vec4(1.0);

void fragment() {
	vec4 albedo = texture(albedo_texture, UV) * albedo_color;
	if (albedo.a < 0.5) {
		discard;
	}
	EMISSION = quake_model_color(albedo.rgb, NORMAL);
	ALBEDO = quake_srgb_to_linear(albedo.rgb);
}

void light() {
	DIFFUSE_LIGHT += quake_dynamic_light(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
