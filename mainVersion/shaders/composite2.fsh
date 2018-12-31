#version 130
#include "lib/global.glsl"

const bool colortex7Clear = false;

uniform sampler2D colortex0;
uniform sampler2D colortex7;
uniform sampler2D depthtex1;
uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTime;

in vec2 texcoord;

const bool colortex0MipmapEnabled = true;
const bool colortex7MipmapEnabled = true;

const float bloomThreshold = bloomThresh;

float pi = 3.1415927;
float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;

float depth;

float getLuma(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

vec3 bloomBuffers(float mip, vec2 offset){
	vec3 bufferTex 	= vec3(0.0);
	vec3 temp 		= vec3(0.0);
	float scale 	= pow(2.0, mip);
	vec2 coord 		= (texcoord-offset)*scale;
	float padding 	= 0.005*scale;

	if (coord.x>-padding && coord.y>-padding && coord.x<1.0+padding && coord.y<1.0+padding) {
		for (int i=0;  i<7; i++) {
			for (int j=0; j<7; j++) {
				float wg 	= clamp(1.0-length(vec2(i-3,j-3))*0.28, 0.0, 1.0);
					wg 		= pow(wg, 2.0)*20;
				vec2 bcoord = (texcoord-offset+vec2(i-3, j-3)*pw*vec2(1.0, aspectRatio))*scale;
				if (wg>0) {
					temp 			= ((texture2D(colortex0, bcoord).rgb)-(bloomThreshold*(1.0/mip)))*wg;
					vec3 colortex 	= (texture2D(colortex0, bcoord).rgb);
						colortex 	= mix(colortex, vec3(getLuma(colortex)), 0.6f);
						bufferTex  += max(temp, 0.0);
				}
			}
		}
	bufferTex /=49;
	}
return pow(bufferTex/32.0, vec3(0.2));
}

#include "lib/post/temporal.glsl"

void main() {

	depth = texture2D(depthtex1, texcoord).r;

vec3 blur = vec3(0.0f);
#ifdef cBloom
	blur += bloomBuffers(2,vec2(0,0));
	blur += bloomBuffers(3,vec2(0.3,0));
	blur += bloomBuffers(4,vec2(0,0.3));
	blur += bloomBuffers(5,vec2(0.1,0.3));
	blur += bloomBuffers(6,vec2(0.2,0.3));
	blur += bloomBuffers(7,vec2(0.3,0.3));
	blur += bloomBuffers(8,vec2(0.4,0.3));
	blur += bloomBuffers(9,vec2(0.5,0.3));
#endif

	float exposure = texture2DLod(colortex7,vec2(0.5),log2(viewWidth*0.4)).a;
	float exposureTarget = length(texture2DLod(colortex0,vec2(0.5),log2(viewWidth*0.4)).rgb);
	float resultExposure = mix(exposure, exposureTarget, 0.025*autoExposureSmoothing*(frameTime/0.033));

	vec3 currentCol = texture2D(colortex0, texcoord).rgb;

	#ifdef TAA
	vec2 taaProj = taaReprojection(texcoord, depth);
	vec2 viewport = 1.0/vec2(viewWidth, viewHeight);

	vec3 temporalCol = texture2D(colortex7, taaProj).rgb;

	//TAA based on code from Capt Tatsu's BSL Shaders
	vec3 coltl = texture2DLod(colortex0,texcoord+vec2(-1.0,-1.0)*viewport,0).rgb;
	vec3 coltm = texture2DLod(colortex0,texcoord+vec2( 0.0,-1.0)*viewport,0).rgb;
	vec3 coltr = texture2DLod(colortex0,texcoord+vec2( 1.0,-1.0)*viewport,0).rgb;
	vec3 colml = texture2DLod(colortex0,texcoord+vec2(-1.0, 0.0)*viewport,0).rgb;
	vec3 colmr = texture2DLod(colortex0,texcoord+vec2( 1.0, 0.0)*viewport,0).rgb;
	vec3 colbl = texture2DLod(colortex0,texcoord+vec2(-1.0, 1.0)*viewport,0).rgb;
	vec3 colbm = texture2DLod(colortex0,texcoord+vec2( 0.0, 1.0)*viewport,0).rgb;
	vec3 colbr = texture2DLod(colortex0,texcoord+vec2( 1.0, 1.0)*viewport,0).rgb;
	
	vec3 minclr = min(currentCol,min(min(min(coltl,coltm),min(coltr,colml)),min(min(colmr,colbl),min(colbm,colbr))));
	vec3 maxclr = max(currentCol,max(max(max(coltl,coltm),max(coltr,colml)),max(max(colmr,colbl),max(colbm,colbr))));
	
	temporalCol = clamp(temporalCol,minclr,maxclr);

	float taaMix = float(taaProj.x>0.0 && taaProj.x<1.0 && taaProj.y>0.0 && taaProj.y<1.0);

	vec2 vel = (texcoord-taaProj)/viewport;
	taaMix *= clamp(1.0-sqrt(length(vel))/1.999, 0.0, 1.0)*0.3+0.6;

	vec3 taa = mix(currentCol, temporalCol, taaMix);
	#else
	vec3 taa = currentCol;
	#endif
	
	/* DRAWBUFFERS:057 */
	gl_FragData[0] = vec4(taa, 1.0);
	gl_FragData[1] = vec4(blur, 1.0);
	gl_FragData[2] = vec4(taa, resultExposure);
}
