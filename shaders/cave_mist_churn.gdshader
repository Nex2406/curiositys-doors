// Churning cave mist. The older cave_mist scrolled two noise octaves sideways,
// which read as tidy horizontal streaks (Advika 2026-07-26: "too organised, make
// it chaotic topsy turvy"). This one domain-WARPS the lookup with a second noise
// field that itself drifts, samples three octaves at different speeds AND
// directions, and rotates each layer's sample space — so the air folds and
// tumbles instead of sliding.
shader_type canvas_item;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 tint = vec3(0.44, 0.40, 0.26);
uniform float strength = 0.30;
uniform float speed = 0.10;             // overall churn rate
uniform vec2 drift = vec2(1.0, -0.3);   // net direction the mass travels
uniform float warp = 0.45;              // how hard the field folds itself
uniform float scale_x = 2.2;
uniform float scale_y = 1.2;
uniform float y_shift = 0.0;
uniform float rot = 0.0;                // per-layer rotation of the sample space
uniform float contrast = 1.35;          // >1 eats the flat middle, leaves wisps
// vertical band the mist lives in: smoothstep(x,y) in, smoothstep(z,w) out
uniform vec4 band_zone = vec4(0.02, 0.30, 1.0, 0.68);

vec2 spin(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

void fragment() {
	vec2 uv = spin(vec2(UV.x * scale_x, UV.y * scale_y + y_shift), rot);
	float t = TIME * speed;
	// the warp field — two slow samples travelling opposite ways, pushing the
	// lookup around so straight streaks get folded into curls
	vec2 w = vec2(
			texture(noise_tex, uv * 0.60 + vec2(t * 0.70, -t * 0.45)).r,
			texture(noise_tex, uv * 0.55 + vec2(-t * 0.50, t * 0.65) + 3.10).r) - 0.5;
	vec2 p = uv + w * warp + drift * t;
	float n1 = texture(noise_tex, p).r;
	float n2 = texture(noise_tex, p * 1.90 + vec2(-t * 0.80, t * 0.35) + 7.30).r;
	float n3 = texture(noise_tex, p * 3.40 + vec2(t * 1.30, t * 0.90) + 1.70).r;
	float m = clamp(n1 * n2 * 1.7 + n3 * 0.22, 0.0, 1.0);
	m = pow(m, contrast);
	float band = smoothstep(band_zone.x, band_zone.y, UV.y)
			* smoothstep(band_zone.z, band_zone.w, UV.y);
	COLOR = vec4(tint, m * strength * band);
}
