#version 130
#include "lib/global.glsl"

const float sunlightLuma        = 20.0*sunlightLum;
const float skylightLuma        = 2.2*skylightLum;
const float minLight            = minLightVal;
const vec3 minLightColor        = vec3(0.5);

uniform sampler2D colortex0;    //COLOR HDR
uniform sampler2D colortex1;    //NORMALS
uniform sampler2D colortex2;    //MASK
uniform sampler2D colortex3;    //LIGHTING
uniform sampler2D colortex4;    //MATERIAL

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

uniform sampler2D noisetex;

const int noiseTextureResolution = 2048;
const int noiseTextureRes = noiseTextureResolution;

const float pi = 3.14159265359;

uniform float far;
uniform float near;
uniform float aspectRatio;
uniform float frameTimeCounter;

uniform int worldTime;
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

vec3 returnColor = vec3(1.0);

#include "lib/decode.glsl"
#include "lib/util/depth.glsl"
#include "lib/util/dither.glsl"
#include "lib/util/fastmath.glsl"
#include "lib/util/taaJitter.glsl"

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
float getLuma(vec3 color) {
	return dot(color,vec3(0.22, 0.687, 0.084));
}
float noise2D(in vec2 coord) {
    coord /= noiseTextureRes;
    return texture2D(noisetex, coord).x;
}

float glowGrad;
float horizonGrad;
void skyGradient() {
    vec3 nFrag      = normalize(pos.screenSpace.xyz);
    vec3 hVec       = normalize(-vec.up+nFrag);
    vec3 hVec2      = normalize(vec.up+nFrag);
    vec3 sgVec      = normalize(-vec.sun+nFrag);
    vec3 mgVec      = normalize(-vec.moon+nFrag);

    float hTop      = dot(hVec2, nFrag);
    float hBottom   = dot(hVec, nFrag);

    float zenith    = dot(hVec2, nFrag);
    float horizon   = clamp(1-max(hBottom*0.85, hTop), 0.0, 1.0);
        horizon     = pow(horizon*2.20, 5.20+timeNoon*0.60);
        //horizon     = clamp(horizon*4.0, 0.0, 1.0);
        
    float horizonLow = clamp(1-max(hBottom, hTop), 0.0, 1.0);
        horizonLow  = pow(horizonLow*2.5, 8.00+timeNoon*4.0);
        horizonLow *= 1+timeSunrise*0.50;
        horizonLow  = clamp(horizonLow*5.0, 0.0, 1.0);
        horizonLow *= 1.0-timeMoon;
        
    float glow      = clamp(1.0-dot(sgVec, nFrag), 0.0, 1.0);
        glow        = clamp(pow(glow, 18.0)*(1.0-timeNoon*0.85)+pow(horizon, 1.20)*(0.04+pow(glow, 4.0)*15.0), 0.0, 1.0);
        glow       *= 1-timeMoon;
    float mglow     = clamp(1.0-dot(mgVec, nFrag), 0.0, 1.0);
        //mglow       = smoothstep(mglow, 0.7, 1.0);
        mglow       = pow(mglow, 18.0)*timeNight;

    vec3 cSun       = lcol.sunlight*clamp(1-timeMoon, 0.0, 1.0)*0.5;
    vec3 cMoon      = vec3(0.66, 0.85, 1.0)*0.004;
    vec3 cHorizon   = colHorizon*1.3;
    vec3 sky        = mix(colSky*(1.0-timeMoon*0.89), colHorizon, horizon);
        sky         = mix(sky, cSun*0.70, horizonLow*(0.6+timeNoon*0.3+timeSunset*0.35));
        sky         = mix(sky, cSun, glow);
        sky         = mix(sky, cMoon, mglow);
        sky        *= 4.5;
        sky        += cbuffer.albedo.rgb*(1.0+mglow*20.0+glow*25.0*(1-mat.cloud*0.7))*(1-mask.solid)*(normalize(cMoon)*0.5+0.5);

    returnColor     = mix(returnColor, sky, (1-mask.solid));
    horizonGrad     = horizon;
    glowGrad        = glow;
}

void skyStars(){
    vec3 fragPos = pos.screenSpace.xyz;
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

    returnColor += mix(vec3(0.0), colorStar*0.1, star*(timeNight*0.3+timeMoon*0.7)*(1-mask.solid));
}

float noise2DCloud(in vec2 coord, in vec2 offset) {
    coord += offset;
    coord = ceil(coord);
    coord /= noiseTextureRes;
    return texture2D(noisetex, coord).x*2.0-1.0;
}

float cloudCirrusDensity(vec2 coord) {
    float noise;
    float windAnim = frameTimeCounter;
    vec2 wind = vec2(windAnim)*vec2(1.0, 0.0);
        wind *= 0.12;

    noise += noise2DCloud(coord*0.5, wind*0.5);
    noise += noise2DCloud(coord*2.0, wind*2.0)*0.25;
    //noise += noise2DCloud(coord*4.0, wind*4.0)*0.25;
    //noise *= noise2DCloud(coord*4.0, wind*4.0)*0.5+0.5;
    return clamp(ceil(noise), 0.0, 1.0);
}

void cloud2D(in float alpha) {
    vec3 wPos = pos.worldSpace.xyz;
        wPos -= cameraPosition.xyz;
    vec3 wPosAbs = pos.worldSpace.xyz;
    vec3 wVec = normalize(wPos);

    float cloudHeight = 800.0;
    float alphaMix = 1.0;

    if (alpha < 0.1) {
        if(wPos.y>0 && pos.camera.y<cloudHeight) {
            alphaMix = 1.0;
        } else if(wPos.y<0 && pos.camera.y>cloudHeight) {
            alphaMix = 1.0;
        } else {
            alphaMix =0.0;
        }
    } else if (alpha > 0.9) {
        if(wPosAbs.y>cloudHeight && pos.camera.y<cloudHeight) {
            alphaMix = 1.0;
        } else if(wPosAbs.y<cloudHeight && pos.camera.y>cloudHeight) {
            alphaMix = 1.0;
        } else {
            alphaMix = 0.0;
        }
    }

    float noise;

    if (alphaMix > 0.9) {
        float size = 20.0;
        vec3 planeIntersect = wVec*((cloudHeight-pos.camera.y)/wVec.y)*0.2;
        vec2 coord = pos.camera.xz*0.2+planeIntersect.xz;
        coord /= size;
        noise = cloudCirrusDensity(coord);
    }

    vec3 cloudDiffuse = vec3(1.0);
    vec3 result = cloudDiffuse;
    float cloudAlpha = clamp(noise*alphaMix*(1-horizonGrad*5), 0.0, 1.0);
    returnColor = mix(returnColor, result, pow2(cloudAlpha));
}

void main() {
    cbuffer.albedo  = texture2D(colortex0, texcoord);
    cbuffer.normal  = texture2D(colortex1, texcoord).rgb*2.0-1.0;
    cbuffer.mask    = texture2D(colortex3, texcoord);
    cbuffer.lightmap = texture2D(colortex2, texcoord).xy;

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

    lcol.sunlight   = colSunlight*sunlightLuma;
    lcol.skylight   = colSkylight*skylightLuma;

    skyGradient();
    skyStars();
    //cloud2D(mask.solid);

    /* DRAWBUFFERS:0 */
    gl_FragData[0]  = vec4(returnColor, 1.0);
}