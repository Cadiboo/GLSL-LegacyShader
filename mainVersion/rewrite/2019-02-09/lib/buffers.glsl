const int RGBA16F = 0;
const int RGB16F = 1;
const int RGBA8  = 2;
const int RG16F  = 3;

const int colortex0Format   = RGBA16F;
const int colortex1Format   = RGB16F;
const int colortex2Format   = RGBA8;
const int colortex3Format   = RG16F;
const int colortex4Format   = RGBA8;
const int colortex5Format   = RGBA16F;
const int colortex6Format   = RGBA16F;
const int colortex7Format   = RGBA16F;
const int shadowcolor0Format = RGBA16F;

uniform sampler2D colortex0;    //COLOR HDR
uniform sampler2D colortex1;    //NORMALS
uniform sampler2D colortex2;    //MASK
uniform sampler2D colortex3;    //LIGHTING
uniform sampler2D colortex4;    //MATERIAL
uniform sampler2D colortex5;    //MATERIAL

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;
uniform sampler2DShadow shadowcolor0;
uniform sampler2DShadow shadowcolor1;