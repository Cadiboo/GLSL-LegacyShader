uniform vec3 cameraPosition;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowModelView;

float pi = 3.14159265359;

vec2 windDirA = vec2(1.0f, 0.7f);
vec2 windDirB = vec2(1.0f, -0.1f);

vec2 windDir(float alpha) {
    return -mix(windDirA, windDirB, alpha);
}

vec3 windDirBlock(float alpha) {
    vec2 temp = -mix(windDirA, windDirB, alpha);
    float y = mix(0.1, -0.5, alpha);
    return vec3(temp.x, y, temp.y);
}

vec2 windRippleDirA = vec2(1.0, 0.9);
vec2 windRippleDirB = vec2(1.0, -0.3);

vec2 windRippleDir(float alpha) {
    return mix(windRippleDirA, windRippleDirB, alpha);
}
vec3 windRippleDirBlock(float alpha) {
    vec2 temp = mix(windRippleDirA, windRippleDirB, alpha);
    float y = mix(0.4, -0.6, alpha);
    return vec3(temp.x, y, temp.y);
}

float windMacroOffsetBase(in vec3 position, in float speed, in float strength, in float rippleMix) {
    position.xz *= windRippleDir(rippleMix);
    float sin1 = sin(frameTimeCounter*pi*speed+position.x+position.z)*0.7+0.2;
    float cos1 = cos(frameTimeCounter*pi*speed*0.654+position.x+position.z)*0.7+.2;
    return (sin1+cos1)*strength;
}
float windMacroOffsetB(in vec3 position, in float speed, in float strength, in float rippleMix) {
    position.xz *= windRippleDir(rippleMix);
    float sin1 = sin(frameTimeCounter*pi*speed+position.x+position.z)*0.68+0.2;
    //float cos1 = cos(frameTimeCounter*pi*speed*0.654+position.x+position.z);
    return (sin1)*strength;
}
float windMicroOffset(in vec3 position, in float speed, in float strength, in float rippleMix) {
    position.xz *= windRippleDir(rippleMix);
    float sin1 = sin(frameTimeCounter*pi*speed*3.5+position.x+position.z)*0.5+0.5;
    float sin2 = sin(frameTimeCounter*pi*speed*0.5+position.x+position.z)*0.66+0.34;
        sin2 = max(sin2*1.2-0.2, 0.0f);
    float cos1 = cos(frameTimeCounter*pi*speed*0.7+position.x+position.z)*0.7+0.23;
        cos1 = max(cos1*1.3-0.3, 0.0f);
    return mix(sin2, cos1, sin1)*strength;
}
float windHeavyRipple(in vec3 position, in float speed, in float strength, in float rippleMix) {
    vec3 posTemp = position.xyz;
        posTemp.xz *= windRippleDir(rippleMix/3);
    float sin1 = sin(frameTimeCounter*pi*speed*0.6+(posTemp.x+posTemp.z)*0.2)*0.6+0.6;
        posTemp.xz = position.xz*windRippleDir(-rippleMix);
    float sin2 = sin(frameTimeCounter*pi*speed*0.5+(posTemp.x+posTemp.z)*0.18)*0.6+0.6;
        posTemp.xz = position.xz*windRippleDir(rippleMix/2);
    float cos1 = cos(frameTimeCounter*pi*speed*0.7+(posTemp.x+posTemp.z)*0.16)*0.6+0.6;
    float amplitude = sin1*sin2*cos1;

        posTemp.xz = position.xz*windRippleDir(rippleMix)*2;
    float sina1 = sin(frameTimeCounter*pi*speed*4.8+posTemp.x+posTemp.z)*0.5+0.5;
        posTemp.xz = position.xz*windRippleDir(-rippleMix*1.5);
    float sina2 = sin(frameTimeCounter*pi*speed*3.9+posTemp.x+posTemp.z)*0.66+0.34;
        posTemp.xz = position.xz*windRippleDir(rippleMix/2);
    float cosa1 = cos(frameTimeCounter*pi*speed*2.75+posTemp.x+posTemp.z)*0.62+0.23;
    float ripple = mix(sina2, cosa1, sina1);
    return ripple*amplitude*strength;
}
void windEffect(inout vec4 position, in float speed, in float strength, in float size) {
    position *= size;
    vec2 macroOffsetA = vec2(0.0);
    
        macroOffsetA += vec2(windMacroOffsetBase(
            position.xyz*.3, speed*0.53, 0.96, 0.15
            ))*windDir(0.0);
        macroOffsetA += vec2(windMicroOffset(
            position.xyz*.64, speed*0.42, 0.87, 0.6
            ))*windDir(0.0);
        macroOffsetA += vec2(windMacroOffsetB(
            position.xyz*0.42, speed*.76, 0.78, 0.8
            ))*windDir(0.9);
    
    vec2 microOffsetA = vec2(0.0);
    
        microOffsetA += vec2(windMicroOffset(
            position.xyz*0.8, speed*0.6, 0.78, 0.62
            ))*windDir(0.18);
        microOffsetA += vec2(windMicroOffset(
            position.xyz*1.0, speed*0.72, 0.63, 0.06
            ))*windDir(0.66);
    
    vec2 heavyRipple = vec2(windHeavyRipple(
            position.xyz*0.8, speed*0.6, 0.78, 0.7
            ))*windDir(0.18);
    position.xz += (macroOffsetA+microOffsetA+heavyRipple)*strength;
}

