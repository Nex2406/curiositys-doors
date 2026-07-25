// REALM 1 backdrop grade (Advika's spec, step 1/7): warm gold, heavily
// blurred, low contrast. Defaults are her tuned values — expected to look
// washed out and too bright on its own until step 2's vignette.
shader_type canvas_item;

// Advika 2026-07-25: the pale bright sepia was blinding — it crushed every
// foreground asset to flat black and made every gap glow. Retoned to a deep
// muted amber that suits the warm rock/plant palette; arches still read as
// lit openings, just dimmer and warmer.
uniform vec3  c_shadow : source_color = vec3(0.055, 0.040, 0.024);  // #0e0a06
uniform vec3  c_haze   : source_color = vec3(0.216, 0.153, 0.082);  // #372715
uniform vec3  c_glow   : source_color = vec3(0.541, 0.416, 0.235);  // #8a6a3c
uniform float desaturate = 0.34;
uniform float tint_mix   = 0.86;
uniform float contrast   = 0.72;
uniform float blur_lod   = 3.5;
uniform float fog_amount = 0.30;

void fragment(){
    vec3 c = mix(textureLod(TEXTURE, UV, blur_lod).rgb,
                 textureLod(TEXTURE, UV, blur_lod + 1.0).rgb, 0.5);

    float lum = dot(c, vec3(0.3, 0.59, 0.11));
    c = mix(vec3(lum), c, desaturate);

    vec3 lo = mix(c_shadow, c_haze, pow(clamp(lum / 0.55, 0.0, 1.0), 1.1));
    vec3 hi = mix(c_haze,   c_glow, pow(clamp((lum - 0.55) / 0.45, 0.0, 1.0), 0.9));
    c = mix(c, lum < 0.55 ? lo : hi, tint_mix);

    c = vec3(0.5) + (c - vec3(0.5)) * contrast;
    c = mix(c, c_haze, fog_amount);

    COLOR = vec4(c, 1.0);
}
