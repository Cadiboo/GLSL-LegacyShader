const int RGBA16F = 0;
const int RGB16F = 1;
const int RGBA8  = 2;
const int RG16F  = 3;

const int colortex0Format   = RGBA16F;
const int colortex1Format   = RGB16F;
const int colortex2Format   = RGB16F;
const int colortex3Format   = RGBA16F;

uniform sampler2D colortex0;    //scene color
uniform sampler2D colortex1;    //scene normals
uniform sampler2D colortex2;    //lightmap.rg materials.b
uniform sampler2D colortex3;    //scene masking

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

#ifdef setShadowDynamic
    uniform sampler2DShadow shadowtex0;
    uniform sampler2DShadow shadowtex1;
    uniform sampler2DShadow shadowcolor0;
    uniform sampler2DShadow shadowcolor1;
#endif