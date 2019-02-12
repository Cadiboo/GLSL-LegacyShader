const float pi = 3.14159265358979323846;

float pow2(float x) {
    return x*x;
}
float pow3(float x) {
    return pow2(x)*x;
}
float pow4(float x) {
    return pow2(pow2(x));
}
float pow5(float x) {
    return pow4(x)*x;
}
float pow6(float x) {
    return pow2(pow3(x));
}

vec3 linCol(vec3 x) {
    return pow(x, vec3(2.2));
}
vec3 gammaCol(vec3 x) {
    return pow(x, vec3(1.0/2.2));
}

vec4 toVec4(vec3 x) {
    return vec4(x, 1.0);
}
vec3 toVec3(vec4 x) {
    return x.xyz/x.w;
}
float sumVec2(vec2 x) {
    return x.x+x.y;
}

float saturateF(float x) {
    return clamp(x, 0.0, 1.0);
}
vec3 saturateV3(vec3 x) {
    return clamp(x, 0.0, 1.0);
}

float smoothCubic(float x) {
    return pow2(x) * (3.0-2.0*x);
}
/*
float smoothstep(float x, float low, float high) {
    float t = saturateF((x-low)/(high-low));
    return pow2(t)*(3-2*t);
}*/
#define smoothstep(x, low, high) smoothstep(low, high, x)

float linStep(float x, float low, float high) {
    float t = saturateF((x-low)/(high-low));
    return t;
}

float getLuma(vec3 color) {
	return dot(color,vec3(0.22, 0.687, 0.084));
}

float flatten(float x, float alpha) {
    return x*alpha+(1.0-alpha);
}

float coordDist(vec2 x) {
    return max(abs(x.x-0.5), abs(x.y-0.5))*2.0;
}

float getFresnel(vec3 n, vec3 v, int exp, bool invert) {
    float fresnel = 0.0;
    if (invert == false) fresnel = dot(normalize(n), v)*0.5+0.5;
    if (invert == true) fresnel = 1.0-(dot(normalize(n), v)*0.5+0.5);
    if (exp == 1) return fresnel;
    if (exp == 2) return pow2(fresnel);
    if (exp == 3) return pow3(fresnel);
    if (exp == 4) return pow4(fresnel);
    if (exp == 5) return pow5(fresnel);
    if (exp == 6) return pow6(fresnel);
    if (exp == 0 || exp > 6) return 1.0;
}

float bLighten(float x, float blend) {
	return max(x, blend);
}
vec3 bLighten(vec3 x, vec3 blend) {
	return vec3(bLighten(x.r, blend.r), bLighten(x.g, blend.g), bLighten(x.b, blend.b));
}