#version 130

out vec4 color;
out vec2 texcoord;
out vec3 normal;

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
    normal              = normalize(gl_NormalMatrix*gl_Normal);
    texcoord            = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
}