// A Quake skybox, six images around the viewer as Quakespasm draws them (after Quake 2): rt, bk, lf, ft, up
// and dn look along +x, +y, -x, -y, +z and -z in Quake axes, each image upright as seen from inside.
shader_type spatial;
render_mode unshaded, fog_disabled;

// no mipmaps: the face changes from one pixel to the next, the derivatives there would blur its edges
uniform sampler2D rt : source_color, filter_linear, repeat_disable;
uniform sampler2D bk : source_color, filter_linear, repeat_disable;
uniform sampler2D lf : source_color, filter_linear, repeat_disable;
uniform sampler2D ft : source_color, filter_linear, repeat_disable;
uniform sampler2D up : source_color, filter_linear, repeat_disable;
uniform sampler2D dn : source_color, filter_linear, repeat_disable;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// the view direction in Quake axes (z up)
	vec3 d = world_position - CAMERA_POSITION_WORLD;
	vec3 q = vec3(d.x, -d.z, d.y);
	vec3 a = abs(q);
	// s runs to the image's right, t to its top, both -1..1 on the face
	vec2 st;
	vec3 color;
	if (a.x >= a.y && a.x >= a.z) {
		st = q.x > 0.0 ? vec2(-q.y, q.z) / a.x : vec2(q.y, q.z) / a.x;
		vec2 uv = vec2(st.x + 1.0, 1.0 - st.y) * 0.5;
		color = q.x > 0.0 ? texture(rt, uv).rgb : texture(lf, uv).rgb;
	} else if (a.y >= a.z) {
		st = q.y > 0.0 ? vec2(q.x, q.z) / a.y : vec2(-q.x, q.z) / a.y;
		vec2 uv = vec2(st.x + 1.0, 1.0 - st.y) * 0.5;
		color = q.y > 0.0 ? texture(bk, uv).rgb : texture(ft, uv).rgb;
	} else {
		st = q.z > 0.0 ? vec2(-q.y, -q.x) / a.z : vec2(-q.y, q.x) / a.z;
		vec2 uv = vec2(st.x + 1.0, 1.0 - st.y) * 0.5;
		color = q.z > 0.0 ? texture(up, uv).rgb : texture(dn, uv).rgb;
	}
	ALBEDO = color;
}
