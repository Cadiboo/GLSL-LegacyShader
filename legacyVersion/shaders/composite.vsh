#version 400

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 cameraPosition;

out vec2 texcoord;

out vec3 sunVector;
out vec3 moonVector;
out vec3 lightVector;
out vec3 upPos;
out vec3 upVector;

out vec3 colSunlight;
out vec3 colSkylight;
out vec3 colSky;
out vec3 colHorizon;

uniform int worldTime;

uniform mat4 gbufferModelView;

float pow2(float x) {
    return x*x;
}

out float timeSunrise;
out float timeNoon;
out float timeSunset;
out float timeNight;
out float timeMoon;
out float timeLightTransition;
out float timeSun;

const float transitionExp = 2.0;
float timeFloat = worldTime;

void daytime() {
    float tSunrise  = ((clamp(timeFloat, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1-(clamp(timeFloat, 500.0, 1200.0) - 500.0) / 700.0);
    float tNoon     = ((clamp(timeFloat, 500.0, 1200.0) - 500.0) / 700.0) - ((clamp(timeFloat, 10500.0, 11500.0) - 10500.0) / 1000.0);
    float tSunset   = ((clamp(timeFloat, 10500.0, 11500.0) - 10500.0) / 1000.0) - ((clamp(timeFloat, 12000.0, 13000.0) - 12000.0) / 1000.0);
    float tNight    = ((clamp(timeFloat, 12000.0, 13000.0) - 12000.0) / 1000.0) - ((clamp(timeFloat, 23000.0, 24000.0) - 23000.0) / 1000.0);
    float tMoon     = ((clamp(timeFloat, 13000.0, 13750.0) - 13000.0) / 750.0) - ((clamp(timeFloat, 21500.0, 23000.0) - 21500.0) / 1500.0);
    float tLightTransition1 = ((clamp(timeFloat, 12500.0, 12600.0) - 12500.0) / 100.0) - ((clamp(timeFloat, 12900.0, 13100.0) - 12900.0) / 200.0);
    float tLightTransition2 = ((clamp(timeFloat, 22700.0, 23000.0) - 22700.0) / 300.0) - ((clamp(timeFloat, 23300.0, 23500.0) - 23300.0) / 200.0);
    float tLightTransition = tLightTransition1+tLightTransition2;

    timeSunrise = clamp(pow2(tSunrise), 0.0, 1.0);
    timeNoon    = clamp(1-pow2(1-tNoon), 0.0, 1.0);
    timeSunset  = clamp(pow2(tSunset), 0.0, 1.0);
    timeNight   = clamp(1-pow2(1-tNight), 0.0, 1.0);
    timeMoon    = clamp(pow2(tMoon), 0.0, 1.0);
    timeLightTransition = (clamp(tLightTransition1, 0.0, 1.0)+clamp(tLightTransition2, 0.0, 1.0));
    timeSun		= timeSunrise + timeNoon + timeSunset;
}

void naturals() {
    vec3 sunlightSunrise;
    sunlightSunrise.r = 1.0;
    sunlightSunrise.g = 0.6;
    sunlightSunrise.b = 0.15;
    sunlightSunrise *= 0.5;

    vec3 sunlightNoon;
    sunlightNoon.r = 1.0;
    sunlightNoon.g = 0.99;
    sunlightNoon.b = 0.98;
    sunlightNoon *= 1.0;

    vec3 sunlightSunset;
    sunlightSunset.r = 1.0;
    sunlightSunset.g = 0.5;
    sunlightSunset.b = 0.1;
    sunlightSunset *= 0.4;

    vec3 sunlightNight;
    sunlightNight.r = 0.1;
    sunlightNight.g = 0.4;
    sunlightNight.b = 1.0;
    sunlightNight *= 0.1*(1-timeMoon*0.5);

    colSunlight = sunlightSunrise*timeSunrise + sunlightNoon*timeNoon + sunlightSunset*timeSunset + sunlightNight*timeNight;

    vec3 skylightSunrise;
    skylightSunrise.r = 0.8;
    skylightSunrise.g = 0.6;
    skylightSunrise.b = 1.0;
    skylightSunrise *= 0.5;

    vec3 skylightNoon;
    skylightNoon.r = 0.6;
    skylightNoon.g = 0.75;
    skylightNoon.b = 1.0;
    skylightNoon *= 1.0;

    vec3 skylightSunset;
    skylightSunset.r = 0.9;
    skylightSunset.g = 0.5;
    skylightSunset.b = 1.0;
    skylightSunset *= 0.4;

    vec3 skylightNight;
    skylightNight.r = 0.1;
    skylightNight.g = 0.4;
    skylightNight.b = 1.0;
    skylightNight *= 0.4*(1-timeMoon*0.5);

    colSkylight = skylightSunrise*timeSunrise + skylightNoon*timeNoon + skylightSunset*timeSunset + skylightNight*timeNight;

    vec3 skySunrise;
    skySunrise.r = 0.30;
    skySunrise.g = 0.62;
    skySunrise.b = 1.0;
    skySunrise *= 0.08;

    vec3 skyNoon;
    skyNoon.r = 0.18;
    skyNoon.g = 0.5;
    skyNoon.b = 1.0;
    skyNoon *= 0.15;

    vec3 skySunset;
    skySunset.r = 0.9;
    skySunset.g = 0.5;
    skySunset.b = 1.0;
    skySunset *= 0.4;

    vec3 skyNight;
    skyNight.r = 0.1;
    skyNight.g = 0.4;
    skyNight.b = 1.0;
    skyNight *= 0.4*(1-timeMoon*0.5);

    colSky = skySunrise*timeSunrise + skyNoon*timeNoon + skySunset*timeSunset + skyNight*timeNight;

    vec3 horizonSunrise;
    horizonSunrise.r = 0.8;
    horizonSunrise.g = 0.6;
    horizonSunrise.b = 1.0;
    horizonSunrise *= 0.5;

    vec3 horizonNoon;
    horizonNoon.r = 0.36;
    horizonNoon.g = 0.74;
    horizonNoon.b = 1.0;
    horizonNoon *= 1.0;

    vec3 horizonSunset;
    horizonSunset.r = 0.36;
    horizonSunset.g = 0.74;
    horizonSunset.b = 1.0;
    horizonSunset *= 0.4;

    vec3 horizonNight;
    horizonNight.r = 0.1;
    horizonNight.g = 0.4;
    horizonNight.b = 1.0;
    horizonNight *= 0.4*(1-timeMoon*0.5);

    colHorizon = horizonSunrise*timeSunrise + horizonNoon*timeNoon + horizonSunset*timeSunset + horizonNight*timeNight;

}

void main() {
    daytime();
    naturals();

    gl_Position     = ftransform();
    texcoord        = gl_MultiTexCoord0.st;
    sunVector       = normalize(sunPosition);
    moonVector      = normalize(moonPosition);
    upPos           = (gbufferModelView[1].xyz);
    upVector        = normalize(upPos);

    if (timeFloat < 12750.0 || timeFloat > 23100.0) {
        lightVector = sunVector;
    } else {
        lightVector = moonVector;
    }
}