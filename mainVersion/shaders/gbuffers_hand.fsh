#version 130

in vec4 color;
in vec2 texcoord;
in vec3 normal;
in vec2 lmcoord;

uniform sampler2D texture;

void main() {
    /* DRAWBUFFERS:01234 */
    gl_FragData[0] = texture2D(texture, texcoord)*color;
    gl_FragData[1] = vec4(normal*0.5+0.5, 1.0);
    gl_FragData[2] = vec4(lmcoord, 0.0, 1.0);
    gl_FragData[3] = vec4(1.0, 1.0, 0.0, 1.0);
    gl_FragData[4] = vec4(0.0, 0.0, 0.0, 1.0);
}