float heightFade(vec3 wPos, float limit, in float smoothing) {
    float density   = smoothstep(wPos.y, limit-smoothing/2, limit+smoothing/2);
    return density;
}