// Inside a liquid: rows and columns sway on sines and the image is scaled in so the edges stay inside,
// then Quake's cshift blends the liquid's color over the finished image.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform vec3 shift_color = vec3(0.5, 0.3, 0.2);
uniform float shift = 0.5;

// of the image size
const float WARP_AMOUNT = 0.005;
// across the image
const float WARP_WAVES = 1.5;
// waves per second
const float WARP_SPEED = 0.4;

void fragment() {
	vec2 wave = sin((SCREEN_UV.yx * WARP_WAVES + TIME * WARP_SPEED) * TAU);
	vec2 uv = 0.5 + (SCREEN_UV - 0.5) * (1.0 - 2.0 * WARP_AMOUNT) + WARP_AMOUNT * wave;
	vec3 color = texture(screen_texture, uv).rgb;
	COLOR = vec4(mix(color, shift_color, shift), 1.0);
}
