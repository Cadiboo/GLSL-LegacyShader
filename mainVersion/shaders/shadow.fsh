#version 130
#include "/lib/global.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/colorConversion.glsl"

uniform sampler2D texture;
uniform sampler2D noisetex;

uniform float frameTimeCounter;

in vec4 col;
in vec2 coord;

in float water;
in float translucency;

vec3 returnCol;
float returnAlpha;

uniform int blockEntityId;

void main() {
    vec4 fragSample     = texture2D(texture, coord);
        returnCol       = toLinear(fragSample.rgb);

        returnCol       = mix(vec3(1.0), returnCol, max(translucency, water));
        returnAlpha     = fragSample.a;

    if (blockEntityId == 138) discard;

    gl_FragColor = vec4(returnCol, returnAlpha);
    gl_FragDepth = gl_FragCoord.z;
}