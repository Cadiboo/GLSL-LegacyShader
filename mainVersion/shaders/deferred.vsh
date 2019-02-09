#version 130
#include "Lib/util/math.glsl"

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;

out vec2 coord;

out vec3 sunVector;
out vec3 moonVector;
out vec3 lightVector;
out vec3 upVector;

#include "lib/util/time.glsl"
#include "lib/nVars.glsl"

void main() {
    daytime();
    nature();

    gl_Position     = ftransform();
    coord           = gl_MultiTexCoord0.xy;
    sunVector       = normalize(sunPosition);
    moonVector      = normalize(moonPosition);
    lightVector     = normalize(shadowLightPosition);
    upVector        = normalize(upPosition);
}