#version 400

const float shadowDistance      = 140.0;
const float ambientOcclusionLevel = 0.0f; 
const float shadowLuma          = 0.1;

/* SHADOWRES:4096 */
/* SHADOWHPL:140.0 */

const float sunlightLuma        = 1.5;
const float skylightLuma        = 0.1;
const float minLight            = 0.03;
vec3 minLightColor              = vec3(0.93, 0.95, 1.0);

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D shadow;

uniform int worldTime;

uniform float far;
uniform float near;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

in vec2 texcoord;

in vec3 sunVector;
in vec3 moonVector;
in vec3 lightVector;
in vec3 upVector;

in float timeSunrise;
in float timeNoon;
in float timeSunset;
in float timeNight;
in float timeMoon;
in float timeLightTransition;
in float timeSun;

in vec3 colSunlight;
in vec3 colSkylight;
in vec3 colSky;
in vec3 colHorizon;


struct colorBuffer{
    vec3 pre;
    vec3 normal;
    vec2 lightmap;
    vec4 mask;
} col;

struct masks{
    float terrain;
    float hand;
    float solid;
} mask;

struct depthBuffer{
    float depth;
    float linear;
} depth;

struct vectors{
    vec3 sun;
    vec3 moon;
    vec3 light;
    vec3 up;
    vec3 view;
} vec;

struct positions{
    vec3 sun;
    vec3 moon;
    vec3 light;
    vec3 up;
    vec4 screen;
    vec4 world;
    vec3 camera;
} pos;

struct shadingComponents{
    float shadow;
    float diffuse;
    float ao;
    float skylight;
    float cave;
    float lit;
    vec3 subsurface;
    vec3 result;
} shading;

struct materialMask{
    float foliage;
    float emissive;
} mat;

vec3 returnColor;

float bayer2(vec2 a){
    a = floor(a);
    return fract( dot(a, vec2(.5, a.y * .75)) );
}
#define bayer4(a)   (bayer2( .5*(a))*.25+bayer2(a))
#define bayer8(a)   (bayer4( .5*(a))*.25+bayer2(a))
#define bayer16(a)  (bayer8( .5*(a))*.25+bayer2(a))
#define bayer32(a)  (bayer16(.5*(a))*.25+bayer2(a))
#define bayer64(a)  (bayer32(.5*(a))*.25+bayer2(a))
#define bayer128(a) (bayer64(.5*(a))*.25+bayer2(a))
#define bayer256(a) (bayer128(.5*(a))*.25+bayer2(a))

float ditherStatic      = bayer64(gl_FragCoord.xy);
float ditherTemporal    = fract(ditherStatic+worldTime/22.0);

float pow2(float x) {
    return x*x;
}
float smoothstep(float x, float low, float high) {
    float t = clamp((x-low)/(high-low), 0.0, 1.0);
    return t*t*(3-2*t);
}

float depthLin(float depth) {
    return (2.0*near) / (far+near-depth * (far-near));
}
float depthLinInv(float depth) {
    return -((2.0*near / depth) - far-near)/(far-near);
}

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

const vec2 poissonOffsets[60] = vec2[60]  (  vec2(0.06120777f, -0.8370339f),
vec2(0.09790099f, -0.5829314f),
vec2(0.247741f, -0.7406831f),
vec2(-0.09391049f, -0.9929391f),
vec2(0.4241214f, -0.8359816f),
vec2(-0.2032944f, -0.70053f),
vec2(0.2894208f, -0.5542058f),
vec2(0.2610383f, -0.957112f),
vec2(0.4597653f, -0.4111754f),
vec2(0.1003582f, -0.2941186f),
vec2(0.3248212f, -0.2205462f),
vec2(0.4968775f, -0.6096044f),
vec2(0.770794f, -0.5416877f),
vec2(0.6429226f, -0.261653f),
vec2(0.6138752f, -0.7684944f),
vec2(-0.06001971f, -0.4079638f),
vec2(0.08106154f, -0.07295965f),
vec2(-0.1657472f, -0.2334092f),
vec2(-0.321569f, -0.4737087f),
vec2(-0.3698382f, -0.2639024f),
vec2(-0.2490126f, -0.02925519f),
vec2(-0.4394466f, -0.06632736f),
vec2(-0.6763983f, -0.1978866f),
vec2(-0.5428631f, -0.3784158f),
vec2(-0.3475675f, -0.9118061f),
vec2(-0.1321516f, 0.2153706f),
vec2(-0.3601919f, 0.2372792f),
vec2(-0.604758f, 0.07382818f),
vec2(-0.4872904f, 0.4500539f),
vec2(-0.149702f, 0.5208581f),
vec2(-0.6243932f, 0.2776862f),
vec2(0.4688022f, 0.04856517f),
vec2(0.2485694f, 0.07422727f),
vec2(0.08987152f, 0.4031576f),
vec2(-0.353086f, 0.7864715f),
vec2(-0.6643087f, 0.5534591f),
vec2(-0.8378839f, 0.335448f),
vec2(-0.5260508f, -0.7477183f),
vec2(0.4387909f, 0.3283032f),
vec2(-0.9115909f, -0.3228836f),
vec2(-0.7318214f, -0.5675083f),
vec2(-0.9060445f, -0.09217478f),
vec2(0.9074517f, -0.2449507f),
vec2(0.7957709f, -0.05181496f),
vec2(-0.1518791f, 0.8637156f),
vec2(0.03656881f, 0.8387206f),
vec2(0.02989202f, 0.6311651f),
vec2(0.7933047f, 0.4345242f),
vec2(0.3411767f, 0.5917205f),
vec2(0.7432346f, 0.204537f),
vec2(0.5403291f, 0.6852565f),
vec2(0.6021095f, 0.4647908f),
vec2(-0.5826641f, 0.7287358f),
vec2(-0.9144157f, 0.1417691f),
vec2(0.08989539f, 0.2006399f),
vec2(0.2432684f, 0.8076362f),
vec2(0.4476317f, 0.8603768f),
vec2(0.9842657f, 0.03520538f),
vec2(0.9567313f, 0.280978f),
vec2(0.755792f, 0.6508092f));

