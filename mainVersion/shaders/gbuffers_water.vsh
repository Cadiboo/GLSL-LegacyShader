#version 130
#include "lib/util/math.glsl"

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform vec3 shadowLightPosition;

out vec4 col;
out vec2 coord;
out vec2 lmap;
out vec3 nrm;

uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;

vec4 position;

out vec3 sunVector;
out vec3 moonVector;
out vec3 lightVector;
out vec3 upVector;

#include "lib/util/time.glsl"
#include "lib/nVars.glsl"

#include "/lib/util/taaJitter.glsl"
#include "/lib/terrain/blocks.glsl"
#include "/lib/terrain/transform.glsl"

#define setWindEffect

const float windIntensity = 1.0;

uniform float frameTimeCounter;
uniform int worldTime;
uniform int worldDay;
//float worldTimeAnim = worldDay + (worldTime/24000);

uniform float rainStrength;
uniform float wetness;
const float wetnessHalflife = 300.0;
const float drynessHalflife = 100.0;

float animTick = frameTimeCounter*pi;
float windOcclusion = 0.0;

vec2 windVec2(float x) {
    vec2 wind1 = vec2(1.0, 0.0);
    vec2 wind2 = vec2(0.0, 1.0);

    vec2 dir = vec2(1.0-abs(clamp(x, -1.0, 1.0)), clamp(x, -1.0, 1.0));
    
    return -normalize(vec3(dir, length(dir))).xy*windIntensity;
}
vec3 windVec3(float x) {
    vec3 wind1 = vec3(1.0, 0.1, 0.0);
    vec3 wind2 = vec3(0.0, -0.5, 1.0);
    return normalize(mix(wind1, wind2, x))*windIntensity;
}

float windMacroGust(in vec3 pos, in float speed, in float strength, in float dir) {
    pos.xz *= -windVec2(dir);
    float loc   = pos.x+pos.z;
    float tick  = animTick*speed;
    float s1    = sin(tick+loc)*0.7+0.2;
    float c1    = cos(tick*0.654+loc)*0.7+0.2;
    return (s1+c1)*strength;
}
float windWave(in vec3 pos, in float speed, in float strength, in float dir) {
    pos.xz *= -windVec2(dir);
    float loc   = pos.x+pos.z;
    float tick  = animTick*speed;
    float s1    = sin(animTick+loc)*0.68+0.2;
    return s1*strength;
}
float windMicroGust(in vec3 pos, in float speed, in float strength, in float dir) {
    pos.xz *= -windVec2(dir);
    float loc   = pos.x+pos.z;
    float tick  = animTick*speed;
    float s1    = sin(tick*3.5+loc)*0.5+0.5;
    float s2    = sin(tick*0.5+loc)*0.66+0.34;
        s2      = max(s2*1.2-0.2, 0.0);
    float c1    = cos(tick*0.7+loc)*0.7+0.23;
        c1      = max(c1*1.3-0.3, 0.0);
    return mix(s2, c1, s1)*strength;
}
float windRipple(in vec3 pos, in float speed, in float strength, in float dir) {
    float tick      = animTick*speed;
    vec2 posTemp    = -pos.xz*windVec2(dir-0.12);
    float s01       = sin(tick*0.6+sumVec2(posTemp)*0.2)*0.6+0.6;
        posTemp     = -pos.xz*windVec2(dir+0.2);
    float s02       = sin(tick*0.5+sumVec2(posTemp)*0.18)*0.6+0.66;
        posTemp     = -pos.xz*windVec2(dir-0.18);
    float c01       = cos(tick*0.7+sumVec2(posTemp)*0.16)*0.6+0.6;
    float amp       = s01*s02*c01;
        amp         = mix(amp, amp*0.5+1.0, wetness*0.8);

        posTemp     = -pos.xz*windVec2(dir)*2.0;
    float s11       = sin(tick*4.8+sumVec2(posTemp))*0.5+0.5;
        posTemp     = -pos.xz*windVec2(-dir*1.5);
    float s12       = sin(tick*3.9+sumVec2(posTemp))*0.66+0.34;
        posTemp     = -pos.xz*windVec2(dir-0.2);
    float c11       = cos(tick*2.75+sumVec2(posTemp))*0.62+0.23;
    float ripple    = mix(s12, c11, s11);

    return ripple*amp*strength;
}

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

    pos.y += (macroWind+microWind+ripple)*amp-0.1;
}

void applyWind() {
    if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) {
        windEffectWater(position, 0.7, 0.05, 1.0);
    }
}

void main() {
    lmap            = (gl_TextureMatrix[1]*gl_MultiTexCoord1).xy;

    daytime();
    nature();

    idSetup();
    matSetup();

    position        = ftransform();

    unpackPos();
    #ifdef setWindEffect
        applyWind();
    #endif
    repackPos();

    
    #ifdef temporalAA
        position.xy = taaJitter(position.xy, position.w);
    #endif
    gl_Position     = position;
    col             = gl_Color;
    coord           = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    nrm             = normalize(gl_NormalMatrix*gl_Normal);
    sunVector       = normalize(sunPosition);
    moonVector      = normalize(moonPosition);
    lightVector     = normalize(shadowLightPosition);
    upVector        = normalize(upPosition);
}