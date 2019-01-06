
const float gauss25w[25] = float[25] (
  0.0038, 0.0150, 0.0238, 0.0150, 0.0038,
  0.0150, 0.0599, 0.0949, 0.0599, 0.0150,
  0.0238, 0.0949, 0.1503, 0.0949, 0.0238,
  0.0150, 0.0599, 0.0949, 0.0599, 0.0150,
  0.0038, 0.0150, 0.0238, 0.0150, 0.0038
);

const float gauss25w2[25] = float[25] (
  0.01, 0.02, 0.04, 0.02, 0.01,
  0.02, 0.04, 0.08, 0.04, 0.02,
  0.04, 0.08, 0.16, 0.08, 0.04,
  0.02, 0.04, 0.08, 0.04, 0.02,
  0.01, 0.02, 0.04, 0.02, 0.01
);

const vec2 gauss25o[25] = vec2[25] (
    vec2(2.0, 2.0), vec2(1.0, 2.0), vec2(0.0, 2.0), vec2(-1.0, 2.0), vec2(-2.0, 2.0),
    vec2(2.0, 1.0), vec2(1.0, 1.0), vec2(0.0, 1.0), vec2(-1.0, 1.0), vec2(-2.0, 1.0),
    vec2(2.0, 0.0), vec2(1.0, 0.0), vec2(0.0, 0.0), vec2(-1.0, 0.0), vec2(-2.0, 0.0),
    vec2(2.0, -1.0), vec2(1.0, -1.0), vec2(0.0, -1.0), vec2(-1.0, -1.0), vec2(-2.0, -1.0),
    vec2(2.0, -2.0), vec2(1.0, -2.0), vec2(0.0, -2.0), vec2(-1.0, -2.0), vec2(-2.0, -2.0)
);

const float gauss9w[9] = float[9] (
    0.0779, 0.1233, 0.0779,
    0.1233, 0.1954, 0.1223,
    0.0779, 0.1233, 0.0779
);

const vec2 gauss9o[9] = vec2[9] (
    vec2(1.0, 1.0), vec2(0.0, 1.0), vec2(-1.0, 1.0),
    vec2(1.0, 0.0), vec2(0.0, 0.0), vec2(-1.0, 0.0),
    vec2(1.0, -1.0), vec2(0.0, -1.0), vec2(-1.0, -1.0)
);

vec4 gauss25(sampler2D tex, float sigma) {
    vec2 pixelRad = sigma/vec2(viewWidth, viewHeight);
    vec2 coord = texcoord;
    vec4 col = vec4(0.0);

    for (int i = 0; i<25; i++) {
        vec2 bcoord = coord + gauss25o[i]*pixelRad;
        col += texture2D(tex, bcoord)*gauss25w[i];
    }
    return col;
}

vec4 gauss25flat(sampler2D tex, float sigma) {
    vec2 pixelRad = sigma/vec2(viewWidth, viewHeight);
    vec2 coord = texcoord;
    vec4 col = vec4(0.0);

    for (int i = 0; i<25; i++) {
        vec2 bcoord = coord + gauss25o[i]*pixelRad;
        col += texture2D(tex, bcoord);
    }
    col /= 25;
    return col;
}

vec4 gauss9(sampler2D tex, float sigma) {
    vec2 pixelRad = sigma/vec2(viewWidth, viewHeight);
    vec2 coord = texcoord;
    vec4 col = vec4(0.0);

    for (int i = 0; i<9; i++) {
        vec2 bcoord = coord + gauss9o[i]*pixelRad;
        col += texture2D(tex, bcoord)*gauss9w[i];
    }
    return col;
}

vec4 gauss9flat(sampler2D tex, float sigma) {
    vec2 pixelRad = sigma/vec2(viewWidth, viewHeight);
    vec2 coord = texcoord;
    vec4 col = vec4(0.0);

    for (int i = 0; i<9; i++) {
        vec2 bcoord = coord + gauss9o[i]*pixelRad;
        col += texture2D(tex, bcoord);
    }
    col /= 9;
    return col;
}
