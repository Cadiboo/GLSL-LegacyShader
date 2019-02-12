vec2 temporalShadowDither() {
    float noise     = ditherDynamic*pi;
    vec2 rot        = vec2(cos(noise), sin(noise));
    return rot;
}

vec4 gauss9shadow(sampler2DShadow tex, vec3 coord, float sigma) {
    vec4 col = vec4(0.0);

    for (int i = 0; i<9; i++) {
        vec2 bcoord = coord.xy + (gauss9o[i]+temporalShadowDither())*sigma;
        col += shadow2D(tex, vec3(bcoord, coord.z))*gauss9w[i];
    }
    return col;
}
vec4 gauss9sharp(sampler2DShadow tex, vec3 coord, float sigma) {
    vec4 col = vec4(0.0);

    for (int i = 0; i<9; i++) {
        vec2 bcoord = coord.xy + gauss9o[i]*sigma;
        float bcoordZ = coord.z + (gauss9o[i]-1.0).x*sigma*0.5;
        col += shadow2D(tex, vec3(bcoord, bcoordZ))*gauss9w[i];
    }
    return smoothstep(col, 0.4, 0.6);
}
vec4 gauss25shadow(sampler2DShadow tex, vec3 coord, float sigma) {
    vec4 col = vec4(0.0);

    for (int i = 0; i<25; i++) {
        vec2 bcoord = coord.xy + (gauss25o[i]+temporalShadowDither())*sigma;
        float bcoordZ = coord.z + (gauss9o[int(ceil(i/3.0))]+temporalShadowDither()-1.0).x*sigma*0.5;
        col += shadow2D(tex, vec3(bcoord, bcoordZ))*gauss25w[i];
    }
    return col;
}
vec4 gauss25sharp(sampler2DShadow tex, vec3 coord, float sigma) {
    vec4 col = vec4(0.0);

    for (int i = 0; i<25; i++) {
        vec2 bcoord = coord.xy + gauss25o[i]*sigma;
        float bcoordZ = coord.z + (gauss9o[int(ceil(i/3.0))]-1.0).x*sigma*0.5;
        col += shadow2D(tex, vec3(bcoord, bcoordZ))*gauss25w[i];
    }
    return smoothstep(col, 0.4, 0.6);
}
vec4 gauss49shadow(sampler2DShadow tex, vec3 coord, float sigma) {
    vec4 col = vec4(0.0);

    for (int i = 0; i<49; i++) {
        vec2 bcoord = coord.xy + (gauss49o[i]+temporalShadowDither())*sigma;
        float bcoordZ = coord.z + (gauss9o[int(ceil(i/3.0))]+temporalShadowDither()-1.0).x*sigma*0.5;
        col += shadow2D(tex, vec3(bcoord, bcoordZ))*gauss49w[i];
    }
    return col;
}
vec4 gauss49sharp(sampler2DShadow tex, vec3 coord, float sigma) {
    vec4 col = vec4(0.0);

    for (int i = 0; i<49; i++) {
        vec2 bcoord = coord.xy + gauss49o[i]*sigma;
        float bcoordZ = coord.z + (gauss9o[int(ceil(i/3.0))]-1.0).x*sigma*0.5;
        col += shadow2D(tex, vec3(bcoord, bcoordZ))*gauss49w[i];
    }
    return smoothstep(col, 0.4, 0.6);
}
vec4 gauss9shadowcol(sampler2DShadow tex, vec3 coord, float sigma) {
    vec4 col = shadow2D(tex, coord);

    for (int i = 0; i<9; i++) {
        vec2 bcoord = coord.xy + (gauss9o[i]+temporalShadowDither())*sigma*0.5;
        float bcoordZ = coord.z + (gauss9o[int(ceil(i/3.0))]-1.0).x*sigma*0.5;
        vec4 temp = shadow2D(tex, vec3(bcoord, coord.z));
        col.rgb = min(col.rgb, temp.rgb);
        col.a   = max(col.a, temp.a);
    }
    return col;
}