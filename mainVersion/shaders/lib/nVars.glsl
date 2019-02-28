#define fogDens 1.0         //[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5]

out vec3 colSunlight;
out vec3 colSkylight;
out vec3 colSky;
out vec3 colHorizon;
out vec3 colSunglow;
out float fogDensity;

uniform vec3 skyColor;
uniform vec3 fogColor;

void nature() {
    vec3 sunlightSunrise;
        sunlightSunrise.r = 1.0;
        sunlightSunrise.g = 0.36;
        sunlightSunrise.b = 0.00;
        sunlightSunrise *= 0.82;

    vec3 sunlightNoon;
        sunlightNoon.r = 1.0;
        sunlightNoon.g = 0.99;
        sunlightNoon.b = 0.96;
        sunlightNoon *= 1.0;

    vec3 sunlightSunset;
        sunlightSunset.r = 1.0;
        sunlightSunset.g = 0.32;
        sunlightSunset.b = 0.0;
        sunlightSunset *= 0.85;

    vec3 sunlightNight;
        sunlightNight.r = 0.08;
        sunlightNight.g = 0.5;
        sunlightNight.b = 1.0;
        sunlightNight *= 0.012;

    colSunlight = sunlightSunrise*timeSunrise + sunlightNoon*timeNoon + sunlightSunset*timeSunset + sunlightNight*timeNight;

    vec3 skylightSunrise;
        skylightSunrise.r = 0.78;
        skylightSunrise.g = 0.72;
        skylightSunrise.b = 1.0;
        skylightSunrise *= 0.3;

    vec3 skylightNoon;
        skylightNoon.r = 0.5;
        skylightNoon.g = 0.75;
        skylightNoon.b = 1.0;
        skylightNoon *= 1.0;

    vec3 skylightSunset;
        skylightSunset.r = 0.75;
        skylightSunset.g = 0.68;
        skylightSunset.b = 1.0;
        skylightSunset *= 0.34;

    vec3 skylightNight;
        skylightNight.r = 0.08;
        skylightNight.g = 0.5;
        skylightNight.b = 1.0;
        skylightNight *= 0.03;

    colSkylight = skylightSunrise*timeSunrise + skylightNoon*timeNoon + skylightSunset*timeSunset + skylightNight*timeNight;
    colSkylight *= 1-timeMoon*0.6;

    vec3 skyVanilla = pow(skyColor, vec3(2.2));

    vec3 skySunrise;
        skySunrise.r = 0.24;
        skySunrise.g = 0.56;
        skySunrise.b = 1.0;
        skySunrise *= 0.11;

    vec3 skyNoon = skyVanilla;
        //skyNoon.r = 0.16;
        //skyNoon.g = 0.48;
        //skyNoon.b = 1.0;
        skyNoon *= 0.21;

    vec3 skySunset;
        skySunset.r = 0.25;
        skySunset.g = 0.56;
        skySunset.b = 1.0;
        skySunset *= 0.1;

    vec3 skyNight;
        skyNight.r = 0.08;
        skyNight.g = 0.5;
        skyNight.b = 1.0;
        skyNight *= 0.01;

    colSky = skySunrise*timeSunrise + skyNoon*timeNoon + skySunset*timeSunset + skyNight*timeNight;
    colSky *= (1-timeMoon*0.7);

    vec3 horizonSunrise;
        horizonSunrise.r = 0.24;
        horizonSunrise.g = 0.68;
        horizonSunrise.b = 1.0;
        horizonSunrise *= 0.4;

    vec3 horizonNoon = pow(fogColor, vec3(2.2));
        //horizonNoon.r = 0.42;
        //horizonNoon.g = 0.76;
        //horizonNoon.b = 1.00;
        horizonNoon *= 1.4;

    vec3 horizonSunset;
        horizonSunset.r = 0.18;
        horizonSunset.g = 0.66;
        horizonSunset.b = 1.0;
        horizonSunset *= 0.65;

    vec3 horizonNight;
        horizonNight.r = 0.08;
        horizonNight.g = 0.5;
        horizonNight.b = 1.0;
        horizonNight *= 0.06;

    colHorizon = horizonSunrise*timeSunrise + horizonNoon*timeNoon + horizonSunset*timeSunset + horizonNight*timeNight;
    colHorizon *= (1-timeMoon*0.89);

    vec3 sunglowSunrise;
        sunglowSunrise.r = 1.0;
        sunglowSunrise.g = 0.14;
        sunglowSunrise.b = 0.00;
        sunglowSunrise *= 0.9;

    vec3 sunglowNoon;
        sunglowNoon.r = 0.56;
        sunglowNoon.g = 0.74;
        sunglowNoon.b = 1.0;
        sunglowNoon *= 0.9;

    vec3 sunglowSunset;
        sunglowSunset.r = 1.0;
        sunglowSunset.g = 0.08;
        sunglowSunset.b = 0.0;
        sunglowSunset *= 0.8;

    vec3 sunglowNight;
        sunglowNight.r = 0.08;
        sunglowNight.g = 0.5;
        sunglowNight.b = 1.0;
        sunglowNight *= 0.004;

    colSunglow = sunglowSunrise*timeSunrise + sunglowNoon*timeNoon + sunglowSunset*timeSunset + sunlightNight*timeNight;


    float fogBaseDensity = 1.5;
    fogBaseDensity *= 1.4*timeSunrise+1.0*timeNoon+1.0*timeSunset+0.9*timeNight;
    fogDensity = fogBaseDensity*fogDens;
}