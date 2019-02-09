#version 420 compatibility
#include "/lib/global.glsl"
#include "/lib/util/math.glsl"

const float shadowBias = 0.85;

out vec4 col;
out vec2 coord;

out float water;
out float translucency;
out float displacement;

out vec2 windVec;

out vec4 worldPos;

uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;

vec4 position;

#include "/lib/terrain/blocks.glsl"
#include "/lib/terrain/transform.glsl"
#include "/lib/terrain/wind.glsl"

void windEffectWater(inout vec4 pos, in float speed, in float amp, in float size) {
    vec3 windPos    = pos.xyz*size;
    float dir       = 0.1;

    float macroWind  = 0.0;
        macroWind  += windMacroGust(windPos*0.3, speed*0.53, 0.96, dir+0.0);
        macroWind  += windWave(windPos*0.64, speed*0.42, 0.87, dir+0.29);
        macroWind  += windMicroGust(windPos*0.42, speed*0.76, 0.78, dir+0.17);
        macroWind  *= 1.0-wetness*0.6;

    float microWind  = 0.0;
        microWind  += windMicroGust(windPos*0.8, speed*0.6, 0.78, dir+0.22);
        microWind  += windMicroGust(windPos*1.0, speed*0.72, 0.63, dir-0.05);

    float ripple    = windRipple(windPos*0.8, speed*0.6, 0.78, dir+0.13);

    displacement = (macroWind+microWind+ripple)*0.1;
    pos.y += (macroWind+microWind+ripple)*amp-0.1;
}

void main() {

    idSetup();
    matSetup();

    if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) {
        water = 1.0;
    } else {
        water = 0.0;
    }
    if (mc_Entity.x == block.glassStain) {
        translucency = 1.0;
    } else {
        translucency = 0.0;
    }

    position = gl_ProjectionMatrix*gl_ModelViewMatrix*gl_Vertex;

    unpackShadow();
    #ifdef setWindEffect
        applyWind();
        /*
        if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) {
            windEffectWater(position, 0.7, 0.05, 1.0);
        }*/
    #endif
    worldPos = position;
    repackShadow();

    float distortion = sqrt(position.x*position.x + position.y*position.y);
        distortion = (1.0-shadowBias) + distortion*shadowBias;

    position.xy *= 1.0/distortion;

    gl_Position = position;
    coord       = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    col         = gl_Color;
    windVec     = windVec2(0.3);
}