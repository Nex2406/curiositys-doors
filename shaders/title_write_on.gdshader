shader_type canvas_item;
// Title write-on. The title is a decorative serif, not a script face, so this does not
// read as handwriting — it reads as something being INSCRIBED, letter by letter, which is
// the right register for this game.
//
// All the sequencing lives in `order_map` (baked by tools/make_title_write_order.py): each
// pixel stores the moment it should appear, so this shader only has to compare.
//
// The map has the SAME dimensions as the title art, and a TextureRect drawing an
// AtlasTexture interpolates UV across the atlas source's space — so the same UV samples
// both, and the crop stays aligned for free.

uniform sampler2D order_map : hint_default_white, filter_linear, repeat_disable;
uniform float progress : hint_range(0.0, 1.0) = 1.0;
// Soft edge on the reveal. Without it the boundary is a hard wipe and the eye reads the
// straight vertical cut instead of the letters.
uniform float feather : hint_range(0.001, 0.1) = 0.015;
// The bright point that appears to be doing the writing. This is most of the effect.
uniform float nib_width : hint_range(0.002, 0.06) = 0.012;
uniform vec3 nib_color : source_color = vec3(1.0, 0.92, 0.72);
uniform float nib_strength : hint_range(0.0, 2.0) = 0.6;
// ...and the light it throws onto the dark AROUND the stroke. The ink is near-white, so
// brightening the ink alone clips and reads as nothing; this is what makes the nib visible.
// The map's green channel says how close each empty pixel is to its stroke.
uniform float halo_strength : hint_range(0.0, 2.0) = 0.85;

// The node's modulate, captured where it is CLEAN. In fragment(), COLOR has already been
// multiplied by the texture, so using it as a tint squares the art — and since the glow
// lives where the texture is transparent, that multiplied the glow away entirely. In
// vertex() COLOR is the modulate alone, which is what a tint actually is.
varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

// --- the resting glow: the letters lit from inside ------------------------------------
// Same proximity channel as the nib, shaped differently — the nib is a point travelling
// along the stroke, this is every written stroke holding light. It arrives WITH the
// writing (gated by the same reveal), so a letter is lit from the moment it exists.
uniform vec3 glow_color : source_color = vec3(1.0, 0.93, 0.78);
uniform float glow_strength : hint_range(0.0, 2.0) = 0.5;
// Exponent on nearness: higher hugs the letterform, lower spreads into a bloom. Under
// ~1.5 the two lines start bleeding into each other and the title turns to soup.
uniform float glow_tightness : hint_range(0.5, 8.0) = 2.2;
// A lantern is never perfectly steady. Slow and shallow — if you can watch it pulse, it
// is too much.
uniform float glow_pulse : hint_range(0.0, 1.0) = 0.16;
uniform float glow_period = 6.5;
// The ink itself lifts a little too, so the light reads as coming THROUGH the letter
// rather than sitting behind it. Small — the cream is already near-white.
uniform float glow_core : hint_range(0.0, 1.0) = 0.10;

void fragment() {
	// This shader builds its output from scratch, so the node's modulate has to be applied
	// by hand or it is thrown away — which is what happened when the frame started using
	// this shader: every adjustment to the border's weight silently did nothing.
	vec4 tint = v_modulate;

	vec4 tex = texture(TEXTURE, UV);
	vec2 map = texture(order_map, UV).rg;
	float order = map.r;
	float near = map.g;

	// Run the head of the reveal from BEFORE 0 to PAST 1, so progress = 0 hides everything
	// and progress = 1 shows everything. Comparing against raw progress left the first and
	// last strokes sitting at half alpha forever — order 1.0 against progress 1.0 lands in
	// the middle of the feather — which read as patches of the border being a different
	// colour from the rest.
	float p = mix(-feather, 1.0 + feather, progress);

	float reveal = 1.0 - smoothstep(p - feather, p + feather, order);

	// The last strokes carry order ~1.0, so at rest (progress = 1.0) the nib would sit on
	// the flourish tips forever. It dies over the final stretch instead — the pen lifts.
	float nib = exp(-pow((order - p) / nib_width, 2.0));
	nib *= 1.0 - smoothstep(0.94, 1.0, progress);

	float ink = tex.a * reveal;
	float outside = 1.0 - tex.a;
	// squared so the glow hugs the stroke instead of sitting in a flat disc around it
	float halo = clamp(halo_strength * nib * near * near * outside, 0.0, 1.0);

	float pulse = 1.0 + glow_pulse * sin(TIME * 6.2831853 / max(0.001, glow_period));
	float glow = clamp(glow_strength * pulse * pow(near, glow_tightness) * outside * reveal,
			0.0, 1.0);

	float a = clamp(ink + glow + halo, 0.0, 1.0);
	vec3 lit = tex.rgb + glow_color * glow_core * pulse + nib_color * nib * nib_strength;
	vec3 rgb = lit * ink + glow_color * glow + nib_color * halo;
	COLOR = vec4(rgb / max(a, 0.0001) * tint.rgb, a * tint.a);
}
