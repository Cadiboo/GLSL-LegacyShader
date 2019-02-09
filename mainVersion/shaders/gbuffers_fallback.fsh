#include "/lib/util/math.glsl"

in vec4 col;
in vec2 coord;
in vec2 lmap;
in vec3 nrm;

uniform sampler2D texture;

void main() {
    /*DRAWBUFFERS:0123*/
    gl_FragData[0] = texture2D(texture, coord)*col;
    gl_FragData[1] = toVec4(nrm*0.5+0.5);
    gl_FragData[2] = vec4(lmap, 0.0, 1.0);
    gl_FragData[3] = vec4(1.0, 0.0, 0.0, 1.0);
}