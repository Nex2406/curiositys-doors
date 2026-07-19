// Realm 1 vignette — elliptical, aspect-aware (Advika's correction,
// 2026-07-19): the outer ~18% of frame goes black, the center stays clear.
shader_type canvas_item;
uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform float inner : hint_range(0.0, 1.5) = 0.45;
uniform float outer : hint_range(0.0, 2.0) = 1.05;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.0, 0.62); // squash Y for 16:9
	float d = length(p) * 2.0;
	float v = smoothstep(inner, outer, d) * strength;
	COLOR = vec4(0.0, 0.0, 0.0, clamp(v, 0.0, 1.0));
}
