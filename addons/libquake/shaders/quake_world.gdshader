// Brush surfaces the way Quake draws them: texture times lightmap, fullbright pixels keep their color.
// Quake did that math on gamma encoded colors, so it happens here too. The baked light is emitted, Godot's
// real-time lights add to it.
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;

#include "res://addons/libquake/shaders/quake_color.gdshaderinc"
#include "res://addons/libquake/shaders/quake_dynamic_light.gdshaderinc"

uniform sampler2D albedo_texture : filter_nearest_mipmap, repeat_enable, hint_default_white;
// gamma encoded like the texture, for materials made from a StandardMaterial3D
uniform vec4 albedo_color = vec4(1.0);
uniform sampler2D emission_texture : filter_nearest_mipmap, repeat_enable, hint_default_black;
// 128 is normal brightness, so a surface can get up to twice as bright as its texture
uniform sampler2D lightmap_texture : filter_linear, repeat_disable;
// where UV2 lands in lightmap_texture: scale, offset. A QuakeLightmap sets it per mesh instance.
instance uniform vec4 lightmap_rect = vec4(1.0, 1.0, 0.0, 0.0);
// above 1 fullbright pixels pass the Environment's glow threshold and bloom
uniform float fullbright_energy = 1.0;
// tiling of materials made from a StandardMaterial3D, its uv1_scale and uv1_offset
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);

float max_component(vec3 color) {
	return max(color.r, max(color.g, color.b));
}

void vertex() {
	UV = UV * uv_scale + uv_offset;
}

void fragment() {
	vec4 albedo = texture(albedo_texture, UV) * albedo_color;
	// '{' textures: palette index 255 is a hole
	if (albedo.a < 0.5) {
		discard;
	}
	vec3 baked = texture(lightmap_texture, UV2 * lightmap_rect.xy + lightmap_rect.zw).rgb * 2.0;
	vec3 lit = quake_srgb_to_linear(albedo.rgb * baked);

	// glow is the share of fullbright pixels in this filtered texel
	vec3 emission = texture(emission_texture, UV).rgb;
	float glow = clamp(max_component(emission) / max(max_component(albedo.rgb), 0.001), 0.0, 1.0);
	EMISSION = mix(lit, quake_srgb_to_linear(emission) * fullbright_energy, glow);
	ALBEDO = quake_srgb_to_linear(albedo.rgb) * (1.0 - glow);
}

void light() {
	DIFFUSE_LIGHT += quake_dynamic_light(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
