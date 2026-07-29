// Main-menu mist — one shader, instanced twice with independent uniforms (MistFar /
// MistNear). Domain-warped FBM so the mist CURLS instead of sliding as a flat sheet:
// the warp offset is itself sampled from a second, lower-frequency FBM.
//
// The bloom in Tunnel 19 measures at UV (0.49, 0.34) — a single soft source, dead
// centre horizontally. So the drift is LATERAL: air moving across a fixed light reads
// as air, where vertical movement would read as smoke, and this isn't a fire. The two
// layers counter-drift; that opposition is what sells the depth.
shader_type canvas_item;

uniform float noise_scale = 2.5;        // noise units across the viewport WIDTH
uniform float aspect = 1.777778;        // keeps cells square rather than stretched
uniform float drift = 0.008;            // UV per second; negative = right-to-left
uniform float warp_strength = 0.9;      // how hard the low-frequency field bends the high
// How fast the warp field itself evolves — the difference between mist that SLIDES past
// and mist that churns while it travels. 1.0 was the original rate; Advika wanted more
// movement, and raising this reads as more alive than simply drifting faster, which just
// turns the sheet into wallpaper scrolling by.
uniform float churn = 1.0;
uniform float contrast = 1.0;
uniform float opacity = 0.30;

// vertical density mask — 15% everywhere so the upper air isn't dead, ramping to full
// through the lower half so the mist never fogs the title
uniform float density_floor = 0.15;
uniform vec2 density_range = vec2(0.30, 0.75);

// LUMINANCE MASK. The vertical ramp alone lifted the shadow floor 50% (0.028 -> 0.043)
// while leaving the 95th percentile untouched — washed, not atmospheric. The darkness
// here isn't distributed vertically: the deepest blacks are the arch mouths at
// mid-height on both flanks, which a UV.y ramp structurally cannot protect.
// Masking by the background's own luminance is also the physically honest rule — mist
// is only visible where light scatters off it, and a pitch-black recess has nothing to
// scatter. The two masks multiply: vertical for composition, luminance for tone.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
// 0.05/0.18, not 0.06/0.30: the lower bound is effectively unchanged (a 0.029 shadow
// pixel still returns zero, so the near-black protection holds), but bringing the
// upper bound down to 0.18 is what lets the MID-TONES — 0.08-0.25, where most of this
// image actually lives — receive any mist at all.
uniform float lum_mask_lo = 0.05;   // below this background luminance, mist at `lum_mask_floor`
uniform float lum_mask_hi = 0.18;   // above this, full strength
// ...and the mask must never reach ZERO. That was the second half of the outline bug: with
// a floor of 0, the mist becomes a cutout of the lit parts of the painting — it is bright
// exactly on the lit floor and absent on the dark rock, so it hands you back the SHAPE of
// the floor as a glowing wedge with an edge along the rock. Blurring what it reads was not
// enough, because the lit floor is far bigger than any blur radius. Keeping a floor here
// means the dark areas still carry mist, just less of it, and the shape stops existing.
uniform float lum_mask_floor : hint_range(0.0, 1.0) = 0.55;

// coloured BY DISTANCE FROM THE LIGHT rather than one flat tint: mist crossing the
// bloom warms up, mist in the corners stays violet
uniform vec2 light_centre = vec2(0.49, 0.34);
uniform float tint_distance = 0.55;
uniform vec3 warm_tint : source_color = vec3(0.79, 0.66, 0.42);
uniform vec3 cool_tint : source_color = vec3(0.17, 0.13, 0.22);

// ...except that painting a fixed warm/violet pair OVER the frame reads as a coloured
// film laid on the art — you see the tint, not the air. Mist has no colour of its own; it
// only scatters the light already in the room. At 1.0 the mist borrows the background's
// own hue and merely brightens it, so it can never introduce a colour that wasn't there.
// The tints above stay as a seasoning, not as the source.
uniform float tint_from_bg : hint_range(0.0, 1.0) = 0.8;


// THE OUTLINE BUG. Both the luminance mask and the borrowed hue used to read the frame at
// full detail, one screen pixel at a time. That makes the mist's density and colour snap
// wherever the painting has an edge — so the mist traces every rock and arch back at you,
// and because the noise slides across those fixed contours the outline SWIMS. It reads as
// a hard outline over the art, which is exactly what it is.
//
// Light in a room doesn't work at that resolution. Sampling a wide average instead means
// the mist responds to where the room is bright, not to where the rock stops — the mask
// keeps doing its job and the contours vanish.
const int SOFT_TAPS = 12;
uniform float bg_softness : hint_range(0.0, 0.2) = 0.09;

vec3 soft_bg(vec2 uv) {
	vec3 sum = texture(screen_texture, uv).rgb;
	// two rings, offset half a step apart, so the taps never line up into a visible cross
	for (int i = 0; i < SOFT_TAPS; i++) {
		float a = 6.2831853 * float(i) / float(SOFT_TAPS);
		float r = bg_softness * ((i % 2 == 0) ? 1.0 : 0.55);
		sum += texture(screen_texture, uv + vec2(cos(a) * r, sin(a) * r)).rgb;
	}
	return sum / float(SOFT_TAPS + 1);
}


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}


float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}


// 4 octaves
float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p *= 2.02;
		a *= 0.5;
	}
	return s;
}


void fragment() {
	// square-celled noise space, drifting sideways
	vec2 p = vec2(UV.x * noise_scale, UV.y * noise_scale / aspect);
	p.x += TIME * drift * noise_scale;

	// the domain warp: a SECOND, lower-frequency field displaces the first
	vec2 q = vec2(fbm(p * 0.5 + vec2(0.0, TIME * 0.02 * churn)),
			fbm(p * 0.5 + vec2(5.2, 1.3) - vec2(0.0, TIME * 0.015 * churn)));
	float n = fbm(p + warp_strength * q);

	n = clamp((n - 0.5) * contrast + 0.5, 0.0, 1.0);

	float density = density_floor + (1.0 - density_floor)
			* smoothstep(density_range.x, density_range.y, UV.y);

	vec3 bg = soft_bg(SCREEN_UV);
	float bg_lum = dot(bg, vec3(0.299, 0.587, 0.114));
	density *= mix(lum_mask_floor, 1.0, smoothstep(lum_mask_lo, lum_mask_hi, bg_lum));

	float d = clamp(distance(UV, light_centre) / tint_distance, 0.0, 1.0);
	vec3 col = mix(warm_tint, cool_tint, d);

	// the background's own colour, renormalised to a steady brightness so dark corners
	// scatter as much as lit ones — this is hue borrowed, not luminance copied
	vec3 scattered = clamp(bg / max(bg_lum, 0.02) * 0.42, vec3(0.0), vec3(1.0));
	col = mix(col, scattered, tint_from_bg);

	COLOR = vec4(col, n * opacity * density);
}
