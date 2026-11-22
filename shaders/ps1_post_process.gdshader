shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float color_levels : hint_range(8.0, 256.0) = 32.0; // 32 levels per channel = 15-bit PS1 RGB555
uniform float dither_strength : hint_range(0.0, 2.0) = 1.0;

// PS1 4x4 ordered Bayer dithering matrix
const mat4 BAYER_4X4 = mat4(
	vec4(-4.0,  0.0, -3.0,  1.0),
	vec4( 2.0, -2.0,  3.0, -1.0),
	vec4(-3.0,  1.0, -4.0,  0.0),
	vec4( 3.0, -1.0,  2.0, -2.0)
);

void fragment() {
	vec3 col = texture(screen_texture, SCREEN_UV).rgb;
	ivec2 px = ivec2(FRAGCOORD.xy) % 4;
	float bayer = BAYER_4X4[px.x][px.y];

	// Apply PS1 hardware dither offset and quantize to 5-bit per channel
	vec3 dithered = col + (bayer / 255.0) * dither_strength;
	vec3 quantized = floor(clamp(dithered, 0.0, 1.0) * color_levels + 0.5) / color_levels;

	COLOR = vec4(quantized, 1.0);
}
