#version 400

out vec4 color;

float distance;

void main() {
    vec4 viewVertex = gl_ModelViewMatrix*gl_Vertex;
    distance = length(viewVertex);

    gl_Position = gl_ProjectionMatrix*viewVertex;
    color = gl_Color;
}