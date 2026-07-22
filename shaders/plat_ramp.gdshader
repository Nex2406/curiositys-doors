// STEP 5 (Advika's spec): platform/floor body ramp — #000000 to `cap`
// with gamma. Dark graphic shapes against the bright backdrop; nothing
// here is a light source.
shader_type canvas_item;
uniform vec3 cap : source_color = vec3(0.180, 0.149, 0.090);  // #2e2617
uniform float gamma_v = 1.9;
uniform float ramp_top = 0.6;

void fragment(){
    vec4 t = texture(TEXTURE, UV);
    float lum = dot(t.rgb, vec3(0.3, 0.59, 0.11));
    float k = pow(clamp(lum / ramp_top, 0.0, 1.0), gamma_v);
    COLOR = vec4(cap * k, t.a) * COLOR;
}
