#version 130


out vec4 color;
out vec2 texcoord;
out vec3 normal;

void main() {
    gl_Position         = ftransform();
    color               = gl_Color;
    normal              = normalize(gl_NormalMatrix*gl_Normal);
    texcoord            = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
}