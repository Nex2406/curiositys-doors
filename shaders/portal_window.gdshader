// Masks a CanvasGroup down to the portal's opening, so the glimpse of Realm 2 sits
// INSIDE the arch and dissolves into the frame instead of ending on a straight cut.
// The door art's interior is fully opaque, so the view has to be painted over it and
// shaped here.
//
// TWO SHAPES (Advika 2026-08-02: "i want it to be shown uniformly throughout the
// inside of the canopy, not just a oval part"):
//   boxiness 0 — a soft ellipse. The painted eruption arch still wants this: its
//                opening really is an oval hole in a solid slab.
//   boxiness 1 — the WHOLE opening, solid to the rim. The grown doorway is a thicket,
//                not a slab: the posts, the curtain and the front growth are what
//                bound the view, so the far realm has to fill everything behind them
//                evenly. An ellipse here leaves dark corners inside the arch.
//
// ...and then the box had the opposite problem (Advika, same day: "it fades in in a
// perfect rctangle i dont want that"). A box mask fills the opening evenly but its
// boundary is four straight lines, so however gently it comes up it still resolves
// into a rectangle. `edge_noise` warps that boundary with fbm before it is thresholded,
// which costs nothing and leaves the CENTRE completely solid — the fill stays uniform,
// only the rim goes ragged, and it reads as growth eating into the light rather than
// as an image with corners.
shader_type canvas_item;

uniform vec2 centre = vec2(0.5, 0.5);   // opening centre, in the group's UV
uniform vec2 radius = vec2(0.30, 0.42); // opening half-size
uniform float feather = 0.30;           // how far in from the rim it fades
uniform float brightness = 1.0;
uniform float boxiness = 0.0;           // 0 = ellipse, 1 = the full opening
uniform float edge_noise = 0.0;         // how far the rim wanders (0 = geometric)
uniform float noise_scale = 5.0;        // how big the wobbles are
// Drifts the FOREST inside a mask that stays put. Moving the sprite instead would
// carry the mask with it and swim the lit area against the posts.
uniform vec2 uv_pan = vec2(0.0);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return 0.60 * vnoise(p) + 0.28 * vnoise(p * 2.13) + 0.12 * vnoise(p * 4.37);
}

void fragment() {
	vec4 c = texture(TEXTURE, clamp(UV + uv_pan, vec2(0.001), vec2(0.999)));
	vec2 d = (UV - centre) / radius;
	// two decorrelated samples so the horizontal and vertical rims wander apart
	float nx = fbm(UV * noise_scale + vec2(11.3, 4.7)) - 0.5;
	float ny = fbm(UV * noise_scale + vec2(63.1, 27.9)) - 0.5;
	float ell = 1.0 - smoothstep(1.0 - feather, 1.0,
			length(d) + (nx + ny) * 0.5 * edge_noise);
	vec2 q = abs(d) + vec2(nx, ny) * edge_noise;
	float box = (1.0 - smoothstep(1.0 - feather, 1.0, q.x))
			* (1.0 - smoothstep(1.0 - feather, 1.0, q.y));
	float m = mix(ell, box, boxiness);
	COLOR = vec4(c.rgb * brightness, c.a * m);
}
