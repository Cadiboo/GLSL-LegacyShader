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

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

uniform int fogMode;

void main() {
    gl_FragData[0] = texture2D(texture, texcoord.st)*color;
    gl_FragData[1] = vec4(vec3(gl_FragCoord.z), 1.0);
    //gl_FragData[3] = vec4(lmcoord.xy, 0.0, 1.0);
    gl_FragData[4] = vec4(0.0, 0.0, 0.0, 1.0);

    if (fogMode == GL_EXP) {
		gl_FragData[0].rgb = mix(gl_FragData[0].rgb, gl_Fog.color.rgb, 1.0 - clamp(exp(-gl_Fog.density * gl_FogFragCoord), 0.0, 1.0));
	} else if (fogMode == GL_LINEAR) {
		gl_FragData[0].rgb = mix(gl_FragData[0].rgb, gl_Fog.color.rgb, clamp((gl_FogFragCoord - gl_Fog.start) * gl_Fog.scale, 0.0, 1.0));
	}
}