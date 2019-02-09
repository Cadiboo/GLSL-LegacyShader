out float timeSunrise;
out float timeNoon;
out float timeSunset;
out float timeNight;
out float timeMoon;
out float timeLightTransition;
out float timeSun;

const float transitionExp = 2.0;
float timeVal = sunAngle;

void daytime() {
    float tSunrise  = ((clamp(timeVal, 0.96, 1.0)-0.96) / 0.04  + 1-(clamp(timeVal, 0.02, 0.15)-0.02) / 0.13);
    float tNoon     = ((clamp(timeVal, 0.02, 0.15)-0.02) / 0.13   - (clamp(timeVal, 0.35, 0.48)-0.35) / 0.13);
    float tSunset   = ((clamp(timeVal, 0.35, 0.48)-0.35) / 0.13 - (clamp(timeVal, 0.5, 0.54)-0.50) / 0.04);
    float tNight    = ((clamp(timeVal, 0.5, 0.53)-0.5) / 0.03  - (clamp(timeVal, 0.96, 1.0)-0.96) / 0.04);
    float tMoon     = ((clamp(timeVal, 0.51, 0.54)-0.51) / 0.03  - (clamp(timeVal, 0.97, 0.99)-0.97) / 0.02);
    float tLightTransition1 = ((clamp(timeVal, 0.494, 0.499)-0.494) / 0.005  - (clamp(timeVal, 0.52, 0.56)-0.52) / 0.03);
    float tLightTransition2 = ((clamp(timeVal, 0.94, 0.97)-0.94) / 0.03  + 1-(clamp(timeVal, 0.004, 0.034)-0.004) / 0.03);
    float tLightTransition = tLightTransition1+tLightTransition2;

    timeSunrise = clamp(pow2(tSunrise), 0.0, 1.0);
    timeNoon    = clamp(1-pow2(1-tNoon), 0.0, 1.0);
    timeSunset  = clamp(pow2(tSunset), 0.0, 1.0);
    timeNight   = clamp(1-pow2(1-tNight), 0.0, 1.0);
    timeMoon    = clamp(pow2(tMoon), 0.0, 1.0);
    timeLightTransition = (clamp(tLightTransition1, 0.0, 1.0)+clamp(tLightTransition2, 0.0, 1.0));
    timeSun		= timeSunrise + timeNoon + timeSunset;
}
