// STEP 4 bg_near ramp (Advika's spec): darkest parts of the art go to
// #000000, lightest parts cap at #31271d — the band must stay darker than
// the backdrop behind it (nothing over luminance 49).
shader_type canvas_item;
uniform vec3 cap : source_color = vec3(0.192, 0.153, 0.114);  // #31271d
uniform float ramp_top = 0.6;  // art luminance that reaches the cap

void fragment(){
    vec4 t = texture(TEXTURE, UV);
    float lum = dot(t.rgb, vec3(0.3, 0.59, 0.11));
    COLOR = vec4(cap * clamp(lum / ramp_top, 0.0, 1.0), t.a) * COLOR;
}