float BlockWindMacroOffsetBase(in vec3 position, in float speed, in float strength, in float rippleMix) {
    position.xz *= windRippleDir(rippleMix);
    float sin1 = sin(frameTimeCounter*pi*speed+position.x+position.z-position.y)*0.7+0.2;
    float cos1 = cos(frameTimeCounter*pi*speed*0.654+position.x+position.z-position.y)*0.7+.2;
    return (sin1+cos1)*strength;
}
float BlockWindMacroOffsetB(in vec3 position, in float speed, in float strength, in float rippleMix) {
    position.xz *= windRippleDir(rippleMix);
    float sin1 = sin(frameTimeCounter*pi*speed+position.x+position.z-position.y)*0.68+0.2;
    //float cos1 = cos(frameTimeCounter*pi*speed*0.654+position.x+position.z);
    return (sin1)*strength;
}
float BlockWindMicroOffset(in vec3 position, in float speed, in float strength, in float rippleMix) {
    position.xz *= windRippleDir(rippleMix);
    float sin1 = sin(frameTimeCounter*pi*speed*3.5+position.x+position.z-position.y)*0.5+0.5;
    float sin2 = sin(frameTimeCounter*pi*speed*0.5+position.x+position.z-position.y)*0.66+0.34;
        sin2 = max(sin2*1.2-0.2, 0.0f);
    float cos1 = cos(frameTimeCounter*pi*speed*0.7+position.x+position.z-position.y)*0.7+0.23;
        cos1 = max(cos1*1.3-0.3, 0.0f);
    return mix(sin2, cos1, sin1)*strength;
}

float BlockWindHeavyRipple(in vec3 position, in float speed, in float strength, in float rippleMix) {
    vec3 posTemp = position.xyz;
        posTemp.xyz *= windRippleDirBlock(rippleMix/3);
    float sin1 = sin(frameTimeCounter*pi*speed*0.6+(posTemp.x+posTemp.z-posTemp.y)*0.2)*0.6+0.6;
        posTemp.xyz = position.xyz*windRippleDirBlock(-rippleMix);
    float sin2 = sin(frameTimeCounter*pi*speed*0.5+(posTemp.x+posTemp.z-posTemp.y)*0.18)*0.6+0.6;
        posTemp.xyz = position.xyz*windRippleDirBlock(rippleMix/2);
    float cos1 = cos(frameTimeCounter*pi*speed*0.7+(posTemp.x+posTemp.z-posTemp.y)*0.16)*0.6+0.6;
    float amplitude = sin1*sin2*cos1;

        posTemp.xyz = position.xyz*windRippleDirBlock(rippleMix)*2;
    float sina1 = sin(frameTimeCounter*pi*speed*4.8+posTemp.x+posTemp.z-posTemp.y)*0.5+0.5;
        posTemp.xyz = position.xyz*windRippleDirBlock(-rippleMix*1.5);
    float sina2 = sin(frameTimeCounter*pi*speed*3.9+posTemp.x+posTemp.z-posTemp.y)*0.66+0.34;
        posTemp.xyz = position.xyz*windRippleDirBlock(rippleMix/2);
    float cosa1 = cos(frameTimeCounter*pi*speed*2.75+posTemp.x+posTemp.z-posTemp.y)*0.62+0.23;
    float ripple = mix(sina2, cosa1, sina1);
    return ripple*amplitude*strength;
}

void windEffectBlock(inout vec4 position, in float speed, in float strength, in float size) {
    vec4 posTemp = position*size;
    vec3 macroOffsetA = vec3(0.0);
    
        macroOffsetA += vec3(BlockWindMacroOffsetBase(
            posTemp.xyz*.3, speed*0.53, 0.96, 0.15
            ))*windDirBlock(0.0);
        macroOffsetA += vec3(BlockWindMicroOffset(
            posTemp.xyz*.64, speed*0.42, 0.87, 0.6
            ))*windDirBlock(0.0);
        macroOffsetA += vec3(BlockWindMacroOffsetB(
            posTemp.xyz*0.42, speed*.76, 0.78, 0.8
            ))*windDirBlock(0.9);
    
    vec3 microOffsetA = vec3(0.0);
        microOffsetA += vec3(BlockWindMicroOffset(
            posTemp.xyz*0.8, speed*0.6, 0.78, 0.62
            ))*windDirBlock(0.18);
        microOffsetA += vec3(BlockWindMicroOffset(
            posTemp.xyz*1.0, speed*0.72, 0.63, 0.06
            ))*windDirBlock(0.66);

    vec3 heavyRipple = vec3(BlockWindHeavyRipple(
            position.xyz*0.8, speed*0.6, 0.78, 0.7
            ))*windDirBlock(0.18);

    vec3 result = (macroOffsetA+microOffsetA+heavyRipple)+vec3(0.8, -0.1, 0.8);
    position.xyz += result*strength;
    //position.y -= mix(result.x-1, result.y-1, 0.5)*strength*0.4;
}

float doublePlantFix() {
    bool isTop = gl_MultiTexCoord0.t<mc_midTexCoord.t;
    bool onTop = mc_Entity.z > 8.0;
    return mix(float(isTop)*0.4, float(isTop)*0.6+0.4, float(onTop));
}

void decodePos() {
    position = gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex);
    position.xyz += cameraPosition.xyz;
}

void encodePos() {
    position.xyz -= cameraPosition.xyz;
    position = gl_ProjectionMatrix * (gbufferModelView * position);
}

void decodeShadowPos() {
	position = shadowProjectionInverse * position;
	position = shadowModelViewInverse * position;
	position.xyz += cameraPosition.xyz;
}

void encodeShadowPos() {
	position.xyz -= cameraPosition.xyz;
	position = shadowModelView * position;
	position = shadowProjection * position;
}

void applyWind() {
    if (blockWindGround && isOnGround) {
        windEffect(position, 0.7, 0.16, 1.0);
    }
    if (blockWindDouble) {
        windEffect(position, 0.7, 0.16*doublePlantFix(), 1.0);
    }
    if (blockWindFree) {
        windEffectBlock(position, 0.7, 0.04, 1.0);
    }
}