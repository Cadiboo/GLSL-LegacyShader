//Post Processing
#define cBloom
#define bloomThresh 30.0            //[10.0 15.0 20.0 25.0 30.0 35.0 40.0 45.0 50.0]
#define bloomInt 1.0                //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define autoExposureSmoothing 1.0 	//[0.0 0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6]
#define TAA
#define mBlur
#define llDesat
#define bpc 8               //[4 6 8 10]
#define minimumExposure 0.2 //[0.05 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]

//Ambient Effects
#define volFog
#define fogSamp 6           //[1 2 3 4 5 6 7 8 9 10 11 12]
#define vFogFilterSteps 9   //[6 9 15 21 30 60]
#define vFogFilterSize 1.0  //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5]
#define sFog

//Shading
#define softShadows true    //[true false]
#define softShadowSteps 30  //[9 15 21 30 60]
#define shadowBlur 1.0      //[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0]
#define AO
#define diffLambert
#define shadowSL 0.0        //[0.0 0.01 0.02 0.03 0.04 0.05 0.1 0.15 0.2 0.25 0.3]
#define sunlightLum 1.0     //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define skylightLum 1.0     //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define minLightVal 0.03    //[0.01 0.02 0.03 0.04 0.05 0.07 0.09 0.12 0.15 0.2 0.25 0.3 0.4 0.5 0.6]
#define torchLuma 1.0       //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]