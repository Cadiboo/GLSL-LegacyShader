#version 130
out vec4 col;
out vec2 coord;
out vec2 lmap;
out vec3 nrm;

uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;

#include "/lib/util/taaJitter.glsl"

void main() {
    gl_Position     = ftransform();
    #ifdef temporalAA
        gl_Position.xy  = taaJitter(gl_Position.xy, gl_Position.w);
    #endif
    col             = gl_Color;
    coord           = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    lmap            = (gl_TextureMatrix[1]*gl_MultiTexCoord1).xy;
    nrm             = normalize(gl_NormalMatrix*gl_Normal);
}