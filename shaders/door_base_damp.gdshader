// Knocks down the bottom of the portal art.
//
// realm1door12.png paints its base stones as bright lavender with a glow at the very
// foot, which made the FLOOR of the door the brightest thing on screen — the eye went
// down to the rubble instead of through the opening. This darkens only the door's own
// pixels (a multiply overlay would have dimmed the cave behind it too), leaving the
// arch and the opening untouched.
shader_type canvas_item;

uniform float damp_start : hint_range(0.0, 1.0) = 0.55;   // where the fade begins, in UV.y
uniform float damp_amount : hint_range(0.0, 1.0) = 0.45;  // how far the very bottom drops

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(c.rgb * (1.0 - damp_amount * smoothstep(damp_start, 1.0, UV.y)), c.a);
}
