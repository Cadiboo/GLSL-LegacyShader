#version 400

out vec4 color;

void main() {
	gl_Position = ftransform();	
	color = gl_Color;
	gl_FogFragCoord = gl_Position.z;
}