void diffuseLambert(in vec3 normal) {
    normal = normalize(normal);
    vec3 light = normalize(vec.light);
    float lambert = dot(normal, light);
        lambert = max(lambert, 0.0);
    shading.diffuse = mix(lambert, 1.0, mat.foliage*0.7+0.3);
}

void shadowing() {
    float shade = 1.0;
    float shadowMod = 1.0;
    float cDepth = 0.0;
    bool softShadow = true;
    int blurSamples = 21;
    float blurSize = 0.0003;
    float shadowDist  = 0.0;
    vec3 shadecol = vec3(1.0);
    vec3 foliageCol = vec3(1.0);
    
    float dist = length(pos.screen.xyz);

    if (dist<shadowDistance && dist > 0.05) {
        float shadowDistSq = pow2(shadowDistance);
        vec4 wPos = gbufferModelViewInverse*pos.screen;
        float distSqXz = dot(wPos.xz, wPos.xz);
        float distSqY = pow2(wPos.y);

        if (distSqY<shadowDistSq) {
            wPos = shadowModelView*wPos;
            cDepth = -wPos.z;
            wPos = shadowProjection*wPos;
            wPos /= wPos.w;
            wPos.st = wPos.st*0.5+0.5;

            if (cDepth>0.0 && wPos.s<1.0 && wPos.s>0.0 && wPos.t<1.0 && wPos.t>0.0) {
                shadowMod = min(1.0-distSqXz/shadowDistSq, 1.0) * min(1.0-distSqY/shadowDistSq, 1.0);
                shadowMod = clamp(shadowMod*1.7, 0.0, 1.0);
                float bias = -0.0004;
                vec2 offset = vec2(bias*0.0, bias);
                float diff = 0.6;
                float shadeBlur = 0.0;
                vec3 shadecolBlur = vec3(0.0);
                blurSize *= 1;
                
                if (softShadow) {
                    for (int i = 0; i<blurSamples; i++) {
                        shadeBlur += -shadowMod * (clamp(cDepth-(texture2D(shadow, wPos.st+offset+poissonOffsets[i]*blurSize).x)*256.0, 0.0, diff)/diff);
                    }
                    shade = 1.0 + shadeBlur/blurSamples;
                } else {
                    shade = 1.0 -shadowMod * (clamp(cDepth-(texture2D(shadow, wPos.st+offset).x)*256.0, 0.0, diff)/diff);
                }
            }
        }
    }
    shading.shadow = shade;
}

