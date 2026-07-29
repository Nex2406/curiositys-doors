// Main-menu colour grade.
//
// Reads whatever is drawn beneath it (the BGBase sprite, and later any parallax or
// mist layers) and grades it in one pass: light desaturation, a split-tone that
// pushes the browns violet while leaving the gold bloom warm, a violet shadow lift,
// a vignette, and two scrims that hold the title and the menu labels legible.
//
// Every value is a uniform: these are STARTING values derived from a brightness map
// of Tunnel 19, not from looking at the frame. The two scrim placements in
// particular are meant to be nudged live in the inspector.
shader_type canvas_item;

// The frame underneath. Sampling the screen rather than a texture uniform means the
// grade covers anything we add below it later without rewiring.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

// 1-3. desaturation. The source palette already sits close to target, so this is light.
uniform float desaturation : hint_range(0.0, 1.0) = 0.30;

// 4. split-tone. Multiplicative tints: >1.0 channels gain, <1.0 channels give way.
uniform vec3 shadow_tint : source_color = vec3(0.72, 0.66, 1.10);
uniform vec3 highlight_tint : source_color = vec3(1.06, 0.98, 0.88);
uniform vec2 shadow_range = vec2(0.05, 0.45);      // smoothstep edges for the shadow weight
uniform vec2 highlight_range = vec2(0.30, 0.75);   // ...and the highlight weight

// 5. shadows lift toward violet instead of crushing to black.
uniform vec3 shadow_lift = vec3(0.055, 0.040, 0.090);

// 6. exposure. Source mean is ~0.20, so this is a nudge, not a dim.
uniform float exposure : hint_range(0.0, 2.0) = 0.90;

// 7. vignette: flat inside `vignette_inner`, down to `vignette_corner` at the corners.
uniform float vignette_inner : hint_range(0.0, 1.0) = 0.34;
uniform float vignette_corner : hint_range(0.0, 1.0) = 0.35;

// 8. title scrim — the bloom peaks at ~0.80 luminance around x 64%, y 4-15%, which is
// under the title. Offset right of centre on purpose.
uniform vec2 title_scrim_centre = vec2(0.60, 0.17);
uniform vec2 title_scrim_radii = vec2(0.34, 0.24);
uniform float title_scrim_strength : hint_range(0.0, 1.0) = 0.55;

// 9. floor scrim — a lit patch at bottom-centre (~0.39) sits where menu labels land.
uniform float floor_scrim_start : hint_range(0.0, 1.0) = 0.62;
uniform float floor_scrim_strength : hint_range(0.0, 1.0) = 0.70;
uniform float floor_scrim_x_centre : hint_range(0.0, 1.0) = 0.50;
uniform float floor_scrim_x_falloff : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	// 2. luminance, Rec.601 weights
	float lum = dot(col, vec3(0.299, 0.587, 0.114));

	// 3. light desaturation
	col = mix(col, vec3(lum), desaturation);

	// 4. split-tone: browns go violet in the dark, the gold bloom stays warm
	float shadow_w = 1.0 - smoothstep(shadow_range.x, shadow_range.y, lum);
	float high_w = smoothstep(highlight_range.x, highlight_range.y, lum);
	col = mix(col, col * shadow_tint, shadow_w);
	col = mix(col, col * highlight_tint, high_w);

	// 5. lift the shadows toward violet rather than black
	col += shadow_lift * (1.0 - lum);

	// 6. exposure
	col *= exposure;

	// 7. radial vignette, normalised so r = 1.0 at the corners
	float r = length(UV - vec2(0.5)) / length(vec2(0.5));
	col *= mix(1.0, vignette_corner, smoothstep(vignette_inner, 1.0, r));

	// 8. title scrim: a soft ellipse, full strength at its core, feathered to nothing
	float td = length((UV - title_scrim_centre) / title_scrim_radii);
	col *= mix(1.0, title_scrim_strength, 1.0 - smoothstep(0.0, 1.0, td));

	// 9. floor scrim: increases downward from `floor_scrim_start`, strongest at centre-x
	float fy = smoothstep(floor_scrim_start, 1.0, UV.y);
	float fx = 1.0 - smoothstep(0.0, floor_scrim_x_falloff,
			abs(UV.x - floor_scrim_x_centre));
	col *= mix(1.0, floor_scrim_strength, fy * fx);

	COLOR = vec4(col, 1.0);
}
