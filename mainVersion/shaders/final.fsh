#version 130
#include "lib/util/math.glsl"

const float expMinimum      = 0.1;

const float saturation      = 1.0;

uniform sampler2D colortex0;
uniform sampler2D colortex7;

const bool colortex0MipmapEnabled = true;

uniform float viewHeight;
uniform float viewWidth;

in vec2 coord;

struct sceneColorData {
    vec3 hdr;
    vec3 sdr;
    float exposure;
} col;

vec3 returnCol;
float imageLuma;

void autoExposureAdvanced() {
    const float expMax  = 20.0;
    const float expMin  = expMinimum;
	    imageLuma = texture2D(colortex7, coord).a;
        imageLuma = imageLuma*8.0;
		imageLuma = clamp((imageLuma), expMin, expMax);
	col.exposure = 1.0 - exp(-1.0/imageLuma);
}
void autoExposureNonTemporal() {
    const float expMax  = 20.0;
    const float expMin  = expMinimum;
	    imageLuma = length(texture2DLod(colortex0,vec2(0.5),log2(viewWidth*0.4)).rgb);
        imageLuma = exp(imageLuma*8.0);
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

void colorGrading() {
    float imageLuma = getLuma(col.sdr);
    col.sdr     = mix(vec3(imageLuma), col.sdr, saturation);
}

void main() {
    col.hdr         = texture2D(colortex0, coord).rgb;
    col.sdr         = col.hdr;
    col.exposure    = 1.0;

    filmic.curve        = 0.28;
    filmic.toe          = 0.52;
    filmic.slope        = 0.64;
    filmic.angle        = 0.07;
    filmic.black        = 0.00;
    filmic.range        = 0.30;
    filmic.white        = 1.30;

    autoExposureAdvanced();
    tonemapFilmic();
    colorGrading();

    returnCol       = col.sdr;


    gl_FragColor    = toVec4(returnCol);
}