#version 130

in vec4 color;

void main() {
    /* DRAWBUFFERS:03 */
    gl_FragData[0] = color;
    gl_FragData[1] = vec4(1.0, 0.0, 0.0, 1.0);
}