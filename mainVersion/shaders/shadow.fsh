#version 130

uniform sampler2D texture;

in vec4 color;
in vec2 texcoord;
in float foliage;
in float translucency;

void main() {
    vec4 shadowcol = texture2D(texture, texcoord)*color;
        shadowcol.rgb  = mix(vec3(1.0), shadowcol.rgb, translucency);
    gl_FragColor = shadowcol;
    gl_FragDepth = gl_FragCoord.z;
}