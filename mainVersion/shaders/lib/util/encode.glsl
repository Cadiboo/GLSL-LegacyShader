float remap(in float x, float low, float high) {
    x = clamp(x, 0.0, 1.0);
    x *= high-low;
    x *= 0.99;
    if (x > 0.0) x += low;
    return x;
}