// A mass standing IN the diagonal fog spill: its color is the LOCAL fog
// color (same spill math as cave_fog_spill, evaluated at SCREEN_UV),
// multiplied by `lift` — >1 reads as lit smoke, <1 as a shaded silhouette.
// Contrast is proportional to local light, so pieces glow near the core
// and dissolve into the dark with no masking tricks. `detail` mixes back
// a whisper of the art's own shading (tinted by `brighten`).
shader_type canvas_item;
uniform vec3 core = vec3(0.545, 0.553, 0.338);
uniform vec3 edge = vec3(0.020, 0.024, 0.016);
uniform vec2 center = vec2(0.20, 0.28);
uniform float angle = 0.50;
uniform float stretch = 2.4;
uniform float falloff = 1.42;
uniform float lift = 1.18;
uniform float detail : hint_range(0.0, 1.0) = 0.12;
uniform vec3 brighten = vec3(1.0, 1.2, 0.75);

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec2 d = SCREEN_UV - center;
	d.x *= 1.777;
	vec2 dir = vec2(cos(angle), sin(angle));
	float along = dot(d, dir);
	float across = dot(d, vec2(-dir.y, dir.x));
	along = along > 0.0 ? along / stretch : along * 1.3;
	float dist = length(vec2(along, across)) * falloff;
	vec3 fog = mix(core, edge, clamp(dist, 0.0, 1.0));
	// calibrated to cave_ref_04: the art is lit BY the fog — its color is
	// scaled by local fog brightness, so pieces glow warm near the core
	// and die to true black in the dark, like the promo frame
	float fog_rel = clamp(dot(fog, vec3(0.3333))
			/ max(dot(core, vec3(0.3333)), 1e-4), 0.0, 1.0);
	// pieces are recut — NO luminance gate: dark art stays dark rock (a
	// gate here repainted bases as flat fog = the translucent-slab bug).
	// Only the 2px blur-edge falls back to pure silhouette.
	float keep = smoothstep(0.55, 0.95, t.a);
	vec3 col = mix(fog * lift, t.rgb * brighten * fog_rel, detail * keep);
	COLOR = vec4(col, t.a);
}
