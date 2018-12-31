#version 130


in vec4 color;
in vec2 texcoord;
in vec3 normal;

uniform sampler2D texture;

void main() {
    /* DRAWBUFFERS:013 */
    gl_FragData[0] = texture2D(texture, texcoord)*color;
    gl_FragData[1] = vec4(normal*0.5+0.5, 1.0);
    gl_FragData[2] = vec4(1.0, 0.0, 0.0, 1.0);
}