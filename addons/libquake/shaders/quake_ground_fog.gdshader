// QuakeGroundFog: fog lying on the floor of a box, its top rolling in noise hills, fading out toward the box's
// sides. Drawn on the box's back faces with the depth test off, so it shows from inside too; the view ray is
// marched from where it enters the box to the box's far side or the scene, whichever comes first. What stands
// in the box pokes out of the fog.
shader_type spatial;
render_mode unshaded, cull_front, depth_test_disabled, depth_draw_never, blend_mix, fog_disabled, shadows_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D noise_texture : filter_linear, repeat_enable;

// Half the box, in the mesh's own space (the box is centered on it)
uniform vec3 half_size = vec3(4.0, 1.0, 4.0);
// How high (m) the fog stands above the box's floor, before the hills
uniform float fog_height = 0.6;
// How far (m) below its top the fog reaches full density
uniform float top_softness = 0.4;
uniform float density = 1.2;
uniform vec4 fog_color : source_color = vec4(0.36, 0.32, 0.27, 1.0);
// Fades the fog out within this distance (m) of the box's sides
uniform float edge_fade = 1.0;
// Fades the fog out within this distance (m) of the camera, so crouching in it does not black out the view
uniform float camera_fade = 0.5;

// How far the top rolls up and down, as a share of fog_height
uniform float hill_amount = 0.5;
// Hill frequency (1/m)
uniform float hill_scale = 0.15;
uniform vec2 wind = vec2(0.03, 0.012);
// Second noise layer drifting the other way, so the hills change shape instead of just sliding
uniform float morph_speed = 0.15;

// Retro look: world aligned fog pixels, banded and dithered alpha, choppy animation
// World size (m) of one fog pixel, 0 = smooth. Quake textures are 1/32 m a texel, 1/8 reads as chunky
uniform float pixel_size = 0.125;
// Opacity levels, 0 = smooth, 1 = pure screen door
uniform int alpha_steps = 4;
// 0 = hard bands between the levels, 1 = ordered (Bayer) dither between them
uniform float dither : hint_range(0.0, 1.0) = 1.0;
// Screen pixels per dither cell
uniform int dither_scale = 2;
// Frames per second the fog animates at, 0 = every frame
uniform float anim_fps = 12.0;
// Samples along the view ray, the dither hides the steps between them
uniform int steps = 8;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

// The camera and this vertex in the box's space, the ray between them crosses the box
varying vec3 v_ray_origin;
varying vec3 v_ray_end;

float bayer(ivec2 cell) {
	cell %= 4;
	return (BAYER[cell.y * 4 + cell.x] + 0.5) / 16.0;
}

// p in the box's space, xz the same point in the world (the hills are world aligned across boxes)
float density_at(vec3 p, vec2 xz, float t) {
	if (pixel_size > 0.0) {
		xz = (floor(xz / pixel_size) + 0.5) * pixel_size;
	}
	vec2 q = xz * hill_scale;
	float n = textureLod(noise_texture, q + t * wind, 0.0).r * 0.6
			+ textureLod(noise_texture, q * 1.7 + vec2(-wind.y, wind.x) * t * morph_speed * 10.0, 0.0).r * 0.4;
	float top = fog_height * (1.0 + hill_amount * (n * 2.0 - 1.0));
	float above_floor = p.y + half_size.y;
	float vertical = 1.0 - smoothstep(top - top_softness, top, above_floor);
	vec2 inside = half_size.xz - abs(p.xz);
	float edge = smoothstep(0.0, edge_fade, min(inside.x, inside.y));
	return density * vertical * edge;
}

void vertex() {
	v_ray_origin = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	v_ray_end = VERTEX;
}

void fragment() {
	// The ray runs from the camera (s = 0) to this back face (s = 1), in the box's space
	vec3 ro = v_ray_origin;
	vec3 rd = v_ray_end - ro;
	float frag_dist = length(VERTEX);

	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_s = length(view.xyz / view.w) / frag_dist;

	// Only the slab the fog can reach is marched, from the floor to the highest hill
	float top_max = min(fog_height * (1.0 + hill_amount), 2.0 * half_size.y);
	vec3 box_min = -half_size;
	vec3 box_max = vec3(half_size.x, top_max - half_size.y, half_size.z);
	vec3 inv = 1.0 / mix(rd, vec3(1e-6), equal(rd, vec3(0.0)));
	vec3 ta = (box_min - ro) * inv;
	vec3 tb = (box_max - ro) * inv;
	vec3 near = min(ta, tb);
	vec3 far = max(ta, tb);
	float s0 = max(max(near.x, near.y), max(near.z, 0.0));
	float s1 = min(min(far.x, far.y), min(far.z, scene_s));
	if (s1 <= s0) {
		discard;
	}

	float t = anim_fps > 0.0 ? floor(TIME * anim_fps) / anim_fps : TIME;
	ivec2 cell = ivec2(FRAGCOORD.xy) / max(dither_scale, 1);
	// Transposed cell for the march offset, so it does not line up with the alpha threshold below
	float jitter = mix(0.5, bayer(cell.yx), dither);
	int n = max(steps, 1);
	float ds = (s1 - s0) / float(n);
	float tau = 0.0;
	for (int i = 0; i < n; i++) {
		float s = s0 + (float(i) + jitter) * ds;
		vec3 p = ro + rd * s;
		tau += density_at(p, (MODEL_MATRIX * vec4(p, 1.0)).xz, t) * smoothstep(0.0, camera_fade, s * frag_dist);
	}
	tau *= ds * frag_dist;

	float alpha = (1.0 - exp(-tau)) * fog_color.a;
	if (alpha_steps > 0) {
		float steps_f = float(alpha_steps);
		alpha = clamp(floor(alpha * steps_f + mix(0.5, bayer(cell), dither)) / steps_f, 0.0, 1.0);
	}
	ALBEDO = fog_color.rgb;
	ALPHA = alpha;
}
