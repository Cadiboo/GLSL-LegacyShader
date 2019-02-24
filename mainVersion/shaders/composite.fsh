#version 130
#include "lib/global.glsl"
#include "lib/util/math.glsl"

const int RGBA16F = 0;

const int colortex4Format   = RGBA16F;

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2D noisetex;

const int noiseTextureResolution = 1024;
const int noiseTextureRes = noiseTextureResolution;

const float sunlightLum     = 20.0;
const float skylightLum     = 2.2;

uniform int worldTime;
uniform int frameCounter;

uniform float far;
uniform float near;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;
uniform float frameTimeCounter;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

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
    vec4 cloud;
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

#include "lib/util/depth.glsl"
#include "lib/util/positions.glsl"
#include "lib/util/dither.glsl"
#include "lib/util/heightFade.glsl"

float noise2DCloud(in vec2 coord, in vec2 offset, float size) {
    coord += offset;
    coord = ceil(coord*size);
    coord /= noiseTextureResolution;
    return texture2D(noisetex, coord).x*2.0-1.0;
}

const float cloudAltitude = 160.0;
const float cloudDepth    = 22.5;

float cloudDensityPlane(vec3 pos) {
    const float lowEdge     = cloudAltitude-cloudDepth/2;
    const float highEdge    = cloudAltitude+cloudDepth/2;
    float size              = 0.07;
    vec2 coord              = pos.xz;
    float height            = heightFade(pos, lowEdge, 0.0)-heightFade(pos, highEdge, 0.0);

    float animTick          = frameTimeCounter*1.0;
    vec2 animVec            = vec2(animTick, 0.0);
    
    float shape;
    shape           = noise2DCloud(coord, animVec, 0.25*size);
    shape          += noise2DCloud(coord, animVec, 0.5*size)*0.5;

    return clamp(ceil(shape)*height, 0.0, 1.0);
}
float cloudShading(vec3 pos, const int steps, float depth) {
    vec3 dir = mix(vec.light, vec.up, pow2(timeLightTransition));
        dir         = normalize(mat3(gbufferModelViewInverse)*dir);
    float rStep     = depth/steps;
    vec3 rayStep    = dir*rStep;
        pos        += vec3(0.0) + rayStep;
    float transmittance = 0.0;
    for (int i = 0; i<steps; ++i, pos += rayStep) {
        transmittance += cloudDensityPlane(pos);
    }
    return exp2(-transmittance * 0.2 * rStep);
}

void cloudVolumetricVanilla() {

    const int samples       = 10;
    const float lowEdge     = cloudAltitude-cloudDepth/2;
    const float highEdge    = cloudAltitude+cloudDepth/2;

    vec3 wPos   = worldSpacePos(depth.solid).xyz;
    vec3 wVec   = normalize(wPos-pos.camera.xyz);

    bool isCorrectStepDir = pos.camera.y<cloudAltitude;

    float heightStep    = cloudDepth/samples;
    float height;
    if (isCorrectStepDir) {
            height      = highEdge;
            height     -= heightStep*ditherDynamic;
    } else {
            height      = lowEdge;
            height     += heightStep*ditherDynamic;
    }

    vec3 lightColor     = light.sun*5.0;
        lightColor      = mix(lightColor, colSky*20.0, timeLightTransition);
    vec3 rayleighColor  = light.sky*0.4;

    float cloud         = 0.0;
    float shading       = 1.0;
    float scatter       = 0.0;
    float distanceFade  = 1.0;

    bool isCloudVisible = false;
    bool isCloserThanLastStep = false;

    float lastStepLength = 100000;

    for (int i = 0; i<samples; i++) {

    if (mask.terrain < 0.5) {
        isCloudVisible = (wPos.y>=pos.camera.y && pos.camera.y<=height) || 
        (wPos.y<=pos.camera.y && pos.camera.y>=height);
    } else if (mask.terrain > 0.5) {
        isCloudVisible = (wPos.y>=height && pos.camera.y<=height) || 
        (wPos.y<=height && pos.camera.y>=height);
    }

    if (isCloudVisible) {
        vec3 getPlane   = wVec*((height-pos.camera.y)/wVec.y);
        vec3 coord      = pos.camera.xyz+getPlane;
        float oD        = cloudDensityPlane(coord);

        float currStepLength = length(coord-pos.camera);

        distanceFade    = 1.0-smoothstep(currStepLength, 1300.0, 1600.0);

        isCloserThanLastStep = (currStepLength<lastStepLength) && oD>0.02;

        if (distanceFade>0.01) {
            cloud          += oD*pow(distanceFade, 1.0/samples);

            if (isCloserThanLastStep) {
                shading         = cloudShading(coord, 5, cloudDepth);
                scatter         = mix(scatter, shading*0.2, oD);
            }
        }
        
        if (oD>0.01) lastStepLength  = currStepLength;
    }
        if (isCorrectStepDir) {
        height         -= heightStep;
        } else {
        height         += heightStep; 
        }
    }
    vec3 color          = mix(rayleighColor, lightColor, scatter);

    if (cameraPosition.y<lowEdge && mask.translucency>0.5) {
        color          *= mix(vec3(1.0), normalize(bData.albedo), 1.0);
    }

    cloud               = clamp(cloud, 0.0, 1.0);
    //returnCol           = mix(returnCol, color, cloud);
    rData.cloud         = vec4(color, cloud);

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

    #ifdef setCloudVolume
        cloudVolumetricVanilla();
    #endif

    /*DRAWBUFFERS:04*/
    gl_FragData[0]  = toVec4(returnCol);
    gl_FragData[1]  = rData.cloud;
}