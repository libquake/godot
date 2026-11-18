// Water, slime, lava and teleporters: unlit like in Quake, warped by a turbulence like software Quake's
// but tighter (4 texels deep, a wave every 64 texels).
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform float alpha = 1.0;
// above 1 it glows like lava
uniform float brightness = 1.0;

const float WARP_AMOUNT = 4.0;
const float WARP_CYCLE = 64.0;
// texels per second, one radian per second like Quake
const float WARP_SPEED = 10.0;

void fragment() {
	vec2 size = vec2(textureSize(albedo_texture, 0));
	vec2 texel = UV * size;
	texel += WARP_AMOUNT * sin((texel.yx + TIME * WARP_SPEED) * (TAU / WARP_CYCLE));
	ALBEDO = texture(albedo_texture, texel / size).rgb * brightness;
	ALPHA = alpha;
}
