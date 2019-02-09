#version 130
#include "/lib/util/math.glsl"

in vec4 col;
in vec2 coord;
in vec2 lmap;
in vec3 nrm;

in float foliage;
in float emissive;
in float metal;

uniform sampler2D texture;

float materialMask = 0.0;

#include "/lib/util/encode.glsl"

void encodeMatBuffer() {
    float fol = remap(foliage, 0.0, 0.9);
    float metal = remap(metal, 1.0, 1.4);
    float emi = remap(emissive, 1.5, 2.5);
    materialMask = fol+metal+emi;
}

void main() {
    /*DRAWBUFFERS:0123*/
    encodeMatBuffer();

    gl_FragData[0] = texture2D(texture, coord)*col;
    gl_FragData[1] = toVec4(nrm*0.5+0.5);
    gl_FragData[2] = vec4(lmap, materialMask, 1.0);
    gl_FragData[3] = vec4(1.0, 0.0, 0.0, 1.0);
}