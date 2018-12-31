#version 130
const bool colortex5Clear = true;
#include "lib/buffers.glsl"
#include "lib/util/fastmath.glsl"
#include "lib/global.glsl"

const int shadowMapResolution   = 3072;         //[512 1024 1536 2048 2560 3072 4096]
const float shadowDistance      = 192.0;        //[96.0 128.0 160.0 192.0 224.0 256.0]
const float shadowLuma          = shadowSL;
const float shadowBias          = 0.85;

const float sunlightLuma        = 20.0*sunlightLum;
const float skylightLuma        = 2.2*skylightLum;
const float minLight            = minLightVal;
const vec3 minLightColor        = vec3(0.5);

const float pi = 3.14159265359;

const int noiseTextureResolution = 2048;

const bool shadowHardwareFiltering = true;
const bool shadowHardwareFiltering0 = true;
const bool shadowHardwareFiltering1 = true;

uniform float far;
uniform float near;
uniform float viewHeight;
uniform float viewWidth;
uniform int frameCounter;
uniform float frameTimeCounter;

uniform float biomeCold;
uniform float biomeHot;
uniform float biomeTropic;
uniform float biomeSnow;
uniform float biomeDesert;

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

uniform int isEyeInWater;

uniform sampler2D noisetex;

in float timeSunrise;
in float timeNoon;
in float timeSunset;
in float timeNight;
in float timeMoon;
in float timeLightTransition;
in float timeSun;

in float fogDensity;


float fogHeight = 0;

in vec2 texcoord;

in vec3 sunVector;
in vec3 moonVector;
in vec3 lightVector;
in vec3 upVector;

in vec3 colSunlight;
in vec3 colSkylight;
in vec3 colSky;
in vec3 colHorizon;

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

struct lightColors {
    vec3 sunlight;
    vec3 skylight;
    vec3 lightmap;
} lcol;

struct bufferOutput {
    vec4 vFog;
} bout;

vec3 returnColor;

#include "lib/decode.glsl"
#include "lib/util/dither.glsl"
#include "lib/util/depth.glsl"

vec4 screenSpacePos(float depth) {
    vec4 posNDC = vec4(texcoord.x*2.0-1.0, texcoord.y*2.0-1.0, 2.0*depth-1.0, 1.0);
    vec4 posCamSpace = gbufferProjectionInverse*posNDC;
    return posCamSpace/posCamSpace.w;
}
vec4 worldSpacePos(float depth) {
    vec4 posCamSpace = screenSpacePos(depth);
    vec4 posWorldSpace = gbufferModelViewInverse*posCamSpace;
    posWorldSpace.xyz += cameraPosition.xyz;
    return posWorldSpace;
}
vec4 worldSpacePosAir(float depth) {
    vec4 posCamSpace = screenSpacePos(depth);
    vec4 posWorldSpace = gbufferModelViewInverse*posCamSpace;
    posWorldSpace.xyz += cameraPosition.xyz;
    return posWorldSpace;
}
#include "lib/util/poisson.glsl"
float heightDensity(vec3 wPos, float limit, float smoothing) {
    float density = 0.0;
        density = clamp(((limit+smoothing/2)-wPos.y)/smoothing, 0.0, 1.0);
    return density;
}

float heightDensityFog(vec3 wPos) {
    return heightDensity(wPos, 100.0, 20.0);
}

vec4 rayPos(in float depth) {
    vec2 coord = gl_FragCoord.xy;
        coord.x /= viewWidth;
        coord.y /= viewHeight;
    vec4 posNDC = vec4((coord.x) * 2.0 - 1.0, (coord.y) * 2.0 - 1.0, 2.0 * depth - 1.0, 1.0);
    vec4 posCamSpace = gbufferProjectionInverse * posNDC;
        posCamSpace /= posCamSpace.w;
    vec4 posWorldSpace = gbufferModelViewInverse * posCamSpace;
    return posWorldSpace;
}

#ifdef TAA
float ditherDynamic     = ditherTemporal;
#else
float ditherDynamic     = ditherStatic;
#endif

void underwaterShadowcol() {
    if (isEyeInWater == 1) {
        lcol.skylight     *= vec3(0.3, 0.66, 1.0)*0.3;
        lcol.sunlight     *= vec3(0.3, 0.66, 1.0)*0.3;
    }
}

