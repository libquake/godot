// Quake's sky: two layers on a flattened sphere around the viewer. The back layer scrolls at 8 texels per
// second, the clouds in front at 16, both ignore the uvs of the faces.
shader_type spatial;
render_mode unshaded, fog_disabled;

uniform sampler2D back_layer : source_color, filter_nearest, repeat_enable;
// alpha 0 where the back layer shows
uniform sampler2D front_layer : source_color, filter_nearest, repeat_enable;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// the view direction in Quake axes (z up), squashed vertically like the original
	vec3 d = world_position - CAMERA_POSITION_WORLD;
	vec3 direction = vec3(d.x, -d.z, d.y * 3.0);
	vec2 st = direction.xy * (6.0 * 63.0 / length(direction));

	vec4 back = texture(back_layer, (st + mod(TIME * 8.0, 128.0)) / 128.0);
	vec4 front = texture(front_layer, (st + mod(TIME * 16.0, 128.0)) / 128.0);
	ALBEDO = mix(back.rgb, front.rgb, front.a);
}
