#version 400

in vec4 color;

void main() {
    gl_FragData[0] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[1] = vec4(vec3(1.0), 1.0);
}