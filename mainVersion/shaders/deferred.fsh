#version 130
#include "lib/global.glsl"
#include "lib/buffer.glsl"
#include "lib/util/math.glsl"

const float sunPathRotation     = -12.5;

#ifdef setShadowDynamic
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

const float ambientOcclusionLevel = 1.0;

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
    float materials;
    vec4 mask;
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

#include "lib/util/depth.glsl"
#include "lib/util/positions.glsl"
#include "lib/util/dither.glsl"
#include "lib/util/decode.glsl"
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
    shading.diffuse = mix(lambert, 1.0, mat.foliage*0.8);
}

void dbao() {
    float falloff       = smoothstep(depth.linear, 0.5, 0.8);
    float ao            = 0.0;
    float dither        = ditherDynamic;

    #if setAOQuality==0
        const int aoArea    = 3;
        const int samples   = 2;
    #elif setAOQuality==1
        const int aoArea    = 3;
        const int samples   = 3;
    #elif setAOQuality==2
        const int aoArea    = 4;
        const int samples   = 4;
    #endif

    float size          = 2.0/samples;
        size           *= dither;
    const float piAngle = 22.0/(7.0*180.0);
    float radius        = 0.6/samples;
    float rot           = 180.0/aoArea*(dither+0.5);
    vec2 scale          = vec2(1.0/aspectRatio,1.0) * gbufferProjection[1][1] / (2.74747742 * max(far*depth.linear,6.0));
    float sd            = 0.0;
    float angle         = 0.0;
    float dist          = 0.0;

    for (int i = 0; i<samples; i++) {
        for (int j = 0; j<aoArea; j++) {
            sd          = depthLin(texture2D(depthtex1, coord+vec2(cos(rot*piAngle), sin(rot*piAngle))*size*scale).r);
            float samp  = far*(depth.linear-sd)/size;
            angle       = clamp(0.5-samp, 0.0, 1.0);
            dist        = clamp(0.0625*samp, 0.0, 1.0);
            sd          = depthLin(texture2D(depthtex1, coord-vec2(cos(rot*piAngle), sin(rot*piAngle))*size*scale).r);
            samp        = far*(depth.linear-sd)/size;
            angle      += clamp(0.5-samp, 0.0, 1.0);
            dist       += clamp(0.0625*samp, 0.0, 1.0);
            ao         += clamp(angle+dist, 0.0, 1.0);
            rot        += 180.0/aoArea;
        }
        rot    += 180.0/aoArea;
        size   += radius;
        angle   = 0.0;
        dist    = 0.0;
    }
    ao         /= samples+aoArea;
    ao          = ao*sqrt(ao);

    #if setAOQuality==0
        ao     *= 0.74;
    #elif setAOQuality==1
        ao     *= 0.54;
    #elif setAOQuality==2
        ao     *= 0.35;
    #endif

    ao          = clamp(ao, 0.0, 1.0);
    ao          = ao*0.7+0.3;
    ao          = mix(ao, 1.0, falloff);
    shading.ao  = mix(1.0, ao, setAOint);
}

void shadowStatic() {
    vec3 normal     = normalize(bData.normal);
    vec3 light      = normalize(vec.light);
    float lambert   = dot(normal, light);
        lambert     = max(lambert, 0.0);
        lambert = mix(lambert, 1.0, mat.foliage*0.7);
        lambert = mix(lambert, 1.0, 0.5);
    shading.shadow = smoothstep(bData.lightmap.y, 0.93, 0.95)*lambert;
}

#ifdef setShadowDynamic
#include "lib/util/gauss.glsl"

vec2 temporalShadowDither() {
    float noise     = ditherDynamic*pi;
    vec2 rot        = vec2(cos(noise), sin(noise));
    return rot;
}

vec4 gauss9shadow(sampler2DShadow tex, vec3 coord, float sigma) {
    vec4 col = vec4(0.0);

    for (int i = 0; i<9; i++) {
        vec2 bcoord = coord.xy + (gauss9o[i]+temporalShadowDither())*sigma;
        col += shadow2D(tex, vec3(bcoord, coord.z))*gauss9w[i];
    }
    return col;
}
vec4 gauss25shadow(sampler2DShadow tex, vec3 coord, float sigma) {
    vec4 col = vec4(0.0);

    for (int i = 0; i<25; i++) {
        vec2 bcoord = coord.xy + (gauss25o[i]+temporalShadowDither())*sigma;
        float bcoordZ = coord.z + (gauss9o[int(ceil(i/3.0))]+temporalShadowDither()-1.0).x*sigma*0.5;
        col += shadow2D(tex, vec3(bcoord, bcoordZ))*gauss25w[i];
    }
    return col;
}
vec4 gauss25sharp(sampler2DShadow tex, vec3 coord, float sigma) {
    vec4 col = vec4(0.0);

    for (int i = 0; i<25; i++) {
        vec2 bcoord = coord.xy + gauss25o[i]*sigma;
        float bcoordZ = coord.z + (gauss9o[int(ceil(i/3.0))]-1.0).x*sigma*0.5;
        col += shadow2D(tex, vec3(bcoord, bcoordZ))*gauss25w[i];
    }
    return smoothstep(col, 0.4, 0.6);
}

