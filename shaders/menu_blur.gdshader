// Main-menu background blur — one axis per pass.
//
// Two stacked full-screen rects (BlurH then BlurV) run this with `direction` swapped. A
// separable pair of 9-tap gaussians is 18 samples for the quality of an 81-tap disc; a
// single-pass ring blur at this radius rings visibly on the corridor's lit edges.
//
// It sits BELOW the grade, so the painting is softened first and then graded — blurring
// after the grade would smear the vignette and the scrims into the frame.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 direction = vec2(1.0, 0.0);
// Half-width of the kernel in screen pixels at 1080p-ish scale. The taps are spread across
// it, so this is the true reach of the softening.
uniform float radius : hint_range(0.0, 40.0) = 9.0;

void fragment() {
	vec2 step_uv = direction * SCREEN_PIXEL_SIZE * radius * 0.25;
	vec3 sum = vec3(0.0);
	float total = 0.0;
	for (int i = -4; i <= 4; i++) {
		float f = float(i);
		// sigma = radius/2, so the kernel is fully faded by the time it reaches the edge
		float w = exp(-0.5 * (f * 0.5) * (f * 0.5));
		sum += texture(screen_tex, SCREEN_UV + step_uv * f).rgb * w;
		total += w;
	}
	COLOR = vec4(sum / total, 1.0);
}
