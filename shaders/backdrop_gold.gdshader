// REALM 1 backdrop grade (Advika's spec, step 1/7): warm gold, heavily
// blurred, low contrast. Defaults are her tuned values — expected to look
// washed out and too bright on its own until step 2's vignette.
shader_type canvas_item;

uniform vec3  c_shadow : source_color = vec3(0.114, 0.075, 0.035);  // #1d1309
uniform vec3  c_haze   : source_color = vec3(0.357, 0.243, 0.122);  // #5b3e1f
uniform vec3  c_glow   : source_color = vec3(0.859, 0.808, 0.600);  // #dbce99
uniform float desaturate = 0.30;
uniform float tint_mix   = 0.76;
uniform float contrast   = 0.66;
uniform float blur_px    = 11.0;
uniform float fog_amount = 0.20;

void fragment(){
    vec2 px = TEXTURE_PIXEL_SIZE * blur_px;
    vec3 c = vec3(0.0);
    float wsum = 0.0;
    for (int x = -2; x <= 2; x++){
        for (int y = -2; y <= 2; y++){
            float w = 1.0 / (1.0 + float(x*x + y*y));
            c += texture(TEXTURE, UV + vec2(float(x), float(y)) * px).rgb * w;
            wsum += w;
        }
    }
    c /= wsum;

    float lum = dot(c, vec3(0.3, 0.59, 0.11));
    c = mix(vec3(lum), c, desaturate);

    vec3 lo = mix(c_shadow, c_haze, pow(clamp(lum / 0.55, 0.0, 1.0), 1.1));
    vec3 hi = mix(c_haze,   c_glow, pow(clamp((lum - 0.55) / 0.45, 0.0, 1.0), 0.9));
    c = mix(c, lum < 0.55 ? lo : hi, tint_mix);

    c = vec3(0.5) + (c - vec3(0.5)) * contrast;
    c = mix(c, c_haze, fog_amount);

    COLOR = vec4(c, 1.0);
}
