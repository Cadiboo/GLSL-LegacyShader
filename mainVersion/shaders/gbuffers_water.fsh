#version 130
#include "lib/global.glsl"
#include "/lib/util/math.glsl"

uniform sampler2D texture;

#ifdef setShadowDynamic
    uniform sampler2DShadow shadowtex0;
    uniform sampler2DShadow shadowtex1;
    uniform sampler2DShadow shadowcolor0;
    uniform sampler2DShadow shadowcolor1;

    const int shadowMapResolution   = 3072;         //[512 1024 1536 2048 2560 3072 4096]

    const float shadowDistance      = 192.0;        //[96.0 128.0 160.0 192.0 224.0 256.0]
    const float shadowIlluminance   = setShadowIlluminance;
    const float shadowBias          = 0.85;

    const bool shadowHardwareFiltering = true;
#endif

const float sunlightLum     = 20.0;
const float skylightLum     = 2.2;

const vec3 minLightCol      = vec3(0.5);
const float minLightLum     = 0.03;

const vec3 lightColor       = vec3(1.0, 0.42, 0.0);
const float lightLum        = 1.0;

uniform int frameCounter;
uniform int isEyeInWater;

uniform float far;
uniform float near;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

#ifdef setShadowDynamic
    uniform mat4 shadowModelView;
    uniform mat4 shadowModelViewInverse;
    uniform mat4 shadowProjection;
    uniform mat4 shadowProjectionInverse;
#endif

in float timeSunrise;
in float timeNoon;
in float timeSunset;
in float timeNight;
in float timeMoon;
in float timeLightTransition;
in float timeSun;

in vec2 coord;
in vec2 lmap;
in vec3 nrm;
in vec4 col;

in vec3 sunVector;
in vec3 moonVector;
in vec3 lightVector;
in vec3 upVector;

in vec3 colSunlight;
in vec3 colSkylight;

struct bufferData {
    vec3 albedo;
    vec3 normal;
    vec2 lightmap;
} bData;

struct depthData {
    float depth;
    float linear;
} depth;

struct positionData {
    vec3 sun;
    vec3 moon;
    vec3 light;
    vec3 up;
    vec3 camera;
    vec4 screen;
    vec4 world;
} pos;

struct vectorData {
    vec3 sun;
    vec3 moon;
    vec3 light;
    vec3 up;
    vec3 view;
} vec;

struct shadingData {
    float diffuse;
    float shadow;
    float ao;
    float skylight;
    float cave;
    float vanillaAO;
    float lit;

    vec3 shadowcol;
    vec3 light;
    vec3 result;
} shading;

struct lightData {
    vec3 sun;
    vec3 sky;
    vec3 art;
} light;

vec3 returnCol  = vec3(0.0);
float materialMask = 0.0;

vec2 fragCoord  = gl_FragCoord.xy/vec2(viewWidth, viewHeight);

#include "/lib/util/encode.glsl"
#include "lib/util/depth.glsl"

