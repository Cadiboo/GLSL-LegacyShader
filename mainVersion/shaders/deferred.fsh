#version 130
#include "lib/buffers.glsl"
#include "lib/global.glsl"

const float sunPathRotation     = -22.0;

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

uniform float far;
uniform float near;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;

uniform int frameCounter;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

in float timeSunrise;
in float timeNoon;
in float timeSunset;
in float timeNight;
in float timeMoon;
in float timeLightTransition;
in float timeSun;

in vec2 texcoord;

in vec3 sunVector;
in vec3 moonVector;
in vec3 lightVector;
in vec3 upVector;

in vec3 colSunlight;
in vec3 colSkylight;

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

#include "lib/decode.glsl"
#include "lib/util/depth.glsl"
#include "lib/util/dither.glsl"
#include "lib/util/fastmath.glsl"

vec4 screenSpacePos(float depth) {
    vec4 posNDC = vec4(texcoord.x*2.0-1.0, texcoord.y*2.0-1.0, 2.0*depth-1.0, 1.0);
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

void diffuseLambert(in vec3 normal) {
    normal = normalize(normal);
    vec3 light = normalize(vec.light);
    float lambert = dot(normal, light);
        lambert = max(lambert, 0.0);
    shading.diffuse = mix(lambert, 1.0, mat.foliage);
}

#include "lib/util/poisson.glsl"
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

    if (wPos.s < 0.99 && wPos.s > 0.01 && wPos.t < 0.99 && wPos.t > 0.01 ) {
        if (softShadow) {
            int blurSteps = shadowBlurSteps;
            float stepSize = 0.0005/blurSteps;
                stepSize *= blurSize;
                stepSize /= distortion;
                wPos.z +=-0.0000;
            for(int i; i<blurSteps; i++) {
                    shade += shadow2D(shadowtex1, vec3(wPos.st + poissonOffsets[(60/blurSteps)*i]*stepSize, wPos.z)).x;
            }
            shade /= blurSteps;
        } else {
        shade = shadow2D(shadowtex1, vec3(wPos.st, wPos.z)).x;
        }
    } else {
        shade = 1.0;
    }

    shading.shadow = shade;
    //shading.shadow = mix(shading.shadow, 0.0f, timeLightTransition);
}

void dbao() {
    float maxDist   = 0.5;
    float smoothing = 0.3;
    float falloff   = clamp((depth.linear-(maxDist-smoothing/2))/smoothing, 0.0, 1.0);
    float ao        = 0.0;
    float dither    = ditherTemporal;
    const int aoArea = 4;
    const int samples = 3;
    float size      = 2.8/samples;
        //size       *= 1-shading.shadow*0.5;
        size       *= 1.6-min(shading.diffuse*shading.shadow, 1.0);
        size         *= dither;
    const float piAngle = 22.0/(7.0*180.0);
    float radius    = 0.6/samples;
    float rot       = 180.0/aoArea*(dither+0.5);
    vec2 scale     = vec2(1.0/aspectRatio,1.0) * gbufferProjection[1][1] / (2.74747742 * max(far*depth.linear,6.0));
    float sd        = 0.0;
    float angle     = 0.0;
    float dist      = 0.0;

    for (int i = 0; i<samples; i++) {
        for (int j = 0; j<aoArea; j++) {
            sd      = depthLin(texture2D(depthtex0, texcoord+vec2(cos(rot*piAngle), sin(rot*piAngle))*size*scale).r);
            float samp = far*(depth.linear-sd)/size;
            angle   = clamp(0.5-samp, 0.0, 1.0);
            dist    = clamp(0.0625*samp, 0.0, 1.0);
            sd      = depthLin(texture2D(depthtex0, texcoord-vec2(cos(rot*piAngle), sin(rot*piAngle))*size*scale).r);
            samp    = far*(depth.linear-sd)/size;
            angle  += clamp(0.5-samp, 0.0, 1.0);
            dist   += clamp(0.0625*samp, 0.0, 1.0);
            ao     += clamp(angle+dist, 0.0, 1.0);
            rot    += 180.0/aoArea;
        }
        rot    += 180.0/aoArea;
        size   += radius;
        angle   = 0.0;
        dist    = 0.0;
    }
    ao     /= samples+aoArea;
    ao      = ao*sqrt(ao);
    ao     *= 0.5;
    ao      = clamp(ao, 0.0, 1.0);
    ao      = 1.0-ao;
    float aoMod = 1.0-shading.shadow*0.5;
        aoMod  *= 1.0-min(shading.diffuse*shading.shadow*0.5, 1.0);
        aoMod   = clamp(aoMod, 0.0, 1.0);
    ao     *= aoMod;
    ao      = 1.0-ao;
    ao      = ao*0.7+0.3;
    ao      = mix(ao, 1.0, falloff);
    shading.ao = ao;
}

void artificialLight() {
    float lightmap  = getLightmap(cbuffer.lightmap.x);
    vec3 lightColor = torchlighColor*lightLuma;
    vec3 light      = mix(vec3(0.0), lightColor, lightmap+mat.emissive);
    shading.lights  = light;
}

void applyShading() {
    shading.skylight = smoothstep(cbuffer.lightmap.y, 0.18, 0.95);
    shading.cave = smoothstep(cbuffer.lightmap.y, 0.36, 0.6);
    shading.lit = shading.shadow*shading.diffuse;
    if (mask.solid != 1.0) {
        shading.lit = 1.0;
    }
    shading.subsurface = mix(vec3(0.0), cbuffer.albedo.rgb*50, mat.foliage*clamp(shadowLuma*8, 0.0, 1.0));
    shading.subsurface *= getLuma(lcol.skylight)*2.0;
    shading.result     = mix(lcol.skylight+shading.subsurface, lcol.sunlight, shadowLuma*(1-timeLightTransition));
    shading.result     = mix(minLightColor*minLight, shading.result*shading.skylight, shading.cave);
    shading.result     = mix(shading.result, lcol.sunlight, shading.lit*(1-timeLightTransition));
    //shading.result    *= shading.ao;
    //float lightAlpha   = getLuma(shading.lights);
    //float sunlitAlpha  = getLuma(shading.result);
    returnColor = returnColor*max(shading.result, shading.lights)*shading.ao*shading.gameAO;
}

void main() {
    cbuffer.albedo  = pow(texture2D(colortex0, texcoord), vec4(2.2));
    cbuffer.normal  = texture2D(colortex1, texcoord).rgb*2.0-1.0;
    cbuffer.mask    = texture2D(colortex3, texcoord);
    cbuffer.lightmap = texture2D(colortex2, texcoord).xy;
    shading.gameAO  = texture2D(colortex0, texcoord).a;
    decodeMask();

    depth.depth     = texture2D(depthtex1, texcoord).x;
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

    shading.diffuse = 1.0;
    shading.shadow  = 1.0;
    shading.ao      = 1.0;
    shading.skylight = 1.0;
    shading.cave    = 1.0;

    lcol.sunlight   = colSunlight*sunlightLuma;
    lcol.skylight   = colSkylight*skylightLuma;

    #ifdef diffLambert
        diffuseLambert(cbuffer.normal);
    #endif
    
    shadow();

    #ifdef AO
        dbao();
    #endif

    artificialLight();
    applyShading();
    //returnColor = vec3(shading.ao*2.0);
    //returnColor = vec3(shading.result);

    /* DRAWBUFFERS:0 */
    gl_FragData[0]  = vec4(returnColor, 1.0);
}