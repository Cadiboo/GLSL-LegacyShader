#define setBokehSize 1.0    //[0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5]

vec2 angleToCoord(float angle){
	return vec2(cos(angle*pi/180),sin(angle*pi/180));
}

void bokehProcedural(sampler2D tex, float delta) {
    const float bokehScale = 0.05*setBokehSize;
    vec3 bokehCol = vec3(0.0);
    vec2 bokehCoord = coord;
    vec2 aspectFix  = vec2(1.0, aspectRatio);
    float noise = ditherStatic*0.2+0.8;
    float CoC = (depth)-(centerDepthSmooth);
        CoC *= bokehScale;
        CoC *= pow4(1.0-smoothstep(depthLin(centerDepthSmooth), 0.02, 0.5));
        //CoC = 0.03;
    
    const int bokehLoops = 5;
    const int diaphragmBlades = 5;
    const float diaphragmRounding = 0.6;
    const int diaphragmRotate = 30;
    const int diaphragmSamples = 5;
    int diaphragmLoop = diaphragmSamples;
    float rotateStep = 90.0;
    float offsetStep = 1.0/bokehLoops;

    vec2 bokehShape;

        for (int i = 0; i<bokehLoops; i++) {            
            for (int b = 0; b < diaphragmLoop; b++) {
                float sine = abs(sin((rotateStep-90.0+diaphragmRotate)*diaphragmBlades*0.5*pi/180));
                float cosine = mix(pow(cos(pi/diaphragmBlades), diaphragmRounding), 1.0, pow(sine, 5.0));
                bokehShape = angleToCoord(rotateStep)*offsetStep*cosine;
                bokehShape *= CoC*aspectFix;
                
                vec3 temp = texture2DLod(tex, bokehCoord + bokehShape, 0).rgb;
                float luma = getLuma(temp);
                bokehCol += temp*(1.0+smoothstep(luma, 80.0, 120.0));
                rotateStep += 360/diaphragmLoop;
            }
            offsetStep += (1.0/bokehLoops);
            diaphragmLoop += diaphragmSamples;
        }
        bokehCol /= bokehLoops*(diaphragmSamples*0.6+diaphragmLoop*0.4);
    //bokehCol  = vec3(depth);
    returnCol = bokehCol;
}