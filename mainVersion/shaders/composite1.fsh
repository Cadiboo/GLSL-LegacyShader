#version 130
#include "/lib/util/math.glsl"
#include "/lib/global.glsl"

in vec2 coord;

uniform sampler2D colortex0;
uniform sampler2D colortex4;

uniform float viewWidth;
uniform float viewHeight;

#include "/lib/util/gauss.glsl"

vec3 returnCol;
vec4 cloud;

void main() {
    returnCol   = texture2D(colortex0, coord).rgb;
    #ifdef setCloudVolume
        #ifdef temporalAA
        cloud       = gauss9(colortex4, 2.0);
        #else
        cloud       = gauss9(colortex4, 2.5);
        #endif
        cloud.a     = pow2(cloud.a);
    #endif

    returnCol   = mix(returnCol, cloud.rgb, saturateF(cloud.a));

    /*DRAWBUFFERS:0*/
    gl_FragData[0] = vec4(returnCol, 1.0);
}