#version 130
#include "lib/util/math.glsl"

uniform sampler2D colortex0;

in vec2 coord;

struct sceneColorData {
    vec3 hdr;
    vec3 sdr;
} col;

vec3 returnCol;

void main() {
    col.hdr         = texture2D(colortex0, coord).rgb;

    //returnCol       = col.hdr;
    returnCol       = pow(col.hdr/10, vec3(1.0/2.2));


    gl_FragColor    = toVec4(returnCol);
}