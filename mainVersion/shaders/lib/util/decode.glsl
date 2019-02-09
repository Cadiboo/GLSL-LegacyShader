struct maskData {
    float terrain;
    float hand;
    float translucency;
} mask;

struct materialData {
    float foliage;
    float emissive;
    float metallic;
    float beacon;
} mat;

float unmap(in float x, float low, float high) {
    if (x < low || x > high) x = low;
    x -= low;
    x /= high-low;
    x /= 0.99;
    x = clamp(x, 0.0, 1.0);
    return x;
}

void decodeBuffer() {
    float maskData  = bData.mask.r;
    float matData   = bData.materials;

    mat.beacon      = unmap(matData, 2.6, 3.5);
    
    mask.terrain    = float(maskData > 0.5 || mat.beacon>0.5);
    mask.hand       = float(maskData > 1.5 && maskData < 2.5);
    mask.translucency = float(maskData > 2.5 && maskData < 3.5);

    mat.foliage     = unmap(matData, 0.0, 0.9);
    mat.emissive    = unmap(matData, 1.5, 2.5);
    mat.metallic    = smoothstep(unmap(matData, 1.0, 1.4), 0.01, 0.09);

}