vec4 screenSpacePos(float depth) {
    vec4 posNDC = vec4(fragCoord.x*2.0-1.0, fragCoord.y*2.0-1.0, 2.0*depth-1.0, 1.0);
    vec4 posCamSpace = gbufferProjectionInverse*posNDC;
    return posCamSpace/posCamSpace.w;
}
vec4 screenSpacePos(float depth, vec2 coord) {
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
vec4 worldSpacePos(float depth, vec2 coord) {
    vec4 posCamSpace = screenSpacePos(depth, coord);
    vec4 posWorldSpace = gbufferModelViewInverse*posCamSpace;
    posWorldSpace.xyz += cameraPosition.xyz;
    return posWorldSpace;
}

#include "lib/util/dither.glsl"
#include "lib/util/colorConversion.glsl"
#include "lib/util/taaJitter.glsl"

float getLightmap(in float lightmap) {
    lightmap = 1-clamp(lightmap*1.1, 0.0, 1.0);
    lightmap *= 5.0;
    lightmap = 1.0 / pow2(lightmap+0.1);
    lightmap = smoothstep(lightmap, 0.025, 1.0);
    return lightmap;
}

void diffuseLambert() {
    vec3 normal     = normalize(bData.normal);
    vec3 light      = normalize(vec.light);
    float lambert   = dot(normal, light);
        lambert     = max(lambert, 0.0);
    shading.diffuse = lambert;
}

void shadowStatic() {
    vec3 normal     = normalize(bData.normal);
    vec3 light      = normalize(vec.light);
    float lambert   = dot(normal, light);
        lambert     = max(lambert, 0.0);
        lambert = mix(lambert, 1.0, 0.5);
    shading.shadow = smoothstep(bData.lightmap.y, 0.93, 0.95)*lambert;
}

#ifdef setShadowDynamic
#include "lib/util/gauss.glsl"
#include "lib/util/shadowFilter.glsl"

void shadowDynamic() {
    float shade     = 1.0;
    vec4 shadowcol  = vec4(1.0);

    const bool shadowFilter = setShadowFilter;
    const bool softShadow   = setShadowFilterMode;
    const float blurRadius  = 0.00004;
    float filterFactor      = 1.0;

    float distortion    = 0.0;
    float offset        = 0.08 + float(softShadow)*0.0;
    float dist          = length(pos.screen.xyz);

    vec4 wPos   = vec4(0.0);

    if (dist<shadowDistance && dist>0.05) {
        wPos        = pos.screen;

        #ifdef temporalAA
            wPos    = screenSpacePos(depth.depth, taaJitter(fragCoord, -0.5));
        #endif

        wPos.xyz   += vec3(offset)*vec.light;
        wPos        = gbufferModelViewInverse*wPos;
        wPos        = shadowModelView*wPos;
        wPos        = shadowProjection*wPos;
        wPos       /= wPos.w;

        distortion  = sqrt(wPos.x*wPos.x + wPos.y*wPos.y);
        distortion  = (1.0-shadowBias) + distortion*shadowBias;
        wPos.xy    *= 1.0/distortion;
        filterFactor = 1.0/distortion;
        //wPos.z     -= 0.0005;

        wPos        = wPos*0.5+0.5;

        if (wPos.x < 1.0 && wPos.x > 0.0 && wPos.y < 1.0 && wPos.y > 0.0) {
            if (shadowFilter) {
                #if setShadowFilterQuality==0
                    if (softShadow) {
                        shade   = gauss25shadow(shadowtex1, wPos.xyz, blurRadius*filterFactor).x;
                        shadowcol = gauss25shadow(shadowcolor0, wPos.xyz, blurRadius*filterFactor);
                    } else {
                        shade   = gauss25sharp(shadowtex1, wPos.xyz, 0.00005*filterFactor).x;
                        shadowcol = gauss25shadow(shadowcolor0, wPos.xyz, 0.000025*filterFactor);
                    }
                #elif setShadowFilterQuality==1
                    if (softShadow) {
                        shade   = gauss25shadow(shadowtex1, wPos.xyz, blurRadius*filterFactor).x;
                        shadowcol = gauss25shadow(shadowcolor0, wPos.xyz, blurRadius*filterFactor);
                    } else {
                        shade   = gauss25sharp(shadowtex1, wPos.xyz, 0.00005*filterFactor).x;
                        shadowcol = gauss25shadow(shadowcolor0, wPos.xyz, 0.000025*filterFactor);
                    }
                #elif setShadowFilterQuality==2
                    if (softShadow) {
                        shade   = gauss49shadow(shadowtex1, wPos.xyz, blurRadius*filterFactor).x;
                        shadowcol = gauss49shadow(shadowcolor0, wPos.xyz, blurRadius*filterFactor);
                    } else {
                        shade   = gauss49sharp(shadowtex1, wPos.xyz, 0.000035*filterFactor).x;
                        shadowcol = gauss49shadow(shadowcolor0, wPos.xyz, 0.0000125*filterFactor);
                    }
                #endif
            } else {
                shade   = shadow2D(shadowtex1, wPos.xyz).x;
                shadowcol = shadow2D(shadowcolor0, wPos.xyz);
            }
        }
    }
    shading.shadow  = shade;
    shading.shadowcol = mix(vec3(1.0), shadowcol.rgb, shadowcol.a);
}
#endif

void artificialLight() {
    float lightmap  = getLightmap(bData.lightmap.x);
    vec3 light      = mix(vec3(0.0), light.art, lightmap);
    shading.light   = light;
}

void applyShading() {
    shading.skylight = smoothstep(bData.lightmap.y, 0.18, 0.95);
    shading.cave    = 1.0-smoothstep(bData.lightmap.y, 0.36, 0.6);
    shading.lit     = min(shading.shadow, shading.diffuse);
    shading.lit    *= 1.0-timeLightTransition;
    shading.ao     *= shading.vanillaAO;

    vec3 indirectLight = light.sky*shading.skylight;
        indirectLight = mix(indirectLight, minLightCol*minLightLum, shading.cave);

    vec3 lightCol   = mix(indirectLight, light.sun*shading.shadowcol, shading.lit);
        lightCol    = bLighten(lightCol, shading.light);

    shading.result  = lightCol*shading.ao;
    returnCol      *= shading.result;
}

void main() {
    vec4 inputSample = texture2D(texture, coord);
    bData.albedo    = toLinear(inputSample.rgb)*col.rgb;
    bData.normal    = nrm;
    bData.lightmap  = lmap;

    depth.depth     = gl_FragCoord.z;
    depth.linear    = depthLin(depth.depth);

    pos.sun         = sunPosition;
    pos.moon        = moonPosition;
    pos.light       = shadowLightPosition;
    pos.camera      = cameraPosition;
    pos.screen      = screenSpacePos(depth.depth);
    pos.world       = worldSpacePos(depth.depth);

    vec.sun         = sunVector;
    vec.moon        = moonVector;
    vec.light       = lightVector;
    vec.up          = upVector;
    vec.view        = normalize(pos.screen).xyz;

    returnCol       = bData.albedo;

    light.sun       = colSunlight*sunlightLum;
    light.sky       = colSkylight*skylightLum;
    light.sky       = mix(light.sky, light.sun, shadowIlluminance);
    light.art       = lightColor*lightLum;

    shading.diffuse = 1.0;
    shading.shadow  = 1.0;
    shading.lit     = 1.0;
    shading.ao      = 1.0;
    shading.vanillaAO = 1.0;
    shading.result  = vec3(1.0);

        #ifdef setDiffuseShading
            diffuseLambert();
        #endif

        #ifdef setUseVanillaAO
            shading.vanillaAO = mix(1.0, inputSample.a, setVanillaAOint);
        #endif

        if (shading.diffuse > 0.0) {
            #ifdef setShadowDynamic
                shadowDynamic();
            #else
                shadowStatic();
            #endif
        }
        artificialLight();
        applyShading();

    /*DRAWBUFFERS:0123*/
    gl_FragData[0] = vec4(returnCol, inputSample.a);
    gl_FragData[1] = toVec4(nrm*0.5+0.5);
    gl_FragData[2] = vec4(lmap, materialMask, 1.0);
    gl_FragData[3] = vec4(1.0, 1.0, 0.0, 1.0);
}