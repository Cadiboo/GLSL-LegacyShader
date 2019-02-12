#version 130
#include "/lib/util/math.glsl"
#include "/lib/global.glsl"

#ifdef setBloom
const bool colortex0MipmapEnabled = true;
#endif

float bloomThreshold    = 30.0;

uniform sampler2D colortex0;    //scene color
uniform sampler2D colortex3;    //scene material masks
uniform sampler2D depthtex1;

uniform int frameCounter;

uniform float viewHeight;
uniform float viewWidth;
uniform float aspectRatio;
uniform float frameTime;
uniform float rainStrength;
uniform float wetness;

in vec2 coord;

float pxWidth       = 1.0/viewWidth;

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
    vec4 maskBuffer = texture2D(colortex3, coord);
    float maskData  = maskBuffer.r;
    
    mask.terrain    = float(maskData > 0.5);
    mask.hand       = float(maskData > 1.5 && maskData < 2.5);
    mask.translucency = float(maskData > 2.5 && maskData < 3.5);
}

vec3 bloomBuffers(float mip, vec2 offset){
	vec3 bufferTex 	= vec3(0.0);
	vec3 temp 		= vec3(0.0);
	float scale 	= pow(2.0, mip);
	vec2 bCoord 	= (coord-offset)*scale;
	float padding 	= 0.005*scale;

	if (bCoord.x>-padding && bCoord.y>-padding && bCoord.x<1.0+padding && bCoord.y<1.0+padding) {
		for (int i=0;  i<7; i++) {
			for (int j=0; j<7; j++) {
				float wg 	= clamp(1.0-length(vec2(i-3,j-3))*0.28, 0.0, 1.0);
					wg 		= pow(wg, 2.0)*20;
				vec2 tCoord = (coord-offset+vec2(i-3, j-3)*pxWidth*vec2(1.0, aspectRatio))*scale;
				if (wg>0) {
					temp 			= ((texture2D(colortex0, tCoord).rgb)-(bloomThreshold*(1.0/mip)))*wg;
					vec3 colortex 	= (texture2D(colortex0, tCoord).rgb);
						colortex 	= mix(colortex, vec3(getLuma(colortex)), 0.6f);
						bufferTex  += max(temp, 0.0);
				}
			}
		}
	bufferTex /=49;
	}
return pow(bufferTex/32.0, vec3(0.2));
}

vec3 returnCol;

#include "/lib/util/dither.glsl"

void main() {
	bloomThreshold *= 1.0-wetness*0.8;

    returnCol = texture2DLod(colortex0, coord, 0).rgb;

    depth   = texture2D(depthtex1, coord).r;

    decodeBuffer();

    vec3 blur = vec3(0.0);

#ifdef setBloom
	blur += bloomBuffers(2,vec2(0,0));
	blur += bloomBuffers(3,vec2(0.3,0));
	blur += bloomBuffers(4,vec2(0,0.3));
	blur += bloomBuffers(5,vec2(0.1,0.3));
	blur += bloomBuffers(6,vec2(0.2,0.3));
	blur += bloomBuffers(7,vec2(0.3,0.3));
	blur += bloomBuffers(8,vec2(0.4,0.3));
	blur += bloomBuffers(9,vec2(0.5,0.3));
#endif

    /*DRAWBUFFERS:04*/
    gl_FragData[0]  = toVec4(returnCol);
    gl_FragData[1]  = toVec4(blur);
}