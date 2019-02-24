#version 130
#include "/lib/util/math.glsl"
#include "/lib/global.glsl"

out vec4 col;
out vec2 coord;
out vec2 lmap;
out vec3 nrm;

uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;

vec4 position;

#include "/lib/util/taaJitter.glsl"
#include "/lib/terrain/blocks.glsl"
#include "/lib/terrain/transform.glsl"
#include "/lib/terrain/wind.glsl"

void main() {
    lmap            = (gl_TextureMatrix[1]*gl_MultiTexCoord1).xy;

    idSetup();
    matSetup();

    position        = ftransform();

    #ifdef setWindEffect
		windOcclusion   = linStep(lmap.y, 0.45, 0.8)*0.9+0.1;
	#endif

    unpackPos();
    #ifdef setWindEffect
        applyWind();
    #endif
    repackPos();

    #ifdef temporalAA
        position.xy = taaJitter(position.xy, position.w);
    #endif
    gl_Position     = position;
    col             = gl_Color;
    coord           = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    nrm             = normalize(gl_NormalMatrix*gl_Normal);
}