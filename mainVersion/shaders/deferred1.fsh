#version 130
#include "lib/global.glsl"
#include "lib/util/math.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;

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
in vec3 colSunglow;

struct bufferData {
    vec3 albedo;
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

struct lightData {
    vec3 sun;
    vec3 sky;
} light;

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

float noise2D(in vec2 coord) {
    coord /= noiseTextureRes;
    return texture2D(noisetex, coord).x;
}

void skyGradient() {
    vec3 nFrag      = -vec.view;
    vec3 hVec       = normalize(-vec.up+nFrag);
    vec3 hVec2      = normalize(vec.up+nFrag);
    vec3 sgVec      = normalize(vec.sun+nFrag);
    vec3 mgVec      = normalize(vec.moon+nFrag);

    float hTop      = dot(hVec, nFrag);
    float hBottom   = dot(hVec2, nFrag);

    float zenith    = dot(hVec2, nFrag);
    float horizonFade = linStep(hBottom, 0.3, 0.8);
        horizonFade = pow4(horizonFade)*0.8;

    float lowDome   = linStep(hBottom, 0.66, 0.71);
        lowDome     = pow3(lowDome);

    float horizonGrad = 1.0-max(hBottom, hTop);

    float horizon   = linStep(horizonGrad, 0.15, 0.31);
        horizon     = pow6(horizon);

    float sunGrad   = 1.0-dot(sgVec, nFrag);
    float moonGrad  = 1.0-dot(mgVec, nFrag);

    float horizonGlow = saturateF(pow2(sunGrad));
        horizonGlow = pow3(linStep(horizonGrad, 0.1-horizonGlow*0.1, 0.33-horizonGlow*0.05))*horizonGlow;
        horizonGlow = pow2(horizonGlow*1.3);
        horizonGlow = saturateF(horizonGlow*0.75);

    float sunGlow   = linStep(sunGrad, 0.7, 0.98);
        sunGlow     = pow6(sunGlow);
        sunGlow    *= 1.0-timeNoon*0.75-0.2;

    float moonGlow  = pow(moonGrad*0.85, 15.0);
        moonGlow    = saturateF(moonGlow*1.05)*0.8;

    float sunLimb   = 1.0-linStep(hBottom, 0.68, 0.74);
        sunLimb     = pow2(sunLimb);

    float sunAlbedo = smoothstep(sunGrad, 0.85, 0.95)*(1.0-timeMoon)*sunLimb;
    float moonAlbedo = smoothstep(moonGrad, 0.85, 0.95)*timeNight;

    vec3 sunColor   = colSunglow*2.2;
    vec3 sunLight   = colSunlight*2.2;
    vec3 moonColor  = vec3(0.66, 0.85, 1.0)*0.05;

    vec3 albedoCol  = sunAlbedo*normalize(sunLight)*50.0 + moonAlbedo*normalize(moonColor)*1.2;

    vec3 skyColor   = mix(colSky*(1.0-timeMoon*0.89), colHorizon, horizonFade);
        skyColor    = mix(skyColor, colSky*1.6+sunColor*0.8, lowDome);
        skyColor    = mix(skyColor, mix(sunColor, colHorizon*2.0, timeNoon*0.85), horizon*(1.0-timeMoon));
        skyColor    = mix(skyColor, sunColor*4.0+sunLight, saturateF(sunGlow+horizonGlow)*(1.0-timeNight));
        skyColor    = mix(skyColor, colHorizon, horizon*timeMoon*0.5);
        skyColor    = mix(skyColor, moonColor, moonGlow);

        skyColor   *= 4.5;
        skyColor   += bData.albedo*albedoCol*2.0;

    returnCol       = vec3(skyColor);
}

void skyStars(){
    vec3 fragPos = pos.screen.xyz;
    vec3 normFragpos = normalize(fragPos);
    vec3 wPos = vec3(gbufferModelViewInverse * vec4(fragPos,1.0));

    vec3 planeIntersect = wPos/(wPos.y+length(wPos.xz));
    float rotationValue = worldTime;
        rotationValue /= 24;
    vec2 rotate = vec2(rotationValue, -(pi/22)*rotationValue)*0.0018;
    vec2 coord = floor((planeIntersect.xz*0.4+pos.camera.xz*0.0001+rotate)*2048)/2048;
    vec2 coord2 = (planeIntersect.xz)*32+rotate*112;
        coord *= 1536.0;

	float NdotU = sqrt(sqrt(max(dot(normFragpos,normalize(vec.up)),0.0)));
	
    vec3 colorStar = vec3(0.5, 0.8, 1.0);
    vec3 colorStar2 = vec3(1.0, 0.4, 0.1);

    //coord.x +=rotationValue;

	float star = 1.0;
		star *= noise2D(coord.xy);
		star *= noise2D(coord.xy+0.1);
		star *= noise2D(coord.xy+0.23);

    float starVariation;
        starVariation = noise2D(coord2.xy)-0.5;
        starVariation *= noise2D(coord2.xy*0.77)*0.5+0.5;
        starVariation = clamp(starVariation, 0.0, 1.0);

	star = max(star-0.825,0.0)*5.0;
    star = clamp(star, 0.0, 1.0);

    colorStar = mix(colorStar, colorStar2, starVariation*2);
    colorStar = clamp(colorStar, 0.0, 1.0);

    returnCol += colorStar*0.1*star*(timeNight*0.3+timeMoon*0.7);
}

void main() {
    bData.albedo    = texture2D(colortex0, coord).rgb;
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

    if (mask.terrain<0.5) {
        skyGradient();
        skyStars();
    }

    /*DRAWBUFFERS:0*/
    gl_FragData[0]  = toVec4(returnCol);
}