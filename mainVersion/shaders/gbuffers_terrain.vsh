#version 130

out vec4 color;
out vec2 texcoord;
out vec3 normal;
out vec2 lmcoord;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
uniform float frameTimeCounter;

uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;

vec4 position;

#include "lib/block.glsl"
#include "lib/amb/wind.glsl"
#include "lib/util/taaJitter.glsl"

void main() {
    idSetup();
    matSetup();

    decodePos();
    applyWind();
    encodePos();
    
    #ifdef TAA
    position.xy     = taaJitter(position.xy, position.w);
    #endif
    gl_Position     = position;
    color           = gl_Color;
    normal          = normalize(gl_NormalMatrix*gl_Normal);
    texcoord        = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    lmcoord         = (gl_TextureMatrix[1]*gl_MultiTexCoord1).xy;
}