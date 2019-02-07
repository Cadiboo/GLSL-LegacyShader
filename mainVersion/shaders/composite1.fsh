#version 130
#include "lib/global.glsl"

in vec2 texcoord;

uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;

uniform sampler2D colortex0;    //COLOR HDR
uniform sampler2D colortex2;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;

#include "lib/util/poisson.glsl"
#include "lib/util/gauss.glsl"
#include "lib/util/fastmath.glsl"

void main() {
    float translucency = texture2D(colortex2, texcoord).b;
    vec4 col = texture2D(colortex0, texcoord);
    float weather = texture2D(colortex4, texcoord).g;
    //col.rgb = vec3(0.0);

    #ifdef setCloudVolume
    #ifdef vCloudHqFilter
        #ifdef TAA
        vec4 vCloud = gauss25(colortex6, 2.0);
        #else
        vec4 vCloud = poisson(colortex6, 4.5, 15);
        #endif
    #else
        #ifdef TAA
        vec4 vCloud = gauss9(colortex6, 2.0);
        #else
        vec4 vCloud = poisson(colortex6, 4.5, 15);
        #endif
    #endif
        vCloud.rgb += weather*0.7;
        col.rgb = mix(col.rgb, vCloud.rgb, pow2(saturateFLOAT(vCloud.a)));

    #endif

    #ifdef volFog
    #ifdef vFogHqFilter
        #ifdef TAA
        vec4 vFog = gauss25(colortex5, 1.66*vFogFilterSize);
        #else
        vec4 vFog = poisson(colortex5, 2.0*vFogFilterSize, 9);
        #endif
    #else
        #ifdef TAA
        vec4 vFog = gauss9(colortex5, 1.66*vFogFilterSize);
        #else
        vec4 vFog = poisson(colortex5, 2.0*vFogFilterSize, 9);
        #endif
    #endif
        col.rgb = mix(col.rgb, vFog.rgb, vFog.a);
    #endif

    /* DRAWBUFFERS:05 */
    gl_FragData[0] = col;
    gl_FragData[1] = vec4(1.0);
}