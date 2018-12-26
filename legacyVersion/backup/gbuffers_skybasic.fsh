#version 400

in vec4 color;

void main() {
    gl_FragData[0] = vec4(vec3(0.0), 1.0);
	gl_FragData[1] = vec4(vec3(0.0), 1.0);
    gl_FragData[4] = vec4(0.0, 0.0, 1.0, 1.0);
	gl_FragData[0].rgb = mix(gl_FragData[0].rgb, (vec3(0.0) * 1.0), 1.0 - clamp(exp(-gl_Fog.density * gl_FogFragCoord), 0.0, 1.0));
    gl_FragData[4].rgb = mix(gl_FragData[4].rgb, (vec3(0.0, 0.0, 1.0) * 1.0), 1.0 - clamp(exp(-gl_Fog.density * gl_FogFragCoord), 0.0, 1.0));
}