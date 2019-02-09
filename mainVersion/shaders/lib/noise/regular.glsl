float noise2D(in vec2 coord) {
    coord      /= noiseTextureResolution;
    return texture2D(noisetex, coord).x;
}