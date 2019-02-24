#version 130
#include "lib/global.glsl"
#include "lib/util/math.glsl"

    const int shadowMapResolution   = 3072;         //[512 1024 1536 2048 2560 3072 4096]

    const float shadowDistance      = 192.0;        //[96.0 128.0 160.0 192.0 224.0 256.0]
    const float shadowIlluminance   = setShadowIlluminance;
    const float shadowBias          = 0.85;

    const bool shadowHardwareFiltering = true;

const int RGBA16F = 0;

const int colortex4Format   = RGBA16F;

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2D noisetex;

uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;
uniform sampler2DShadow shadowcolor0;

const int noiseTextureResolution = 1024;
const int noiseTextureRes = noiseTextureResolution;

const float sunlightLum     = 20.0;
const float skylightLum     = 2.2;

uniform int worldTime;
uniform int frameCounter;

uniform ivec2 eyeBrightnessSmooth;

uniform float far;
uniform float near;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform float rainStrength;

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

in float timeSunrise;
in float timeNoon;
in float timeSunset;
in float timeNight;
in float timeMoon;
in float timeLightTransition;
in float timeSun;
in float fogDensity;

in vec2 coord;

in vec3 sunVector;
in vec3 moonVector;
in vec3 lightVector;
in vec3 upVector;

in vec3 colSunlight;
in vec3 colSkylight;
in vec3 colSky;
in vec3 colHorizon;

struct bufferData {
    vec3 albedo;
    vec4 mask;
} bData;