void shadowDynamic() {
    float shade     = 1.0;
    vec4 shadowcol  = vec4(1.0);

    const bool shadowFilter = setShadowFilter;
    const bool softShadow   = setShadowFilterMode;
    const float blurRadius  = 0.00006;
    float filterFactor      = 1.0;

    float distortion    = 0.0;
    float offset        = 0.08 + float(softShadow)*0.0 + mat.foliage*0.2;
    float dist          = length(pos.screen.xyz);

    vec4 wPos   = vec4(0.0);

    if (dist<shadowDistance && dist>0.05) {
        wPos        = pos.screen;

        #ifdef temporalAA
            wPos    = screenSpacePos(depth.depth, taaJitter(coord, -0.5));
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
                if (softShadow) {
                    shade   = gauss25shadow(shadowtex1, wPos.xyz, blurRadius*filterFactor).x;
                    shadowcol = gauss25shadow(shadowcolor0, wPos.xyz, blurRadius*filterFactor);
                } else {
                    shade   = gauss25sharp(shadowtex1, wPos.xyz, 0.00005*filterFactor).x;
                    shadowcol = gauss25shadow(shadowcolor0, wPos.xyz, 0.00005*filterFactor);
                }
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
    vec3 light      = mix(vec3(0.0), light.art, lightmap+mat.emissive*5.0);
    shading.light   = light;
}

void applyShading() {
    shading.skylight = smoothstep(bData.lightmap.y, 0.18, 0.95);
    shading.cave    = 1.0-smoothstep(bData.lightmap.y, 0.36, 0.6);
    shading.lit     = min(shading.shadow, shading.diffuse);
    shading.ao     *= shading.vanillaAO;

    vec3 foliageCol = mix(vec3(1.0), 0.5+normalize(bData.albedo), mat.foliage);

    vec3 indirectLight = light.sky*foliageCol*shading.skylight;
        indirectLight = mix(indirectLight, minLightCol*minLightLum, shading.cave);

    vec3 lightCol   = mix(indirectLight, light.sun*shading.shadowcol, shading.lit);
        lightCol    = bLighten(lightCol, shading.light);

    returnCol      *= 1.0-mat.metallic;
    vec3 shadingCol = bData.albedo*normalize(bData.albedo)*mat.metallic;

    shading.result  = lightCol*shading.ao;
    returnCol      *= shading.result;
    returnCol      += shadingCol*shading.result*mat.metallic;
}

void main() {
    vec4 inputSample = texture2D(colortex0, coord);
    bData.albedo    = toLinear(inputSample.rgb);
    bData.normal    = texture2D(colortex1, coord).rgb*2.0-1.0;
    bData.lightmap  = texture2D(colortex2, coord).rg;
    bData.materials = texture2D(colortex2, coord).b;
    bData.mask      = texture2D(colortex3, coord);

    decodeBuffer();

    depth.depth     = texture2D(depthtex1, coord).x;
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
    light.art       = lightColor*lightLum;

    shading.diffuse = 1.0;
    shading.shadow  = 1.0;
    shading.lit     = 1.0;
    shading.ao      = 1.0;
    shading.vanillaAO = 1.0;
    shading.result  = vec3(1.0);

    if (mask.terrain > 0.5) {
        #ifdef setDiffuseShading
            diffuseLambert();
        #endif

        #ifdef setAmbientOcclusion
            dbao();
        #endif

        #ifdef setUseVanillaAO
            shading.vanillaAO = mix(inputSample.a, 1.0, mat.foliage);
            shading.vanillaAO = mix(1.0, shading.vanillaAO, setVanillaAOint);
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
    }

    //returnCol       = shading.result;

    /*DRAWBUFFERS:0*/
    gl_FragData[0]  = toVec4(returnCol);
}