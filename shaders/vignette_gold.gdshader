// REALM 1 vignette (Advika's spec, step 2/7). Hard elliptical falloff:
// corners to near-black, centre fully lit and unchanged.
shader_type canvas_item;

uniform vec2  center  = vec2(0.44, 0.47);
uniform vec2  radius  = vec2(0.86, 0.92);
uniform float falloff = 2.5;

void fragment(){
    vec2 d = (UV - center) / radius;
    float v = clamp(1.0 - pow(clamp(length(d), 0.0, 2.0), falloff), 0.0, 1.0);
    COLOR = vec4(0.020, 0.043, 0.031, 1.0 - v);
}
