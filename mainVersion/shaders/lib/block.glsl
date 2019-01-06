out float foliage;
out float emissive;
out float metal;

bool isOnGround;
bool blockWindGround;
bool blockWindDouble;
bool blockWindFree;

struct blockIdStruct {
    float tallgrass;
    float sapling;
    float shrub;
    float wheat;
    float carrot;
    float potato;
    float beets;
    float leaves;
    float leaves2;
    float vine;
    float reed;
    float doublegrass;
    float torch;
    float lava;
    float lavaFlow;
    float glowstone;
    float seaLantern;
    float water;
    float glassStain;
} block;

void idSetup() {
    block.tallgrass=31.0;
    block.sapling=6.0;
    block.shrub=32.0;
    block.wheat=59.0;
    block.carrot=141.0;
    block.potato=142.0;
    block.beets=207.0;
    block.leaves=18.0;
    block.leaves2=161.0;
    block.vine=106.0;
    block.reed=83.0;
    block.doublegrass=175.0;
    block.torch=50.0;
    block.glowstone=89.0;
    block.lava=10.0;
    block.lavaFlow=11.0;
    block.seaLantern=169.0;
    block.water=999.0;
    block.glassStain=95.0;

    isOnGround = (gl_MultiTexCoord0.t < mc_midTexCoord.t);

    blockWindGround = (mc_Entity.x == block.tallgrass ||
     mc_Entity.x == block.sapling ||
     mc_Entity.x == block.shrub ||
     mc_Entity.x == block.wheat ||
     mc_Entity.x == block.carrot ||
     mc_Entity.x == block.potato ||
     mc_Entity.x == block.beets );

    blockWindDouble = (mc_Entity.x == block.doublegrass);

    blockWindFree = (mc_Entity.x == block.leaves ||
     mc_Entity.x == block.leaves2 ||
     mc_Entity.x == block.vine);
}

void matSetup() {
    if (mc_Entity.x == block.tallgrass ||
     mc_Entity.x == block.doublegrass ||
     mc_Entity.x == block.shrub ||
     mc_Entity.x == block.wheat||
     mc_Entity.x == block.carrot||
     mc_Entity.x == block.potato ||
     mc_Entity.x == block.beets) {
        foliage = 1.0;
    } else if (mc_Entity.x == block.reed ||
     mc_Entity.x == block.vine) {
         foliage = 0.5;
    } else if (mc_Entity.x == block.leaves ||
     mc_Entity.x == block.leaves2) {
        foliage = 0.35;
    } else {
        foliage = 0.0;
    }

    if (mc_Entity.x == block.torch ||
     mc_Entity.x == block.glowstone ||
     mc_Entity.x == block.seaLantern) {
        emissive = 0.5;
    } else if(mc_Entity.x == block.lava ||
     mc_Entity.x == block.lavaFlow) {
        emissive = 1.0;
    } else {
        emissive = 0.0;
    }
}