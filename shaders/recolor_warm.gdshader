// Recolor any sprite into a warm two-point ramp by its own luminance, discarding
// the source hue entirely. Used in Realm 1 to turn R2's green jade into a gold
// shard and the violet life-eyes into warm amber, without editing shared art.
// Alpha (and the node's modulate, via the trailing *COLOR) are preserved, so the
// eyes' death-fade on modulate:a still works.
shader_type canvas_item;

uniform vec3 lo : source_color = vec3(0.12, 0.05, 0.01);  // shadow tone
uniform vec3 hi : source_color = vec3(1.0, 0.78, 0.32);   // highlight tone
uniform float boost = 1.0;                                 // lift dim source art

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float lum = clamp(dot(t.rgb, vec3(0.299, 0.587, 0.114)) * boost, 0.0, 1.0);
	vec3 col = mix(lo, hi, lum);
	COLOR = vec4(col, t.a) * COLOR;
}
