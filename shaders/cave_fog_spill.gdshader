// Realm 1 cave fog with a DIAGONAL SPILL (cave_ref_03): the bright core
// sits upper-left and the light leaks down-right in a long tail, so the
// lit region cuts a diagonal across the frame instead of a round glow.
shader_type canvas_item;
uniform vec3 core = vec3(0.545, 0.553, 0.338);  // ref_04 core, pre-boosted so
                                                // the mist sheets land it right
uniform vec3 edge = vec3(0.020, 0.024, 0.016);
uniform vec2 center = vec2(0.20, 0.28);
uniform float angle = 0.50;    // spill direction in radians (down-right)
uniform float stretch = 2.4;   // how much slower the falloff is along the spill
uniform float falloff = 1.42;  // ref_04: the lit pocket is PRECIOUS — about a
                               // quarter of the frame; the rest drowns dark

void fragment() {
	vec2 d = UV - center;
	d.x *= 1.777;  // aspect-correct (16:9) so distances are true on screen
	vec2 dir = vec2(cos(angle), sin(angle));
	float along = dot(d, dir);
	float across = dot(d, vec2(-dir.y, dir.x));
	// the tail only runs down-right; behind the core it dies quickly
	along = along > 0.0 ? along / stretch : along * 1.3;
	float dist = length(vec2(along, across)) * falloff;
	COLOR = vec4(mix(core, edge, clamp(dist, 0.0, 1.0)), 1.0);
}
