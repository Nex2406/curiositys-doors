// Drifting cave mist: two scrolling noise octaves multiplied, tinted the
// fog's olive, alpha-banded so it lives in the frame's middle and dies at
// the edges. TIME-driven — the mist visibly crawls, each layer at its own
// speed/direction for the mysterious underground aura.
shader_type canvas_item;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 tint = vec3(0.40, 0.41, 0.21);
uniform float strength = 0.30;
uniform float speed = 0.015;
uniform float scale_x = 2.2;
uniform float scale_y = 1.2;
uniform float y_shift = 0.0;
// vertical band the mist lives in: smoothstep(x,y) in, smoothstep(z,w) out
uniform vec4 band_zone = vec4(0.02, 0.30, 1.0, 0.68);

void fragment() {
	float n1 = texture(noise_tex,
			vec2(UV.x * scale_x + TIME * speed,
			UV.y * scale_y + y_shift)).r;
	float n2 = texture(noise_tex,
			vec2(UV.x * scale_x * 1.7 - TIME * speed * 0.6,
			UV.y * scale_y * 1.3 + y_shift + 0.37)).r;
	float m = n1 * n2 * 1.7;
	float band = smoothstep(band_zone.x, band_zone.y, UV.y)
			* smoothstep(band_zone.z, band_zone.w, UV.y);
	COLOR = vec4(tint, clamp(m, 0.0, 1.0) * strength * band);
}
