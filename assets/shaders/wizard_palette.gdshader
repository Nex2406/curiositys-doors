shader_type canvas_item;

// THE CONJURER'S PALETTE — one shader, worn by everything he makes.
//
// The wizard is drawn in a blue indigo: his mid-tones measure around (32,32,64)
// and (48,48,80), where red and green sit level and blue carries the colour —
// hue ~240 degrees at about 0.4 saturation. His creatures were not. The void
// moth measures (48,16,80) and (32,16,64): red well clear of green, hue ~270,
// saturation ~0.8. That gap is the whole of Advika's *"the void moth is too
// purple"* — it is a violet thing in an indigo wizard's level, so it reads as
// belonging to somebody else. The rune orbs have the same problem from the
// other side, their gold banding pulling them warm.
//
// Recolouring the sheets would mean repainting every frame of every animation,
// so the correction is done in the render instead: rotate the hue onto his and
// pull the saturation down to his, leaving the drawn light, shading and detail
// exactly as painted. Nothing is flattened and nothing is tinted over — the art
// keeps its own values and only its colour family moves.
//
// Defaults are the moth's numbers: -30 degrees lands 270 on 240, and 0.62
// saturation lands 0.8 on ~0.5. The orbs override both.

// turns of hue, so -0.0833 is -30 degrees
uniform float hue_shift : hint_range(-0.5, 0.5) = -0.0833;
// ROTATE vs LOCK. A rotation only works on art that is one colour family — the
// moth is all violet, so turning it lands the whole creature together. The rune
// orbs are two families at once, a grey-blue crystal in warm gold banding, and
// they sit on opposite sides of the wheel: any single rotation that carries the
// gold home drags the crystal off to yellow, and the first attempt at +165 came
// out mint and tan. So an orb LOCKS instead — every hue collapsed onto his one
// hue, saturation and value left exactly as painted, so the banding still reads
// as banding by its brightness rather than by being a different colour.
uniform float hue_target : hint_range(0.0, 1.0) = 0.667;  // 240 degrees: the wizard's indigo
uniform float hue_lock : hint_range(0.0, 1.0) = 0.0;      // 0 rotates, 1 locks
uniform float sat_scale : hint_range(0.0, 2.0) = 0.62;
uniform float value_scale : hint_range(0.0, 2.0) = 1.0;
// how completely the shift applies: 0 leaves the art alone, 1 is the full move.
// A dial rather than a rebuild, for tuning against the level with the game running.
uniform float amount : hint_range(0.0, 1.0) = 1.0;

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

// COLOR arrives already carrying the texture times the node's modulate, so the
// shift is done on it in place. That is deliberate rather than reading TEXTURE
// and re-applying MODULATE by hand: MODULATE is not exposed to canvas_item
// fragment in this build, and doing it this way keeps the hit flashes intact —
// the moth's strike drives modulate to (2.4, 2.0, 2.6), value stays above 1.0
// through the round trip, and a near-white flash has almost no saturation left
// for the rotation to move anyway.
void fragment() {
	vec3 hsv = rgb_to_hsv(COLOR.rgb);
	hsv.x = mix(fract(hsv.x + hue_shift), hue_target, hue_lock);
	hsv.y = clamp(hsv.y * sat_scale, 0.0, 1.0);
	hsv.z = hsv.z * value_scale;
	// mix against the untouched art so `amount` can dial the whole thing back
	COLOR.rgb = mix(COLOR.rgb, hsv_to_rgb(hsv), amount);
}
