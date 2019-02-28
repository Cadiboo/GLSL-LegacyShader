#version 130
#include "/lib/util/math.glsl"

in vec4 col;
in vec2 coord;
in vec2 lmap;
in vec3 nrm;

uniform sampler2D texture;

float materialMask = 0.0;

#include "/lib/util/encode.glsl"

void encodeMatBuffer() {
    float beacon = remap(1.0, 1.5, 2.5);
    materialMask = beacon;
}

vec4 sampleCol;

void main() {
    sampleCol = texture2D(texture, coord)*col;

    encodeMatBuffer();

    /*DRAWBUFFERS:0123*/
    gl_FragData[0] = toVec4((sampleCol.rgb*1.0));
    gl_FragData[1] = toVec4(nrm*0.5+0.5);
    gl_FragData[2] = vec4(lmap, 1.0, 1.0);
    gl_FragData[3] = vec4(1.0, 0.0, 0.0, 1.0);
}