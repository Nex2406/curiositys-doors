// A background mass standing in fog: the sprite's ALPHA is the shape,
// painted mostly a flat fog-family color (flat_col), with an optional
// whisper of the art's own shading (detail, art tinted by brighten).
// Kills outline fringes and lets a piece sit at any exact value.
shader_type canvas_item;
uniform vec4 flat_col : source_color = vec4(0.4, 0.4, 0.2, 1.0);
uniform vec3 brighten = vec3(1.0, 1.2, 0.75);
uniform float detail : hint_range(0.0, 1.0) = 0.2;
// dissolve the piece's base: alpha fades over this bottom fraction of the
// sprite so it sinks into fog instead of ending on an edge
uniform float base_fade : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec3 col = mix(flat_col.rgb, t.rgb * brighten, detail);
	float a = t.a * flat_col.a;
	if (base_fade > 0.0) {
		a *= smoothstep(1.0, 1.0 - base_fade, UV.y);
	}
	COLOR = vec4(col, a);
}
