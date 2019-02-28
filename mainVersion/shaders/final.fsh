#version 130
#include "lib/util/math.glsl"
#include "lib/global.glsl"

#define setBrightness 1.0
#define setContrast 0.95
#define setCurve 1.04

const float saturation      = 1.0;

uniform sampler2D colortex0;
uniform sampler2D colortex7;

const bool colortex0MipmapEnabled = true;

uniform float viewHeight;
uniform float viewWidth;

uniform int isEyeInWater;

in vec2 coord;

struct sceneColorData {
    vec3 hdr;
    vec3 sdr;
    float exposure;
} col;

vec3 returnCol;
float imageLuma;

void autoExposureAdvanced() {
    const float expMax  = expMaximum;
    const float expMin  = expMinimum;
	    imageLuma = texture2D(colortex7, coord).a;
		imageLuma = clamp((imageLuma), expMin, expMax);
	col.exposure = 1.0 - exp(-1.0/imageLuma);
}
void autoExposureNonTemporal() {
    const float expMax  = 20.0;
    const float expMin  = expMinimum;
	    imageLuma = length(texture2DLod(colortex0,vec2(0.5),log2(viewWidth*0.4)).rgb);
        imageLuma = exp(imageLuma);
		imageLuma = clamp((imageLuma), expMin, expMax);
	col.exposure = 1.0 - exp(-1.0/imageLuma);
}
void fixedExposure() {
    float exposure = 25.0;
    col.exposure   = 1.0 - exp(-1.0/exposure);
}

struct filmicTonemap {
    float curve;
    float toe;
    float angle;
    float slope;
    float black;
    float range;
    float white;
} filmic;

vec3 filmicCurve(vec3 col) {
    float A   = filmic.curve;
    float B   = filmic.toe;
    float C   = filmic.slope;
    float D   = filmic.angle;
    float E   = filmic.black;
    float F   = filmic.range;
    return ((col * (A*col + C*B) + D*E) / (col * (A*col + B) + D*F)) - E/F;
}

void tonemapFilmic() {
    vec3 colIn = col.hdr;
    colIn *= col.exposure;
    vec3 white = filmicCurve(vec3(filmic.white));
    vec3 colOut = filmicCurve(colIn);
    col.sdr = colOut/white;
}


vec3 brightenContrast(vec3 x, const float brighten, const float contrast) {
    return (x - 0.5) * contrast + 0.5 + brighten;
}
vec3 curve(vec3 x, const float exponent) {
    return vec3(pow(abs(x.r), exponent),pow(abs(x.g), exponent),pow(abs(x.b), exponent));
}

void colorGrading() {
    col.sdr     = curve(col.sdr, setCurve);
    col.sdr     = brightenContrast(col.sdr, setBrightness-1.0, setContrast);
    float imageLuma = getLuma(col.sdr);
    col.sdr     = mix(vec3(imageLuma), col.sdr, saturation);
}

void underwaterColor() {
    if (isEyeInWater == 1) {
        col.sdr = mix(col.sdr, getLuma(col.sdr)*vec3(0.4, 0.82, 1.0), 0.75);
    } 
    if (isEyeInWater == 2) {
        col.sdr = mix(col.sdr, getLuma(col.sdr)*vec3(1.6, 0.47, 0.0), 0.75);
    } 
}

void main() {
    col.hdr         = texture2D(colortex0, coord).rgb;
    col.sdr         = col.hdr;
    col.exposure    = 1.0;

    filmic.curve        = 0.22;
    filmic.toe          = 0.79;
    filmic.slope        = 0.72;
    filmic.angle        = 0.52;
    filmic.black        = 0.00;
    filmic.range        = 0.52;
    filmic.white        = 5.00;

    autoExposureAdvanced();
    tonemapFilmic();
    underwaterColor();
    colorGrading();

    returnCol       = col.sdr;


    gl_FragColor    = toVec4(returnCol);
}