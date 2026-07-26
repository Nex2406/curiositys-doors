// Main-menu mist (Step 3). One shader, used by two layers (body + veil) with
// different uniforms. Domain-warped seamless noise: the warp lookups are driven
// by OSCILLATING (sin/cos) offsets plus a slow CIRCULAR base drift, so the field
// churns and evolves in place and never translates in a consistent direction (a
// straight-line scroll reads as cheap instantly). Additive violet — the mist
// adds luminous haze rather than a flat overlay, matching the painting's glow.
shader_type canvas_item;
render_mode blend_add;

// baked SEAMLESS fractal noise (tiles). repeat_enable so the churn wraps cleanly.
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
// depth map (DATA texture, near=white). Body masks by it; veil sets influence 0.
uniform sampler2D depth_tex : repeat_disable, filter_linear;
uniform vec4 tint : source_color = vec4(0.14, 0.11, 0.18, 1.0);
uniform float density = 0.35;
uniform float noise_scale = 2.2;
uniform float warp_amount = 0.4;
uniform float scroll_speed = 1.0;       // churn RATE (not translation)
uniform float vertical_falloff = 0.75;  // 0 = even, 1 = fully gone at the top
uniform float depth_influence = 1.0;    // body = 1 (pool where far); veil = 0
uniform float master = 1.0;
uniform vec2 u_offset = vec2(0.0);      // parallax ride (script-driven)
uniform float ride = 1.0;               // how much this layer rides the parallax

void fragment() {
	vec2 uv = UV + u_offset * ride;
	float t = TIME * scroll_speed;

	// --- domain warp: oscillating lookups morph the field in place ---
	vec2 wc = uv * noise_scale * 0.5;
	vec2 osc1 = vec2(sin(t * 0.31), cos(t * 0.27)) * 0.15;
	vec2 osc2 = vec2(cos(t * 0.19 + 1.3), sin(t * 0.23 + 0.7)) * 0.12;
	float wx = texture(noise_tex, wc + osc1).r;
	float wy = texture(noise_tex, wc * 1.13 + osc2 + vec2(4.2, 1.7)).r;
	vec2 warp = (vec2(wx, wy) - 0.5) * warp_amount;

	// slow CIRCULAR base drift (returns on itself -> no net direction) + warp
	vec2 flow = vec2(sin(t * 0.05), cos(t * 0.04)) * 0.06;
	float m = texture(noise_tex, uv * noise_scale + warp + flow).r * 0.65;
	m += texture(noise_tex, uv * noise_scale * 2.1 + warp * 1.4 + vec2(2.3, 5.1)).r * 0.35;
	m = smoothstep(0.42, 0.9, m);

	// thin/absent at the top of the frame, thickening toward the floor
	float vfall = mix(1.0 - vertical_falloff, 1.0, UV.y);

	// body: pool where the map is FAR (dark), stay off the near ledge + frame
	float dmask = 1.0;
	if (depth_influence > 0.001) {
		float d = texture(depth_tex, UV).r;   // near = 1, far = 0
		dmask = mix(1.0, 1.0 - d, depth_influence);
	}

	float a = m * density * vfall * dmask * master;
	COLOR = vec4(tint.rgb, a);   // blend_add adds tint.rgb * a
}
