// STEP 5c (Advika's spec): platform form — lit stone from above grading
// into shadow, not a black cutout. Ramp dark->cap with gamma, plus a rim
// that hugs the sprite's own TOP contour (alpha sampled rim_width px up:
// where above is air, the edge catches the light). rim_strength 0 turns
// the rim off (under-rocks).
shader_type canvas_item;
uniform vec3 dark_c : source_color = vec3(0.102, 0.082, 0.063);  // #1a1510
uniform vec3 cap_c  : source_color = vec3(0.420, 0.353, 0.239);  // #6b5a3d
uniform float gamma_v = 1.3;
uniform float ramp_top = 0.45;
uniform vec3 rim_c : source_color = vec3(0.541, 0.455, 0.302);   // #8a744d
uniform float rim_alpha = 0.8;
uniform float rim_width = 4.0;
uniform float rim_strength = 1.0;

void fragment(){
    vec4 t = texture(TEXTURE, UV);
    float lum = dot(t.rgb, vec3(0.3, 0.59, 0.11));
    float k = pow(clamp(lum / ramp_top, 0.0, 1.0), gamma_v);
    vec3 col = mix(dark_c, cap_c, k);
    float up_a = texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * rim_width)).a;
    float rim_t = clamp(1.0 - up_a, 0.0, 1.0) * t.a * rim_strength;
    col = mix(col, rim_c, rim_t * rim_alpha);
    COLOR = vec4(col, t.a) * COLOR;
}
