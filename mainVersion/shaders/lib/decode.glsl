struct masks {
    float terrain;
    float hand;
    float solid;
    float translucency;
} mask;

struct materialMask {
    float foliage;
    float emissive;
    float cloud;
} mat;

void decodeMask() {
    mask.terrain        = cbuffer.mask.r;
    mask.hand           = cbuffer.mask.g;
    mask.translucency   = cbuffer.mask.b;
    mask.solid          = clamp(cbuffer.mask.r+cbuffer.mask.g, 0.0, 1.0);

    vec3 matBuffer      = texture2D(colortex4, texcoord).rgb;
    mat.foliage         = matBuffer.r;
    mat.emissive        = matBuffer.g;
    mat.cloud           = matBuffer.b;
}