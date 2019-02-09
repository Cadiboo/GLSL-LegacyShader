#version 130
#include "lib/util/fastmath.glsl"

const float sunPathRotation		= -12.5;
const float pi = 3.14159265359;

uniform float sunAngle;

out vec4 color;
out vec2 texcoord;
out vec3 normal;
out vec2 lmcoord;

out vec3 sunVector;
out vec3 moonVector;
out vec3 lightVector;
out vec3 upVector;

out vec3 sunPosition;
out vec3 moonPosition;
out vec3 shadowLightPosition;
out vec3 upPosition;

out float water;
out vec4 wPos;
out float heightmap;

uniform float frameTimeCounter;
uniform int worldTime;

uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform vec3 cameraPosition;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowModelView;

vec4 position;

#include "lib/block.glsl"
#include "lib/util/daytime.glsl"
#include "lib/amb/naturals.glsl"
#include "lib/util/taaJitter.glsl"

vec2 windDirA = vec2(1.0f, 0.7f);
vec2 windDirB = vec2(1.0f, -0.1f);

vec2 windDir(float alpha) {
    return -mix(windDirA, windDirB, alpha);
}

vec3 windDirBlock(float alpha) {
    vec2 temp = -mix(windDirA, windDirB, alpha);
    float y = mix(0.1, -0.5, alpha);
    return vec3(temp.x, y, temp.y);
}

vec2 windRippleDirA = vec2(1.0, 0.9);
vec2 windRippleDirB = vec2(1.0, -0.3);

vec2 windRippleDir(float alpha) {
    return mix(windRippleDirA, windRippleDirB, alpha);
}
vec3 windRippleDirBlock(float alpha) {
    vec2 temp = mix(windRippleDirA, windRippleDirB, alpha);
    float y = mix(0.4, -0.6, alpha);
    return vec3(temp.x, y, temp.y);
}

float windMacroOffsetBase(in vec3 position, in float speed, in float strength, in float rippleMix) {
    position.xz *= windRippleDir(rippleMix);
    float sin1 = sin(frameTimeCounter*pi*speed+position.x+position.z)*0.7+0.2;
    float cos1 = cos(frameTimeCounter*pi*speed*0.654+position.x+position.z)*0.7+.2;
    return (sin1+cos1)*strength;
}
float windMacroOffsetB(in vec3 position, in float speed, in float strength, in float rippleMix) {
    position.xz *= windRippleDir(rippleMix);
    float sin1 = sin(frameTimeCounter*pi*speed+position.x+position.z)*0.68+0.2;
    //float cos1 = cos(frameTimeCounter*pi*speed*0.654+position.x+position.z);
    return (sin1)*strength;
}
float windMicroOffset(in vec3 position, in float speed, in float strength, in float rippleMix) {
    position.xz *= windRippleDir(rippleMix);
    float sin1 = sin(frameTimeCounter*pi*speed*3.5+position.x+position.z)*0.5+0.5;
    float sin2 = sin(frameTimeCounter*pi*speed*0.5+position.x+position.z)*0.66+0.34;
        sin2 = max(sin2*1.2-0.2, 0.0f);
    float cos1 = cos(frameTimeCounter*pi*speed*0.7+position.x+position.z)*0.7+0.23;
        cos1 = max(cos1*1.3-0.3, 0.0f);
    return mix(sin2, cos1, sin1)*strength;
}
float windHeavyRipple(in vec3 position, in float speed, in float strength, in float rippleMix) {
    vec3 posTemp = position.xyz;
        posTemp.xz *= windRippleDir(rippleMix/3);
    float sin1 = sin(frameTimeCounter*pi*speed*0.6+(posTemp.x+posTemp.z)*0.2)*0.6+0.6;
        posTemp.xz = position.xz*windRippleDir(-rippleMix);
    float sin2 = sin(frameTimeCounter*pi*speed*0.5+(posTemp.x+posTemp.z)*0.18)*0.6+0.6;
        posTemp.xz = position.xz*windRippleDir(rippleMix/2);
    float cos1 = cos(frameTimeCounter*pi*speed*0.7+(posTemp.x+posTemp.z)*0.16)*0.6+0.6;
    float amplitude = sin1*sin2*cos1;

        posTemp.xz = position.xz*windRippleDir(rippleMix)*2;
    float sina1 = sin(frameTimeCounter*pi*speed*4.8+posTemp.x+posTemp.z)*0.5+0.5;
        posTemp.xz = position.xz*windRippleDir(-rippleMix*1.5);
    float sina2 = sin(frameTimeCounter*pi*speed*3.9+posTemp.x+posTemp.z)*0.66+0.34;
        posTemp.xz = position.xz*windRippleDir(rippleMix/2);
    float cosa1 = cos(frameTimeCounter*pi*speed*2.75+posTemp.x+posTemp.z)*0.62+0.23;
    float ripple = mix(sina2, cosa1, sina1);
    return ripple*amplitude*strength;
}
void windEffectWater(inout vec4 position, in float speed, in float strength, in float size) {
    vec4 posTemp = position*size;
    float macroOffsetA = 0.0;
    
        macroOffsetA += (windMacroOffsetBase(
            posTemp.xyz*.3, speed*0.53, 0.96, 0.15
            ));
        macroOffsetA += (windMicroOffset(
            posTemp.xyz*.64, speed*0.42, 0.87, 0.6
            ));
        macroOffsetA += (windMacroOffsetB(
            posTemp.xyz*0.42, speed*.76, 0.78, 0.8
            ));
    
    float microOffsetA = (0.0);
        microOffsetA += (windMicroOffset(
            posTemp.xyz*0.8, speed*0.6, 0.78, 0.62
            ));
        microOffsetA += (windMicroOffset(
            posTemp.xyz*1.0, speed*0.72, 0.63, 0.06
            ));

    float heavyRipple = (windHeavyRipple(
            position.xyz*0.8, speed*0.6, 0.78, 0.7
            ));

    float result = (macroOffsetA+microOffsetA+heavyRipple)-0.7;
    heightmap = result*strength;
    position.y += result*strength;
}

float doublePlantFix() {
    bool isTop = gl_MultiTexCoord0.t<mc_midTexCoord.t;
    bool onTop = mc_Entity.z > 8.0;
    return mix(float(isTop)*0.4, float(isTop)*0.6+0.4, float(onTop));
}

void decodePos() {
    position = gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex);
    position.xyz += cameraPosition.xyz;
}

void encodePos() {
    position.xyz -= cameraPosition.xyz;
    position = gl_ProjectionMatrix * (gbufferModelView * position);
}

void applyWind() {
    if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) {
        windEffectWater(position, 0.7, 0.04, 1.0);
    }
}

void main() {
    const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(worldTime / 24000.0 - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunPosition = ((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 100.0, 1.0)).xyz);
    sunVector = normalize(sunPosition);
	upPosition = (gbufferModelView[1].xyz);
    upVector = normalize(upPosition);
    moonPosition = -sunPosition;

    if (sunAngle <= 0.5) {
        lightVector = sunVector;
        shadowLightPosition = sunPosition;
    } else {
        lightVector = -sunVector;
        shadowLightPosition = -shadowLightPosition;
    }

    if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) {
        water = 1.0;
    } else {
        water = 0.0;
    }

    daytime();
    naturals();

    idSetup();
    matSetup();

    decodePos();
    applyWind();
    wPos = position;
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