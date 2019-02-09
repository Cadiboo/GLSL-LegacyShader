float noise3D(in vec3 pos, in float size, in vec3 offset) {
    pos            *= size;
    pos            += offset;
    vec3 i          = floor(pos);
    vec3 f          = fract(pos);

    vec2 p1         = (i.xy+i.z*vec2(17.0)+f.xy);
    vec2 p2         = (i.xy+(i.z+1.f)*vec2(17.0))+f.xy;
    vec2 c1         = (p1+0.5)/noiseTextureResolution;
    vec2 c2         = (p2+0.5)/noiseTextureResolution;
    float r1        = texture2D(noisetex, c1).r;
    float r2        = texture2D(noisetex, c2).r;
    return mix(r1, r2, f.z)*2-1;
}
float noise3D(in vec3 pos) {
    return noise3D(pos, 1.0, vec3(0.0));
}

float fbm3D(in vec3 pos,
            in float size,
            in int level,
            in float amp,
            in float detail,
            in vec3 offset) {

        pos        *= size;
    float value     = 0.0;
    for (int i = 0; i < level; i++){
        value      += amp*noise3D(pos);
        pos        *= detail;
        amp        *= 0.5;
    }
    return value;
}
float fbm3D(in vec3 pos,
            in float size,
            in int level,
            in float amp,
            in float detail
            ) {

    return fbm3D(pos, size, level, amp, detail, vec3(0.0));
}
float fbm3D(in vec3 pos, in float size, in int level){
    float amp = 1.0;
    float detail = 2.0;
    return fbm3D(pos, size, level, amp, detail);
}
