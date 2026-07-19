// Realm 1 cave fog — radial gloom centered above screen middle.
// Core/edge sampled from the pack's reference shots (build spec 2026-07-19).
shader_type canvas_item;
uniform vec3 core = vec3(0.525, 0.514, 0.235);
uniform vec3 edge = vec3(0.020, 0.024, 0.016);
uniform vec2 center = vec2(0.5, 0.35);
uniform float falloff = 1.35;

void fragment() {
	float d = distance(UV, center) * falloff;
	COLOR = vec4(mix(core, edge, clamp(d, 0.0, 1.0)), 1.0);
}
