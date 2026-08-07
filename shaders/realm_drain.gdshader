shader_type canvas_item;

// THE SHIFT — the forest gives up.
//
// The player spends ten minutes saving this place from the things sprouting
// out of it, and the moment the sixth one dies the colour goes out of it. It
// is done to the SCREEN, not to the textures: one full-viewport pass under
// the HUD, so nothing in the level has to know it happened and it can be
// tweened, held, or run backwards over the boss's body when it dies.
//
// Not a plain greyscale. Grey alone reads as "the renderer broke". This
// keeps the luminance structure, crushes it darker, and pushes what is left
// a few degrees COLD, so the forest looks drained of blood rather than
// desaturated in software.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

// IT ARRIVES. The death does not fade in over the whole screen at once — it
// crosses the forest from left to right like weather, so the player watches
// it COME, and for a second or two there is living forest ahead of the line
// and dead forest behind it. `sweep` is where that front is, in screen UV.x:
// below 0 it has not started, above 1 it has passed and everything is dead.
uniform float sweep : hint_range(-0.5, 1.5) = -0.5;
// how soft the front is — the width of the dying band, in screen widths
uniform float edge : hint_range(0.01, 0.8) = 0.26;
// a master gate, so the finished state can still be held or run backwards
uniform float amount : hint_range(0.0, 1.0) = 1.0;
// how far down the drained image is pulled
uniform float darken : hint_range(0.0, 1.0) = 0.46;
// the cold tint the corpse keeps
uniform vec3 cold = vec3(0.90, 0.96, 1.08);
// a little contrast kept in the dead state so silhouettes still read
uniform float contrast : hint_range(0.5, 2.0) = 1.12;

// The realm applies a CanvasModulate (a teal grade) to every canvas item —
// and this rect IS a canvas item, so the screen copy it draws gets that grade
// multiplied onto it a SECOND time. The result was a green wash over the whole
// screen the instant the drain appeared, before the sweep had touched
// anything. Dividing it out here means what finally lands on screen, after
// CanvasModulate does its multiply, is exactly what was sampled.
uniform vec3 ambient = vec3(1.0);

void fragment() {
	vec3 src = texture(screen_tex, SCREEN_UV).rgb;

	float l = dot(src, vec3(0.2126, 0.7152, 0.0722));
	// keep the shape of the light, lose the hue
	float lc = clamp((l - 0.5) * contrast + 0.5, 0.0, 1.0);
	vec3 dead = vec3(lc) * (1.0 - darken) * cold;

	// how dead THIS pixel is: 1 well behind the front, 0 well ahead of it
	float a = clamp((sweep - SCREEN_UV.x) / max(edge, 0.001), 0.0, 1.0);
	a = smoothstep(0.0, 1.0, a) * amount;

	vec3 outc = mix(src, dead, a);
	// pre-divide, so CanvasModulate's multiply cancels instead of stacking
	outc /= max(ambient, vec3(0.001));
	COLOR = vec4(outc, 1.0);
}
