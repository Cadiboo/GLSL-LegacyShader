#version 130
#include "lib/util/fastmath.glsl"

uniform int worldTime;

uniform float sunAngle;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;

out vec2 texcoord;

out vec3 sunVector;
out vec3 moonVector;
out vec3 lightVector;
out vec3 upVector;

#include "lib/util/daytime.glsl"

void main() {
    daytime();

    gl_Position     = ftransform();
    texcoord        = gl_MultiTexCoord0.st;
    sunVector       = normalize(sunPosition);
    moonVector      = normalize(moonPosition);
    lightVector     = normalize(shadowLightPosition);
    upVector        = normalize(upPosition);
}