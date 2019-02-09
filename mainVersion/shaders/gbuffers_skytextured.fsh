#version 130
#include "/lib/util/math.glsl"

in vec4 col;
in vec2 coord;
in vec2 lmap;
in vec3 nrm;

uniform sampler2D texture;

void main() {
    /*DRAWBUFFERS:03*/
    gl_FragData[0] = texture2D(texture, coord)*col;
    gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0);
}