void dbao() {
    float maxDist   = 0.5;
    float smoothing = 0.3;
    float falloff   = clamp((depth.linear-(maxDist-smoothing/2))/smoothing, 0.0, 1.0);
    float ao        = 0.0;
    float dither    = ditherTemporal;
    const int aoArea = 2;
    const int samples = 2;
    float size      = 1.8/samples;
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
            sd      = depthLin(texture2D(gdepth, texcoord+vec2(cos(rot*piAngle), sin(rot*piAngle))*size*scale).r);
            float samp = far*(depth.linear-sd)/size;
            angle   = clamp(0.5-samp, 0.0, 1.0);
            dist    = clamp(0.0625*samp, 0.0, 1.0);
            sd      = depthLin(texture2D(gdepth, texcoord-vec2(cos(rot*piAngle), sin(rot*piAngle))*size*scale).r);
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

void applyShading() {
    shading.skylight    = smoothstep(col.lightmap.y, 0.18, 0.95);
    shading.cave        = smoothstep(col.lightmap.y, 0.36, 0.6);
    shading.lit         = shading.shadow*shading.diffuse*shading.ao;
    shading.subsurface  = mix(vec3(0.0), col.pre, mat.foliage*0.0);
    shading.result      = mix(colSkylight*skylightLuma+shading.subsurface, colSunlight*sunlightLuma, shadowLuma);
    shading.result      = mix(minLightColor*minLight, shading.result*shading.skylight, shading.cave);
    shading.result      = mix(shading.result, colSunlight*sunlightLuma, shading.lit*(1-timeLightTransition));
    returnColor         = returnColor*shading.result;
}

void skyGradient() {
    vec3 nFrag      = normalize(pos.screen.xyz);
    vec3 hVec       = normalize(-vec.up+nFrag);
    vec3 hVec2      = normalize(vec.up+nFrag);
    vec3 sgVec      = normalize(-vec.sun+nFrag);

    float hTop      = dot(hVec2, nFrag);
    float hBottom   = dot(hVec, nFrag);

    float zenith    = dot(hVec2, nFrag);
    float horizon   = clamp(1-max(hBottom*0.75, hTop), 0.0, 1.0);
        horizon     = pow(horizon*1.40, 2.60+timeNoon*0.40);
        //horizon     = clamp(horizon*4.0, 0.0, 1.0);
    float horizonLow = clamp(1-max(hBottom, hTop), 0.0, 1.0);
        horizonLow  = pow(horizonLow*2.5, 8.00+timeNoon);
        horizonLow *= 1+timeSunrise*0.50;
        horizonLow  = clamp(horizonLow*5.0, 0.0, 1.0);
        horizonLow *= 1.0-timeMoon;
    float glow      = clamp(1.0-dot(sgVec, nFrag), 0.0, 1.0);
        glow        = clamp(pow(glow, 25.0)*(1.0-timeNoon*0.6)+pow(horizon, 1.30)*(0.04+pow(glow, 4.0)*15.0), 0.0, 1.0);
        glow       *= 1-timeMoon;

    vec3 cSun       = colSunlight*clamp(1-timeMoon, 0.0, 1.0);
    vec3 cHorizon   = colHorizon;
    vec3 sky        = mix(colSky*(1.0-timeMoon*0.89), colHorizon, horizon);
        sky         = mix(sky, cSun*0.70, horizonLow);
        sky         = mix(sky, cSun, glow);
        sky        += col.pre.rgb*(1-mask.solid);

    returnColor     = mix(returnColor, sky, (1-mask.solid));
}

struct filmicTonemap {
    float shoulder;
    float slope;
    float toe;
    float angle;
    float white;
    float exposure;
} filmic;

vec3 filmicCurve(vec3 col) {
    float A   = filmic.shoulder;
    float B   = filmic.slope;
    float C   = filmic.angle;
    float D   = filmic.toe;
    const float E   = 0.01;
    const float F   = 0.30;
    return ((col * (A*col + C*B) + D*E) / (col * (A*col + B) + D*F)) - E/F;
}

void tonemapFilmic() {
    vec3 colIn = returnColor;
    colIn *= filmic.exposure;
    vec3 white = filmicCurve(vec3(filmic.white));
    vec3 colOut = filmicCurve(colIn);
    returnColor = colOut/white;
}

void main() {
    col.pre     = pow(texture2D(gcolor, texcoord).rgb, vec3(2.2));
    col.normal  = texture2D(gnormal, texcoord).rgb*2.0-1.0;
    col.lightmap = texture2D(composite, texcoord).rg;
    col.mask    = texture2D(gaux1, texcoord);
    depth.depth = texture2D(gdepth, texcoord).r;
    depth.linear = depthLin(depth.depth);

    mask.solid  = col.mask.r;

    pos.screen  = screenSpacePos(depth.depth);
    pos.world   = worldSpacePos(depth.depth);

    vec.light   = lightVector;
    vec.sun     = sunVector;
    vec.up      = upVector;

    filmic.shoulder  = 0.22;
    filmic.slope     = 0.35;
    filmic.toe       = 0.08;
    filmic.angle     = 0.60;
    filmic.white     = 1.00;
    filmic.exposure  = 1.00;

    shading.shadow  = 1.0;
    shading.diffuse = 1.0;
    shading.ao      = 1.0;

    returnColor     = col.pre;

    //diffuseLambert(col.normal);
    shadowing();
    dbao();
    applyShading();

    skyGradient();

    tonemapFilmic();

    //returnColor    = vec3(shading.result);

    gl_FragData[0] = vec4(returnColor, 1.0);
    gl_FragData[1] = vec4(vec3(depth.depth), 1.0);
    gl_FragData[2] = texture2D(gnormal, texcoord);
}