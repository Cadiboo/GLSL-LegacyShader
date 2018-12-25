#version 400

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D composite;

uniform float far;
uniform float near;
uniform float viewWidth;
uniform float viewHeight;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

in vec2 texcoord;

in vec3 sunVector;
in vec3 moonVector;
in vec3 lightVector;
in vec3 upVector;

float depth;

struct imageColor{
    vec3 pre;
    vec3 post;
} col;

struct masks{
    float terrain;
    float water;
    float hand;
    float solid;
} mask;

float bayer2(vec2 a){
    a = floor(a);
    return fract( dot(a, vec2(.5, a.y * .75)) );
}
#define bayer4(a)   (bayer2( .5*(a))*.25+bayer2(a))
#define bayer8(a)   (bayer4( .5*(a))*.25+bayer2(a))
#define bayer16(a)  (bayer8( .5*(a))*.25+bayer2(a))
#define bayer32(a)  (bayer16(.5*(a))*.25+bayer2(a))
#define bayer64(a)  (bayer32(.5*(a))*.25+bayer2(a))
#define bayer128(a) (bayer64(.5*(a))*.25+bayer2(a))
#define bayer256(a) (bayer128(.5*(a))*.25+bayer2(a))

void motionblur() {
    const int samples = 6;
    const float blurStrength = 0.06;

    float d     = depth;
        d       = mix(d, pow(d, 0.01), mask.hand);
    float dither = bayer64(gl_FragCoord.xy);
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
        blurSize  = min(blurSize, 0.033);

    vec2 vel    = (currPos-prevPos).xy*2.0;
        vel    *= blurSize;
    const float maxVel = 0.046;
        vel     = clamp(vel, -maxVel, maxVel)*dither;

    vec2 coord  = texcoord;
    vec3 colBlur = vec3(0.0);

    int fix = 0;

    for (int i = 0; i<samples; i++, coord +=vel) {
        if (coord.x>1.0 || coord.y>1.0 || coord.x<0.0 || coord.y<0.0) {
            break;
        }
        vec2 coordB = clamp(coord, viewport, 1.0-viewport);
        colBlur += texture2D(gcolor, coordB).rgb;
        ++fix;
    }
    colBlur /= fix;
    col.pre.rgb = colBlur;
}

void main() {
    depth = texture2D(gdepth, texcoord).r;
    col.pre = texture2D(gcolor, texcoord).rgb;
    motionblur();
    //col.pre = texture2D(gnormal, texcoord).rgb;


    col.post = col.pre;
    gl_FragColor = vec4(col.post, 1.0);
}