struct depthData {
    float depth;
    float linear;
    float solid;
    float solidLin;
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

struct lightData {
    vec3 sun;
    vec3 sky;
} light;

struct returnData {
    vec4 fog;
    vec4 fogUnderwater;
} rData;

struct maskData {
    float terrain;
    float hand;
    float translucency;
} mask;

float unmap(in float x, float low, float high) {
    if (x < low || x > high) x = low;
    x -= low;
    x /= high-low;
    x /= 0.99;
    x = clamp(x, 0.0, 1.0);
    return x;
}

void decodeBuffer() {
    float maskData  = bData.mask.r;
    
    mask.terrain    = float(maskData > 0.5);
    mask.hand       = float(maskData > 1.5 && maskData < 2.5);
    mask.translucency = float(maskData > 2.5 && maskData < 3.5);
}

vec3 returnCol  = vec3(0.0);
float water     = 0.0;

const float fogAltitude     = 100.0;
const float fogSmoothing    = 40.0;


#include "lib/util/depth.glsl"
#include "lib/util/positions.glsl"
#include "lib/util/dither.glsl"
#include "lib/util/heightFade.glsl"

float getPhaseSimple() {
    return (dot(vec.view, vec.light))*0.5+0.5;
}

vec4 rayPos(in float depth) {
    vec4 posNdc     = vec4((coord.x)*2.0-1.0, (coord.y)*2.0-1.0, 2.0*depth-1.0, 1.0);
    vec4 posScreen  = gbufferProjectionInverse*posNdc;
        posScreen  /= posScreen.w;
    vec4 posWorld   = gbufferModelViewInverse*posScreen;
    return posWorld;
}

void fogVolumetric() {
    const float highEdge    = fogAltitude+fogSmoothing;
    const int samples   = 8;
    float skyPhase      = dot(vec.view, vec.up)*0.5+0.5;
        skyPhase        = (1.0-linStep(skyPhase, 0.6, 1.0))*0.5+0.5;
        skyPhase        = mix(skyPhase, 1.0, 0.7*mask.terrain);
    float baseDensity = min(0.5*fogDensity, 1.0*skyPhase);
        //density        *= mix(0.8, 1.0, mask.terrain*(1.0-rainStrength));
    float dither        = ditherDynamic;

#ifdef setFogVolWater
    float rayStart      = depth.solidLin;
#else
    float rayStart      = depth.linear;
#endif

    //float rayEnd        = 0.0;
    float rayStep       = rayStart/samples;
    float rayDepth      = rayStart - rayStep*dither;

    float scatter       = 0.0;
    float transmittance = 1.0;
    float scatterCoeff = 0.5;
    const float transmittanceCoeff = 1.0;
    float density       = 0.2*fogDensity;

    #ifdef setFogVolWater
        vec3 scatterUW     = vec3(0.0);
        float transmittanceUW = 1.0;
        float baseDensityUW = 0.6;
        float densityUW     = 0.4;
        float scatterCaustic = 1.0;
        bool isWaterFog = false;
        vec3 waterExtinction = setGlobWaterColor*0.08;
    #endif

    float shade         = 1.0;
    float cDepth        = 0.0;
    float shadowFade    = 1.0;
    float distortion    = 0.0;
    float weight        = 8.0/samples;
    float rayDensity    = 0.0;
    //vec4 shadowcol      = vec4(1.0);
    //vec3 scatterCol     = vec3(1.0);

    float fogPhase      = linStep(getPhaseSimple(), 0.4, 1.0)*0.5+0.8;
    float sunPhase      = pow3(getPhaseSimple())*0.3+0.7;

    vec3 sunlight       = light.sun;
        sunlight        = mix(sunlight, light.sky*(sunlightLum/skylightLum)*3.0, timeNoon*0.75);
    vec3 rayleigh       = light.sky*(1.0+timeLightTransition*3.0);
        rayleigh       *= exp(rayStart)*0.1;
        rayleigh        = mix(vec3(0.0), rayleigh, linStep(eyeBrightnessSmooth.y/240.0, 0.0, 0.5));

    for (int i = 0; i<samples; i++) {
        if (rayDepth>0.0) {
            float rDepth    = depthLinInv(rayDepth);
            vec4  rPos      = rayPos(rDepth);
            float rDepthFix = (length(rPos.xyz))/far16;
            float rStepFix  = rDepthFix/samples;

            #ifdef setFogVolWater
                float rDepthMax = depth.solidLin;
                isWaterFog = (rDepth>depth.depth && isEyeInWater==0 && water>0.5 && mask.terrain>0.5) || (rDepth<depth.depth && isEyeInWater==1);
                if (isEyeInWater==0) {
                rDepthMax = depth.solidLin;
                } else {
                rDepthMax = depth.linear;
                }
            #endif

            if ((rPos.y+pos.camera.y)<highEdge && (rPos.y+pos.camera.y)>(-50.0)) {
                rayDensity      = rStepFix*5.0;
                float oD        = rayDensity*(1.0-heightFade(rPos.xyz+pos.camera.xyz, fogAltitude, fogSmoothing));

                #ifdef setFogVolWater
                    float oDUW          = clamp(rayDepth, 0.0, rDepthMax)*2.0;
                #endif

                float shadowDistSq  = pow2(shadowDistance);
                vec4 wPos           = rPos;
                float distSqXZ  = pow2(wPos.x) + pow2(wPos.z);
                float distSqY   = pow2(wPos.y);
                    shadowFade  = min(1.0-distSqXZ/shadowDistSq, 1.0);
                    shadowFade  = saturateF(shadowFade);

                if (distSqY<shadowDistSq) {
                    wPos    = shadowModelView*wPos;
                    wPos    = shadowProjection*wPos;
                    wPos   /= wPos.w;
                        distortion = sqrt(wPos.x*wPos.x + wPos.y*wPos.y);
                        distortion = (1.0-shadowBias) + distortion*shadowBias;
                        wPos.xy   *= 1.0/distortion;
                    wPos.xyz        = wPos.xyz*0.5+0.5;

                    if (wPos.x<1.0 && wPos.x>0.0 && wPos.y<1.0 && wPos.y>0.0) {
                        #ifdef setFogVolWater
                        shade   = shadow2D(shadowtex1, wPos.xyz).x;
                        #else
                        shade   = shadow2D(shadowtex0, wPos.xyz).x;
                        #endif

                        #ifdef setFogVolWater
                        scatterCaustic = 0.0;                        
                        if (isWaterFog) {
                            vec4 shadowcol = shadow2D(shadowcolor0, wPos.xyz);
                            shadowcol.rgb = mix(vec3(1.0), shadowcol.rgb, shadowcol.a);
                            scatterCaustic = saturateF((shadowcol.rgb).b*1.5-0.04);
                            //scatterCol = mix(scatterCol, setGlobWaterColor, oD);
                        } else {
                            //shadowcol = vec4(1.0);
                            //scatterCol = mix(scatterCol, vec3(1.0), oD);
                        }
                        #endif
                        
                        
                    }
                }
                #ifdef setFogVolWater
                if (isWaterFog) {
                    densityUW        *= baseDensityUW+oDUW*1.03;
                    scatterUW        += waterExtinction*transmittanceUW*oDUW*shade*scatterCaustic*(shadowFade*0.2+0.8);
                    transmittanceUW  *= exp2(-oDUW*0.2);
                } else {
                    density        *= baseDensity+oD;
                    scatter        += scatterCoeff*transmittance*rayDensity*shade*(shadowFade*0.2+0.8)*fogPhase;
                    transmittance  *= exp2(-oD*transmittanceCoeff);
                }
                #else
                    density        *= baseDensity+oD;
                    scatter        += scatterCoeff*transmittance*rayDensity*shade*(shadowFade*0.2+0.8)*fogPhase;
                    transmittance  *= exp2(-oD*transmittanceCoeff);
                #endif
            }
        rayDepth       -= rayStep;
        } else {
            break;
        }
    }

bool isNotWaterTranslucent = mask.translucency>0.5 && water<0.5;
float translucencyAlpha = 1.0;

    vec3 col    = rayleigh*transmittance + sunlight*scatter*(1.0-timeLightTransition);
    if (isNotWaterTranslucent) {
    translucencyAlpha = (1.0-heightFade(pos.world.xyz, fogAltitude, fogSmoothing))*smoothstep((length(pos.world.xyz-pos.camera.xyz)/far), 0.0, 0.4*(1.0/fogDensity))*0.5+0.5;
        col    *= mix(normalize(bData.albedo), vec3(1.0), translucencyAlpha);
    }
    //col = vec3(translucencyAlpha);
    rData.fog   = vec4(col, saturateF(density)*mix(0.8, 1.0, mask.terrain*(1.0-rainStrength)));
    //rData.fog.rgb = vec3(rData.fog.a);
    //rData.fog.a = 1.0;

#ifdef setFogVolWater
    vec3 colWater = rayleigh*transmittanceUW*waterExtinction + sunlight*scatterUW*(1.0-timeLightTransition)*0.7;
    rData.fogUnderwater = vec4(colWater, saturateF(densityUW*weight)*mix(0.0, 1.0, max(water, float(isEyeInWater==1))));
    returnCol = mix(returnCol, rData.fogUnderwater.rgb, rData.fogUnderwater.a);
#endif

    returnCol = mix(returnCol, rData.fog.rgb, rData.fog.a);
}

void main() {
    bData.albedo    = texture2D(colortex0, coord).rgb;
    bData.mask      = texture2D(colortex3, coord);

    decodeBuffer();

    depth.depth     = texture2D(depthtex0, coord).x;
    depth.linear    = depthLin(depth.depth);
    depth.solid     = texture2D(depthtex1, coord).x;
    depth.solidLin  = depthLin(depth.solid);

    mask.translucency = float(depth.solid > depth.depth);
    water   = float(depth.depth<depth.solid);

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

    fogVolumetric();

    /*DRAWBUFFERS:04*/
    gl_FragData[0]  = toVec4(returnCol);
    gl_FragData[1]  = rData.fog;
}