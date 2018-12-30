#version 130

out vec4 color;

void main() {
    gl_Position = ftransform();
    color = gl_Color;
}