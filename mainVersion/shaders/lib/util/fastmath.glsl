float pow2(float x) {
    return x*x;
}
float pow3(float x) {
    return x*x*x;
}
float pow4(float x) {
    return pow2(x)*pow2(x);
}
float saturate(float x) {
    return clamp(x, 0.0, 1.0);
}
float smoothstep(float x, float low, float high) {
    float t = clamp((x-low)/(high-low), 0.0, 1.0);
    return t*t*(3-2*t);
}
float saturateFLOAT(float x) {
    return clamp(x, 0.0, 1.0);
}
vec3 saturateRGB(vec3 x) {
    return clamp(x, 0.0, 1.0);
}