#version 130
#include "/lib/util/math.glsl"
#include "/lib/global.glsl"

const float bloomIntensity  = 0.2;

uniform sampler2D colortex0;    //scene color
uniform sampler2D colortex3;    //scene material masks
uniform sampler2D colortex4;
uniform sampler2D depthtex0;

uniform int frameCounter;

uniform float near;
uniform float far;
uniform float viewHeight;
uniform float viewWidth;
uniform float aspectRatio;
uniform float frameTime;
uniform float centerDepthSmooth;
const float centerDepthHalflife = 2.0;

in vec2 coord;

float depth;
vec3 returnCol;

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
    vec4 maskBuffer = texture2D(colortex3, coord);
    float maskData  = maskBuffer.r;
    
    mask.terrain    = float(maskData > 0.5);
    mask.hand       = float(maskData > 1.5 && maskData < 2.5);
    mask.translucency = float(maskData > 2.5 && maskData < 3.5);
}

vec3 bloomExpand(vec3 x) {
    return x * x * x * x * 32.0;
}
void bloom() {
    vec3 blur1 = bloomExpand(texture2D(colortex4,coord.xy/pow(2.0,2.0) + vec2(0.0,0.0)).rgb);
    vec3 blur2 = bloomExpand(texture2D(colortex4,coord.xy/pow(2.0,3.0) + vec2(0.3,0.0)).rgb);
    vec3 blur3 = bloomExpand(texture2D(colortex4,coord.xy/pow(2.0,4.0) + vec2(0.0,0.3)).rgb);
    vec3 blur4 = bloomExpand(texture2D(colortex4,coord.xy/pow(2.0,5.0) + vec2(0.1,0.3)).rgb);
    vec3 blur5 = bloomExpand(texture2D(colortex4,coord.xy/pow(2.0,6.0) + vec2(0.2,0.3)).rgb);
    vec3 blur6 = bloomExpand(texture2D(colortex4,coord.xy/pow(2.0,7.0) + vec2(0.3,0.3)).rgb);
    vec3 blur7 = bloomExpand(texture2D(colortex4,coord.xy/pow(2.0,8.0) + vec2(0.4,0.3)).rgb);
	
    vec3 blur = (blur1 + blur2 + blur3 + blur4 + blur5 + blur6 + blur7)*bloomIntensity;

    returnCol += blur/7.0;
}

#include "/lib/util/depth.glsl"
#include "/lib/util/dither.glsl"

void main() {
    decodeBuffer();
    returnCol   = texture2D(colortex0, coord).rgb;
    depth       = texture2D(depthtex0, coord).x;
    depth      *= 1.0+mask.hand*0.5;

#ifdef setBloom
    bloom();
#endif

    /*DRAWBUFFERS:0*/
    gl_FragData[0]  = toVec4(returnCol);
}