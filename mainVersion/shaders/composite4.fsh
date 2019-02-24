#version 130
#include "/lib/util/math.glsl"
#include "/lib/global.glsl"

const int RGBA16F = 0;

const int colortex7Format   = RGBA16F;

const bool colortex7Clear   = false;

const bool colortex0MipmapEnabled = true;
const bool colortex7MipmapEnabled = true;

uniform sampler2D colortex0;    //scene color
uniform sampler2D colortex2;
uniform sampler2D colortex7;    //temporals
uniform sampler2D depthtex1;

uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTime;

in vec2 coord;

float pxWidth       = 1.0/viewWidth;
float pxHeight      = 1.0/viewHeight;

vec3 returnCol;
vec3 returnTemporal;

#include "/lib/post/taa.glsl"

float depth;

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
    vec4 maskBuffer = texture2D(colortex2, coord);
    float maskData  = maskBuffer.b;
    
    mask.terrain    = float(maskData > 0.5);
    mask.hand       = float(maskData > 1.5 && maskData < 2.5);
    mask.translucency = float(maskData > 2.5 && maskData < 3.5);
}

float getImageLuma(sampler2D tex) {
    vec3 sample1 = textureLod(colortex0, vec2(0.5), ceil(log2(max(viewHeight, viewWidth)))).rgb;
    vec3 sample2 = textureLod(colortex0, vec2(0.5), ceil(log2(max(viewHeight, viewWidth)))/1.5).rgb;

    return getLuma((sample1+sample2*0.1));
}

void main() {
    vec3 returnCol  = texture2DLod(colortex0, coord, 0).rgb;
    float depth     = texture2DLod(depthtex1, coord, 0).x;
    depth           = mix(depth, pow(depth, 0.01), mask.hand);

    float expCurrent    = texture2DLod(colortex7, coord, 0).a;
    float expTarget     = getImageLuma(colortex0);
        expTarget       = clamp(expTarget, expMinimum, expMaximum);
    float expResult     = mix(expCurrent, expTarget, 0.025*(frameTime/0.033));

    vec2 taaCoord       = taaReprojection(coord, depth);
    vec2 viewport       = 1.0/vec2(viewWidth, viewHeight);

    vec3 taaCol         = texture2DLod(colortex7, taaCoord, 0).rgb;

    vec3 coltl      = texture2DLod(colortex0,coord+vec2(-1.0,-1.0)*viewport,0).rgb;
	vec3 coltm      = texture2DLod(colortex0,coord+vec2( 0.0,-1.0)*viewport,0).rgb;
	vec3 coltr      = texture2DLod(colortex0,coord+vec2( 1.0,-1.0)*viewport,0).rgb;
	vec3 colml      = texture2DLod(colortex0,coord+vec2(-1.0, 0.0)*viewport,0).rgb;
	vec3 colmr      = texture2DLod(colortex0,coord+vec2( 1.0, 0.0)*viewport,0).rgb;
	vec3 colbl      = texture2DLod(colortex0,coord+vec2(-1.0, 1.0)*viewport,0).rgb;
	vec3 colbm      = texture2DLod(colortex0,coord+vec2( 0.0, 1.0)*viewport,0).rgb;
	vec3 colbr      = texture2DLod(colortex0,coord+vec2( 1.0, 1.0)*viewport,0).rgb;

	vec3 minCol = min(returnCol,min(min(min(coltl,coltm),min(coltr,colml)),min(min(colmr,colbl),min(colbm,colbr))));
	vec3 maxCol = max(returnCol,max(max(max(coltl,coltm),max(coltr,colml)),max(max(colmr,colbl),max(colbm,colbr))));

        taaCol      = clamp(taaCol, minCol, maxCol);

    float taaMix    = float(taaCoord.x>0.0 && taaCoord.x<1.0 && taaCoord.y>0.0 && taaCoord.y<1.0);

    vec2 velocity   = (coord-taaCoord)/viewport;
        taaMix     *= clamp(1.0-sqrt(length(velocity))/1.999, 0.0, 1.0)*0.3+0.6;

    returnTemporal  = mix(returnCol, taaCol, taaMix);

    /*DRAWBUFFERS:07*/
    gl_FragData[0]  = toVec4(returnTemporal);
    gl_FragData[1]  = vec4(returnTemporal, expResult);
}