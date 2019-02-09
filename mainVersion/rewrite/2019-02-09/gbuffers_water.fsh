#version 130
#include "lib/global.glsl"

const int shadowMapResolution   = 3072;         //[512 1024 1536 2048 2560 3072 4096]
const float shadowDistance      = 192.0;        //[96.0 128.0 160.0 192.0 224.0 256.0]
const float shadowLuma          = shadowSL;
const bool softShadow           = softShadows;
const int shadowBlurSteps       = softShadowSteps;
const float shadowBlurSize      = shadowBlur;
const float shadowBias          = 0.85;

const float sunlightLuma        = 20.0*sunlightLum;
const float skylightLuma        = 2.2*skylightLum;
const float minLight            = minLightVal;
const vec3 minLightColor        = vec3(0.5);

const vec3 torchlighColor       = vec3(1.0, 0.42, 0.0);
const float lightLuma           = 1.0*torchLuma;

const bool shadowHardwareFiltering = true;
const bool shadowHardwareFiltering0 = true;
const bool shadowHardwareFiltering1 = true;

const float shadowIntervalSize	= 2.0;
const float shadowDistanceRenderMul = -1.0;

const float pi = 3.14159265359;

in vec4 color;
in vec2 texcoord;
in vec3 normal;
in vec2 lmcoord;

in float timeLightTransition;

in vec3 sunVector;
in vec3 moonVector;
in vec3 lightVector;
in vec3 upVector;

in vec3 sunPosition;
in vec3 moonPosition;
in vec3 shadowLightPosition;

in vec3 colSunlight;
in vec3 colSkylight;

in float water;
in vec4 wPos;
float heightmap;

uniform float far;
uniform float near;
uniform float viewHeight;
uniform float viewWidth;
uniform float frameTimeCounter;

uniform int frameCounter;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec3 cameraPosition;

uniform sampler2D texture;
uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;

vec2 fragCoord = gl_FragCoord.xy/vec2(viewWidth,viewHeight);

struct bufferInput {
    vec4 albedo;
    vec3 normal;
    vec2 lightmap;
    vec4 mask;
} cbuffer;

struct pbrAttr {
    float roughness;
    float metallic;
    float specular;
} pbr;

struct depthBuffer {
    float depth;
    float linear;
} depth;

struct vectors {
    vec3 sun;
    vec3 moon;
    vec3 light;
    vec3 up;
    vec3 view;
} vec;

struct positions {
    vec3 sun;
    vec3 moon;
    vec3 light;
    vec3 up;
    vec3 camera;
    vec4 screenSpace;
    vec4 worldSpace;
    vec4 shadowSpace;
} pos;

struct shadingComp {
    float diffuse;
    float shadow;
    vec3 shadowcol;
    vec3 foliageCol;
    float ao;
    vec3 subsurface;
    float lit;
    vec3 result;
    float cave;
    float skylight;
    vec3 lights;
    float gameAO;
} shading;

struct lightColors {
    vec3 sunlight;
    vec3 skylight;
    vec3 lightmap;
} lcol;

vec3 returnColor = vec3(1.0);
float returnAlpha = 0.5;

#include "lib/encode.glsl"
#include "lib/util/depth.glsl"
#include "lib/util/dither.glsl"
#include "lib/util/fastmath.glsl"

vec4 screenSpacePos(float depth) {
    vec4 posNDC = vec4(fragCoord.x*2.0-1.0, fragCoord.y*2.0-1.0, 2.0*depth-1.0, 1.0);
    vec4 posCamSpace = gbufferProjectionInverse*posNDC;
    return posCamSpace/posCamSpace.w;
}
vec4 screenSpacePosTAA(float depth, vec2 coord) {
    vec4 posNDC = vec4(coord.x*2.0-1.0, coord.y*2.0-1.0, 2.0*depth-1.0, 1.0);
    vec4 posCamSpace = gbufferProjectionInverse*posNDC;
    return posCamSpace/posCamSpace.w;
}
vec4 worldSpacePos(float depth) {
    vec4 posCamSpace = screenSpacePos(depth);
    vec4 posWorldSpace = gbufferModelViewInverse*posCamSpace;
    posWorldSpace.xyz += cameraPosition.xyz;
    return posWorldSpace;
}

