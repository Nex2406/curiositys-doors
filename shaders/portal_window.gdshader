// Masks a CanvasGroup down to the portal's opening: an ellipse with a soft edge,
// so the glimpse of Realm 2 sits INSIDE the arch and dissolves into the stone
// instead of ending on a straight cut. The door art's interior is fully opaque,
// so the view has to be painted over it and shaped here.
shader_type canvas_item;

uniform vec2 centre = vec2(0.5, 0.5);   // opening centre, in the group's UV
uniform vec2 radius = vec2(0.30, 0.42); // opening half-size
uniform float feather = 0.30;           // how far in from the rim it fades
uniform float brightness = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 d = (UV - centre) / radius;
	float m = 1.0 - smoothstep(1.0 - feather, 1.0, length(d));
	COLOR = vec4(c.rgb * brightness, c.a * m);
}
