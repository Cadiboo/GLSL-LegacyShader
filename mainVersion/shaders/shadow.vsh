#version 130

const float shadowBias = 0.85;

out vec4 color;
out vec2 texcoord;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
uniform float frameTimeCounter;

vec4 position;

#include "lib/block.glsl"
#include "lib/amb/wind.glsl"
out float translucency;

void main() {
    idSetup();
    matSetup();
    if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0 || mc_Entity.x == block.glassStain) {
        translucency = 1.0;
    } else {
        translucency = 0.0;
    }
    position = gl_ProjectionMatrix*gl_ModelViewMatrix*gl_Vertex;

    decodeShadowPos();
    applyWind();
    encodeShadowPos();

    float distortion = sqrt(position.x*position.x + position.y*position.y);
        distortion = (1.0-shadowBias) + distortion*shadowBias;

    position.xy *= 1.0/distortion;

    gl_Position = position;
    texcoord = (gl_TextureMatrix[0]*gl_MultiTexCoord0).st;
    color = gl_Color;
}