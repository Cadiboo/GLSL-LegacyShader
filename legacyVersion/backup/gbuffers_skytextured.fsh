#version 400

in vec4 color;
in vec4 texcoord;
in vec4 lmcoord;
in vec3 normal;

in float timeSunrise;
in float timeNoon;
in float timeSunset;
in float timeNight;
in float timeMoon;
in float timeLightTransition;
in float timeSun;

uniform sampler2D texture;

void main() {
    gl_FragData[0] = vec4((texture2D(texture, texcoord.st)*color).rgb, 1.0);
    gl_FragData[1] = vec4(vec3(0.0), 1.0);
    gl_FragData[4] = vec4(0.0, 0.0, 1.0, 1.0);
}