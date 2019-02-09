vec4 screenSpacePos(float depth) {
    vec4 posNDC = vec4(coord.x*2.0-1.0, coord.y*2.0-1.0, 2.0*depth-1.0, 1.0);
    vec4 posCamSpace = gbufferProjectionInverse*posNDC;
    return posCamSpace/posCamSpace.w;
}
vec4 screenSpacePos(float depth, vec2 coord) {
    vec4 posNDC = vec4(coord.x*2.0-1.0, coord.y*2.0-1.0, 2.0*depth-1.0, 1.0);
    vec4 posCamSpace = gbufferProjectionInverse*posNDC;
    return posCamSpace/posCamSpace.w;
}

vec4 worldSpacePos(float depth) {
    vec4 posCamSpace = screenSpacePos(depth);
    vec4 posWorldSpace = gbufferModelViewInverse*posCamSpace;
    posWorldSpace.xyz += cameraPosition.xyz;
    return posWorldSpace;
}
vec4 worldSpacePos(float depth, vec2 coord) {
    vec4 posCamSpace = screenSpacePos(depth, coord);
    vec4 posWorldSpace = gbufferModelViewInverse*posCamSpace;
    posWorldSpace.xyz += cameraPosition.xyz;
    return posWorldSpace;
}