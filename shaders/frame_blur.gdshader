// STEP 3 frame DOF: subtle blur applied per-sprite on the fg_frame
// silhouette layer (CanvasGroup capture mangles at this layer's scale).
// COLOR multiply keeps the layer's silhouette modulate.
shader_type canvas_item;
uniform float blur_px = 1.1;

void fragment(){
    vec2 px = TEXTURE_PIXEL_SIZE * blur_px;
    vec4 c = texture(TEXTURE, UV) * 0.4;
    c += texture(TEXTURE, UV + vec2(px.x, 0.0)) * 0.15;
    c += texture(TEXTURE, UV - vec2(px.x, 0.0)) * 0.15;
    c += texture(TEXTURE, UV + vec2(0.0, px.y)) * 0.15;
    c += texture(TEXTURE, UV - vec2(0.0, px.y)) * 0.15;
    COLOR = c * COLOR;
}
