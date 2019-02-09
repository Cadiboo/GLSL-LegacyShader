#version 130

void main() {
    vec4 viewVertex = gl_ModelViewMatrix*gl_Vertex;
    gl_Position = gl_ProjectionMatrix*viewVertex;
}