void volumetricFog() {
    float dither    = ditherDynamic;
    float rayStart  = depth.linear;
        rayStart    = mix(rayStart, 0.6, (1-mask.solid));
    float rayEnd    = 0.0;
    const int samples = fogSamp;
    float rayStep   = rayStart/samples;
    float rayDepth  = rayStart;
        rayDepth   -= rayStep*dither;
    
    float shade     = 1.0;
    float cDepth    = 0.0;
    float shadowMod = 1.0;

    float scatter   = 0.0;
    float transmittance = 1.0;
    float scatterCoefficient = 0.66;
    float transmittanceCoefficient = 0.1;
    float density   = fogDensity;
    float weight    = 8/samples;
    if (samples < 4) {
        weight += 4-samples;
    }

    vec3 lightColor = mix(lcol.sunlight, colSkylight*sunlightLuma, timeNoon*0.75);
    vec3 rayleighColor = lcol.skylight*(1+timeLightTransition*1.5)*0.5;

    for (int i = 0; i<samples; i++) {
        if (rayDepth > rayEnd) {
            float rayD = depthLinInv(rayDepth);
            vec4 rayP = rayPos(rayD);
            float rayDensity = (sqrt(rayDepth)*1.8)*0.66 + (rayDepth*2.7)*0.33;
            float oD = rayDensity*heightDensityFog(rayP.xyz+cameraPosition.xyz);
            density *= 1+oD*0.25*weight;

            //shadows
            vec4 wPos = rayP;
            wPos = shadowModelView * wPos;
            wPos = shadowProjection * wPos;
            wPos /= wPos.w;
            //wPos.z += 0.02;
            float distortion = sqrt(wPos.x*wPos.x + wPos.y*wPos.y);
                distortion = (1.0-shadowBias) + distortion*shadowBias;
            wPos.xy *= 1.0/distortion;
            wPos = wPos*0.5+0.5;
                if (wPos.s < 1.0 && wPos.s > 0.0 && wPos.t < 1.0 && wPos.t > 0.0) {
                    shade = shadow2D(shadowtex1, vec3(wPos.st, wPos.z)).x;
                }
            
            scatter += scatterCoefficient*transmittance*oD*shade*(1-timeLightTransition);
            transmittance *= exp(-oD*transmittanceCoefficient);
            rayDepth -= rayStep;
            } else {
                break;
            }
        }
    vec3 fogColor = mix(rayleighColor, lightColor, scatter);
    //returnColor = mix(returnColor, fogColor, density);
    bout.vFog   = vec4(fogColor, density);
}

void simpleFogLayer() {
    float density   = fogDensity;
        density    *= 0.005/fogDensity;
    float maxDensity = 0.24;
    vec3 fogColor   = mix(lcol.sunlight*(1-timeLightTransition), colSkylight*sunlightLuma*(1.0+timeLightTransition), 0.2+timeNoon*0.7);
    float d         = length(pos.camera.xz-pos.worldSpace.xz)/far;
    float start     = 0.75;
    float smoothing = 0.5;
    float falloff   = clamp(((d-(start-smoothing/2))/smoothing)*maxDensity, 0.0, 0.7);
        falloff    *= heightDensityFog(pos.worldSpace.xyz)*0.6+0.4;

    returnColor     = mix(returnColor, fogColor, falloff*saturateFLOAT(mask.solid+mask.translucency));
}

void simpleFog() {
    float density   = fogDensity;
    float maxDensity = 0.08;
    vec3 fogColor   = mix(lcol.sunlight*(1-timeLightTransition), colSkylight*sunlightLuma*(3.0+timeLightTransition), 0.2+timeNoon*0.7);
    float d         = length(pos.camera.xz-pos.worldSpace.xz)/far;
    float start     = 0.56-fogDensity*6.0;
    float smoothing = 0.75;
    float falloff   = clamp(((d-(start-smoothing/2))/smoothing)*maxDensity, 0.0, 0.7);
        falloff    *= heightDensityFog(pos.worldSpace.xyz)*0.6+0.4;

    returnColor     = mix(returnColor, fogColor, falloff*saturateFLOAT(mask.solid+mask.translucency));
}

void main() {
    cbuffer.albedo  = texture2D(colortex0, texcoord);
    cbuffer.normal  = texture2D(colortex1, texcoord).rgb*2.0-1.0;
    cbuffer.mask    = texture2D(colortex3, texcoord);
    cbuffer.lightmap = texture2D(colortex2, texcoord).xy;

    decodeMask();
    mask.translucency   = texture2D(colortex5, texcoord).z;

    depth.depth     = texture2D(depthtex0, texcoord).x;
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

    bout.vFog       = vec4(0.0);

    returnColor = cbuffer.albedo.rgb;

    lcol.sunlight   = colSunlight*sunlightLuma;
    lcol.skylight   = colSkylight*skylightLuma;

    underwaterShadowcol();

    #ifdef volFog
        //simpleFogLayer();
        volumetricFog();
    #else
        #ifdef sFog
            simpleFog();
        #endif
    #endif

    //returnColor = vec3(shading.lit);

    /* DRAWBUFFERS:025 */
    gl_FragData[0]  = vec4(returnColor, 1.0);
    gl_FragData[1]  = vec4(mask.terrain, mask.hand, mask.translucency, 1.0);
    gl_FragData[2]  = bout.vFog;
}