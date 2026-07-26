// Main-menu depth parallax (Step 2). Samples the painting with a per-pixel UV
// offset scaled by the depth map, so NEAR regions (white in the map) shift more
// than FAR ones (black). The eased offset, master intensity, overscan and
// breathing all live in MainMenuParallax.gd — this shader is only the per-pixel
// displacement + edge-clamped sampling.
shader_type canvas_item;

// Depth map: a DATA texture (non-sRGB), white = near, black = far. repeat_disable
// == clamp-to-edge, so an out-of-range sample can never wrap the opposite edge of
// the painting into frame (the one catastrophic failure mode).
uniform sampler2D depth_tex : repeat_disable, filter_linear;
uniform vec2 u_offset = vec2(0.0);      // eased parallax offset in UV (script-driven)
uniform float u_depth_strength = 1.0;   // how strongly depth modulates the shift

void fragment() {
	float d = texture(depth_tex, UV).r;             // 0 far .. 1 near
	vec2 suv = UV + u_offset * d * u_depth_strength;
	COLOR = texture(TEXTURE, suv);                  // TEXTURE repeat is DISABLED (clamp)
}
