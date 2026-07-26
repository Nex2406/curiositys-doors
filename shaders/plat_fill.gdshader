// Solid lit fill behind a platform. The fused platform textures fade to semi-
// transparent toward the bottom, so the tile body shows the dark cave through
// it and reads black. This draws an OPAQUE lit-brown silhouette (from the same
// texture's alpha) behind the platform, so the see-through body reads as lit
// stone instead. Same texture => exact silhouette, no outline.
shader_type canvas_item;
uniform vec4 fill : source_color = vec4(0.34, 0.28, 0.19, 1.0);

void fragment() {
	// opaque across the whole silhouette (even where the tile fades), so the fill
	// actually shows through the see-through body
	float a = smoothstep(0.02, 0.12, texture(TEXTURE, UV).a);
	COLOR = vec4(fill.rgb, a);
}
