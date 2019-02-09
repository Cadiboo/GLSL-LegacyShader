#version 130

out vec4 color;

uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;

#include "lib/util/taaJitter.glsl"

void main() {
    gl_Position         = ftransform();
    #ifdef TAA
    gl_Position.xy      = taaJitter(gl_Position.xy, gl_Position.w);
    #endif
    color               = gl_Color;
}