float getLightmap(in float lightmap) {
    lightmap = 1-clamp(lightmap*1.1, 0.0, 1.0);
    lightmap *= 5.0;
    lightmap = 1.0 / pow2(lightmap+0.1);
    lightmap = smoothstep(lightmap, 0.025, 1.0);
    return lightmap;
}
float getLuma(vec3 color) {
	return dot(color,vec3(0.22, 0.687, 0.084));
}
#include "lib/util/taaJitter.glsl"

void shadow() {
    float shade = 0.0;
    #ifdef TAA
    vec4 wPos = screenSpacePosTAA(depth.depth, taaJitter(gl_FragCoord.xy/vec2(viewWidth,viewHeight),-0.5));
    #else
    vec4 wPos = pos.screenSpace;
    #endif
        wPos = gbufferModelViewInverse * wPos;
        wPos = shadowModelView * wPos;
        wPos = shadowProjection * wPos;
        wPos /= wPos.w;
        wPos.z += -0.002;
        float distortion = sqrt(wPos.x*wPos.x + wPos.y*wPos.y);
            distortion = (1.0-shadowBias) + distortion*shadowBias;
        wPos.xy *= 1.0/distortion;
        float blurSize = shadowBlurSize;
            blurSize *= 1.0/distortion;
        wPos = wPos*0.5+0.5;
        //float diff = 0.002/distortion;

        shade = shadow2D(shadowtex0, vec3(wPos.st, wPos.z)).x;

    shading.shadow = shade;
    //shading.shadow = mix(shading.shadow, 0.0f, timeLightTransition);
}

void artificialLight() {
    float lightmap  = getLightmap(cbuffer.lightmap.x);
    vec3 lightColor = torchlighColor*lightLuma;
    vec3 light      = mix(vec3(0.0), lightColor, lightmap);
    shading.lights  = light;
}

void applyShading() {
    shading.skylight = smoothstep(cbuffer.lightmap.y, 0.18, 0.95);
    shading.cave = smoothstep(cbuffer.lightmap.y, 0.36, 0.6);
    shading.lit = shading.shadow;
    shading.result     = mix(lcol.skylight, lcol.sunlight, shadowLuma*(1-timeLightTransition));
    shading.result     = mix(minLightColor*minLight, shading.result*shading.skylight, shading.cave);
    shading.result     = mix(shading.result, lcol.sunlight, shading.lit*(1-timeLightTransition));
    returnColor = returnColor*max(shading.result, shading.lights);
}

void customWaterColor() {
    if (water > 0.5) {
        returnColor *= 0.8;
        returnAlpha = 0.9;
    }
}

void main() {
    vec4 inputSample = texture2D(texture, texcoord)*color;
    cbuffer.albedo  = pow(inputSample, vec4(2.2));
    cbuffer.normal  = normal;
    cbuffer.mask    = vec4(1.0, 0.0, 1.0, 1.0);
    cbuffer.lightmap = lmcoord;

    returnAlpha = inputSample.a;

    depth.depth     = gl_FragCoord.z;
    depth.linear    = depthLin(depth.depth);

    vec.sun         = sunVector;
    vec.moon        = moonVector;
    vec.light       = lightVector;
    vec.up          = upVector;
    vec.view        = normalize(screenSpacePos(depth.depth)).xyz;

    pos.sun         = sunPosition;
    pos.moon        = moonPosition;
    pos.light       = shadowLightPosition;
    pos.camera      = cameraPosition;
    pos.screenSpace = screenSpacePos(depth.depth);
    pos.worldSpace  = worldSpacePos(depth.depth);

    returnColor = cbuffer.albedo.rgb;
    customWaterColor();

    shading.diffuse = 1.0;
    shading.shadow  = 1.0;
    shading.ao      = 1.0;
    shading.skylight = 1.0;
    shading.cave    = 1.0;

    lcol.sunlight   = colSunlight*sunlightLuma;
    lcol.skylight   = colSkylight*skylightLuma;

    shadow();
    artificialLight();
    applyShading();
    
    /* DRAWBUFFERS:0125 */
    gl_FragData[0] = vec4(returnColor, returnAlpha);
    gl_FragData[1] = vec4(normal*0.5+0.5, 1.0);
    gl_FragData[2] = vec4(lmcoord, 0.0, 1.0);
    gl_FragData[3].ba = vec2(1.0, 1.0);
}