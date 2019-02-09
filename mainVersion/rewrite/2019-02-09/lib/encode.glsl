in float foliage;
in float emissive;
in float metal;

vec3 encodedBuffer = vec3(0.0);

void encodeMatBuffer() {
    encodedBuffer = vec3(foliage, emissive, metal);
}