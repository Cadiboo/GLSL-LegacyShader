#define mBlurSamples 9  //[3 6 9 12 15 18 21]
#define mBlurInt 1.0    //[0.5 0.75 1.0 1.25 1.5 1.75 2.0]

void motionblur() {
    const int samples = mBlurSamples;
    const float blurStrength = 0.02*mBlurInt;

    float d     = depth;
        d       = mix(d, pow(d, 0.01), mask.hand);
    float dither = ditherStatic;
    vec2 viewport = 2.0/vec2(viewWidth, viewHeight);

    vec4 currPos = vec4(texcoord.x*2.0-1.0, texcoord.y*2.0-1.0, 2.0*d-1.0, 1.0);

    vec4 frag   = gbufferProjectionInverse*currPos;
        frag    = gbufferModelViewInverse*frag;
        frag   /= frag.w;
        frag.xyz += cameraPosition;

    vec4 prevPos = frag;
        prevPos.xyz -= previousCameraPosition;
        prevPos = gbufferPreviousModelView*prevPos;
        prevPos = gbufferPreviousProjection*prevPos;
        prevPos /= prevPos.w;

    float blurSize = blurStrength;
        blurSize /= frameTime*30;
        blurSize  = min(blurSize, 0.033);

    vec2 vel    = (currPos-prevPos).xy;
        vel    *= blurSize;
    const float maxVel = 0.046;
        vel     = clamp(vel, -maxVel, maxVel);
        vel     = vel - (vel/2.0);

    vec2 coord  = texcoord;
    vec3 colBlur = vec3(0.0);
    coord += vel*dither;

    int fix = 0;

    for (int i = 0; i<samples; i++, coord +=vel) {
        if (coord.x>=1.0 || coord.y>=1.0 || coord.x<=0.0 || coord.y<=0.0) {
            colBlur += texture2D(colortex0, texcoord).rgb;
            fix += 1;
            break;
        } else {
            vec2 coordB = clamp(coord, viewport, 1.0-viewport);
            colBlur += texture2D(colortex0, coordB).rgb;
            ++fix;
        }
    }
    colBlur /= fix;
    col.HDR.rgb = colBlur;
}