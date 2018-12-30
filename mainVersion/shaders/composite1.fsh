#version 130
#include "lib/global.glsl"

in vec2 texcoord;

uniform float viewHeight;
uniform float aspectRatio;

uniform sampler2D colortex0;    //COLOR HDR
uniform sampler2D colortex2;
uniform sampler2D colortex5;

#include "lib/util/poisson.glsl"
#include "lib/util/fastmath.glsl"

vec4 blurFilter(sampler2D tex, float size, int samples) {
    vec2 coord = texcoord;
    float blurRadius = size * 0.01 * (1080/viewHeight);
    vec4 col = vec4(0.0);

    for (int i = 0; i<samples; i++) {
        col += texture2D(tex, coord + poissonOffsets[i*(60/samples)]*vec2(blurRadius/aspectRatio, blurRadius));
    }
    col /= samples;
    return col;
}
vec4 blurFilterFog(sampler2D tex) {
    #ifdef TAA
    return blurFilter(tex, 0.372, 3);
    #else
    return blurFilter(tex, 0.4787*vFogFilterSize, vFogFilterSteps);
    #endif
}

void main() {
    float translucency = texture2D(colortex2, texcoord).b;
    vec4 col = texture2D(colortex0, texcoord);

    #ifdef volFog
    vec4 vFog = blurFilterFog(colortex5);
        col.rgb = mix(col.rgb, vFog.rgb, vFog.a);
    #endif

    /* DRAWBUFFERS:05 */
    gl_FragData[0] = col;
    gl_FragData[1] = vec4(1.0);
}