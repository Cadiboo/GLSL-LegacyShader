#version 130
#include "lib/util/fastmath.glsl"
#include "lib/global.glsl"
#define INFO 0  //[0]

//#define DEPTH_DEBUG

const float gamma       = 2.2;
const float luma        = 0.0;
const float contrast    = 1.0;
const float saturation  = 1.09;

const int bitdepth  = bpc;

const float bloomIntensity  = 0.15*bloomInt;

const float eyeBrightnessHalflife = 10.0;
uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;

uniform float viewHeight;
uniform float viewWidth;
uniform float frameTime;
uniform int frameCounter;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

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

uniform sampler2D colortex0;    //COLOR HDR
uniform sampler2D colortex1;    //NORMALS
uniform sampler2D colortex2;    //MASK
uniform sampler2D colortex3;    //LIGHTING
uniform sampler2D colortex4;    //BLOOM
uniform sampler2D colortex5;    //VFOG
uniform sampler2D colortex6;    //VCLOUD
uniform sampler2D colortex7;    //BLOOM

uniform sampler2D depthtex0;

float depth;
float imageLuma;

struct imageColor {
    vec3 HDR;
    vec3 SDR;
    float exposure;
} col;

struct masks {
    float terrain;
    float hand;
    float solid;
    float translucency;
} mask;

#include "lib/util/dither.glsl"

void decodeMask() {
    vec3 maskBuffer     = texture2D(colortex2, texcoord).rgb;
    mask.terrain        = maskBuffer.r;
    mask.hand           = maskBuffer.g;
    mask.translucency   = maskBuffer.b;
    mask.solid          = clamp(maskBuffer.r+maskBuffer.g+maskBuffer.b, 0.0, 1.0);
}

#include "lib/post/motionblur.glsl"

float getLuma(vec3 color) {
	return dot(color,vec3(0.22, 0.687, 0.084));
}

vec3 bloomExpand(vec3 x){return x * x * x * x * 32.0;}
void bloom() {

    vec3 blur1 = bloomExpand(texture2D(colortex5,texcoord.xy/pow(2.0,2.0) + vec2(0.0,0.0)).rgb);
    vec3 blur2 = bloomExpand(texture2D(colortex5,texcoord.xy/pow(2.0,3.0) + vec2(0.3,0.0)).rgb);
    vec3 blur3 = bloomExpand(texture2D(colortex5,texcoord.xy/pow(2.0,4.0) + vec2(0.0,0.3)).rgb);
    vec3 blur4 = bloomExpand(texture2D(colortex5,texcoord.xy/pow(2.0,5.0) + vec2(0.1,0.3)).rgb);
    vec3 blur5 = bloomExpand(texture2D(colortex5,texcoord.xy/pow(2.0,6.0) + vec2(0.2,0.3)).rgb);
    vec3 blur6 = bloomExpand(texture2D(colortex5,texcoord.xy/pow(2.0,7.0) + vec2(0.3,0.3)).rgb);
    vec3 blur7 = bloomExpand(texture2D(colortex5,texcoord.xy/pow(2.0,8.0) + vec2(0.4,0.3)).rgb);
	
    vec3 blur = (blur1 + blur2 + blur3 + blur4 + blur5 + blur6 + blur7)*bloomIntensity;

    col.HDR += blur/7.0;
}

void lowlightDesaturation() {
    float luminance = getLuma(col.HDR.rgb);
    vec3 lowlightEyeCol = vec3(0.22, 0.55, 1.00);
    vec3 lowlightCol    = luminance*lowlightEyeCol;
    float threshold     = 0.007;
    float smoothing     = 0.01;
    float alpha         = 1-(clamp(((luminance+smoothing/2)-threshold)/smoothing, 0.0, 1.0));
    col.HDR             = mix(col.HDR, lowlightCol, alpha);
}

void autoExposureLegacy() {
    const float expMax  = 18.0;
    const float expMin  = minimumExposure;
    float eyeSkylight = eyeBrightnessSmooth.y*(1-timeNight*0.3-timeMoon*0.3);
    float eyeLight = eyeBrightnessSmooth.x*0.7;
    float imageLuma = max(eyeSkylight, eyeLight);
        imageLuma /= 240.0;
        imageLuma = pow4(imageLuma)*expMax;
        imageLuma = clamp(imageLuma, expMin, expMax); 
    col.exposure = 1.0 - exp(-1.0/imageLuma);
}

void autoExposureNonTemporal() {
    const float expMax  = 20.0;
    const float expMin  = minimumExposure;
	    imageLuma = length(texture2DLod(colortex0,vec2(0.5),log2(viewWidth*0.4)).rgb);
        imageLuma = exp(imageLuma*8.0);
		imageLuma = clamp((imageLuma), expMin, expMax);
	col.exposure = 1.0 - exp(-1.0/imageLuma);
}

void autoExposureAdvanced() {
    const float expMax  = 20.0;
    const float expMin  = minimumExposure;
	    imageLuma = texture2D(colortex7, texcoord).a;
        imageLuma = imageLuma*8.0;
		imageLuma = clamp((imageLuma), expMin, expMax);
	col.exposure = 1.0 - exp(-1.0/imageLuma);
}

struct filmicTonemap {
    float shoulder;
    float slope;
    float toe;
    float angle;
    float white;
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
    vec3 colIn = col.HDR;
    colIn *= col.exposure;
    vec3 white = filmicCurve(vec3(filmic.white));
    vec3 colOut = filmicCurve(colIn);
    col.SDR = colOut/white;
}

int getColorBit() {
	if (bitdepth==1) {
		return 1;
	} else if (bitdepth==2) {
		return 4;
	} else if (bitdepth==4) {
		return 16;
	} else if (bitdepth==6) {
		return 64;
	} else if(bitdepth==8){
		return 255;
	} else if (bitdepth==10) {
		return 1023;
	} else {
		return 255;
	}
}

void imageDither() {
    int bits = getColorBit();
    vec3 colDither = col.SDR.rgb;
        colDither *= bits;
        colDither += bayer64(gl_FragCoord.xy)-0.5;

        float colR = round(colDither.r);
        float colG = round(colDither.g);
        float colB = round(colDither.b);

    col.SDR.rgb = vec3(colR, colG, colB)/bits;
}

void colorGrading() {
    float luma = getLuma(col.SDR.rgb);
    col.SDR.rgb = mix(vec3(luma), col.SDR.rgb, saturation);
}

void main() {
	col.HDR = texture2D(colortex0, texcoord).rgb;
    col.SDR = col.HDR;
    col.exposure = 1.0;
    filmic.shoulder  = 0.28;
    filmic.slope     = 0.64;
    filmic.angle     = 0.52;
    filmic.toe       = 0.07;
    filmic.white     = 1.30;

    depth = texture2D(depthtex0, texcoord).r;
    imageLuma = 1.0;

    decodeMask();

    #ifdef mBlur
        motionblur();
    #endif
    
    #ifdef DEPTH_DEBUG
        col.HDR.rgb = vec3(depth);
    #endif

    #ifdef cBloom
        bloom();
    #endif

    #ifdef llDesat
    lowlightDesaturation();
    #endif

    #if exposureType == 0
        autoExposureAdvanced();
    #elif exposureType == 1
        autoExposureNonTemporal();
    #elif exposureType == 2
        autoExposureLegacy();
    #endif

    tonemapFilmic();
    colorGrading();
    imageDither();

    //col.SDR = texture2D(colortex5, texcoord).rgb*0.01;

    gl_FragColor = vec4(col.SDR.rgb, 1.0);
}