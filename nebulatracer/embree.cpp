#define HL_NAME(n) nebulatracer_##n

#include <embree4/rtcore.h>
#include <vector>
#include <unordered_map>
#include <iostream>
#include <mutex>
#include <hl.h>
#include "parson.h"
#include <string>
#include <codecvt>
#include <locale>

typedef struct
{
    hl_type* t;
    float posx, posy, posz;
    float dirx, diry, dirz;
} SimpleRay;

struct HitResult {
    bool hit;
    unsigned int geomID;
};

struct RaytracerInstance {
    RTCDevice device = nullptr;
    RTCScene scene = nullptr;

    RaytracerInstance() {
        device = rtcNewDevice(nullptr);
        scene = rtcNewScene(device);
    }

    ~RaytracerInstance() {
        if (scene) rtcReleaseScene(scene);
        if (device) rtcReleaseDevice(device);
    }
};

std::unordered_map<int, RaytracerInstance*> raytracers;
std::mutex raytracerMutex;
int nextID = 0;

extern "C" void createRaytracer() {
    std::lock_guard<std::mutex> lock(raytracerMutex);
    int id = nextID++;
    raytracers[id] = new RaytracerInstance();
}

extern "C" void disposeRaytracer(int id) {
    std::lock_guard<std::mutex> lock(raytracerMutex);
    if (raytracers.count(id)) {
        delete raytracers[id];
        raytracers.erase(id);
    }
}

extern "C" void buildBVH(int id) {
    std::lock_guard<std::mutex> lock(raytracerMutex);
    if (raytracers.count(id)) {
        rtcSetSceneFlags(raytracers[id]->scene, RTC_SCENE_FLAG_DYNAMIC | RTC_SCENE_FLAG_ROBUST);
        rtcCommitScene(raytracers[id]->scene);
    }
}

// Embree has no refitting... :(
extern "C" void refitBVH(int id) {
    buildBVH(id);
}

extern "C" void rebuildBVH(int id) {
    buildBVH(id);
}

extern "C" void traceRay(int id, SimpleRay* ray, bool* hitOut, unsigned int* geomIDOut) {
    if (!ray || !hitOut || !geomIDOut) return;
    std::lock_guard<std::mutex> lock(raytracerMutex);
    if (!raytracers.count(id)) return;

    RaytracerInstance* instance = raytracers[id];


    RTCRayHit rayhit = {};
    rayhit.ray.org_x = ray->posx;
    rayhit.ray.org_y = ray->posy;
    rayhit.ray.org_z = ray->posz;
    rayhit.ray.dir_x = ray->dirx;
    rayhit.ray.dir_y = ray->diry;
    rayhit.ray.dir_z = ray->dirz;
    rayhit.ray.tnear = 0.0f;
    rayhit.ray.tfar = INFINITY;
    rayhit.ray.time = 0.0f;
    rayhit.ray.mask = -1;
    rayhit.ray.id = 0;
    rayhit.ray.flags = 0;

    rayhit.hit.geomID = RTC_INVALID_GEOMETRY_ID;
    rayhit.hit.primID = RTC_INVALID_GEOMETRY_ID;
    rayhit.hit.instID[0] = RTC_INVALID_GEOMETRY_ID;

    rtcIntersect1(instance->scene, &rayhit);

    *hitOut = rayhit.hit.geomID != RTC_INVALID_GEOMETRY_ID;
    *geomIDOut = rayhit.hit.geomID;
}

extern "C" void traceRay4(int id,
    SimpleRay* ray1, bool* hitOut1, unsigned int* geomIDOut1,
    SimpleRay* ray2, bool* hitOut2, unsigned int* geomIDOut2,
    SimpleRay* ray3, bool* hitOut3, unsigned int* geomIDOut3,
    SimpleRay* ray4, bool* hitOut4, unsigned int* geomIDOut4)
{
    std::lock_guard<std::mutex> lock(raytracerMutex);
    if (!raytracers.count(id)) return;

    RaytracerInstance* instance = raytracers[id];

    RTCRayHit4 rayhit4 = {};
    SimpleRay* rays[] = {
        ray1, ray2, ray3, ray4
    };
    for (int i = 0; i < 4; i++) {
        rayhit4.ray.dir_x[i] = rays[i]->dirx;
        rayhit4.ray.dir_y[i] = rays[i]->diry;
        rayhit4.ray.dir_z[i] = rays[i]->dirz;
        rayhit4.ray.org_x[i] = rays[i]->posx;
        rayhit4.ray.org_y[i] = rays[i]->posy;
        rayhit4.ray.org_z[i] = rays[i]->posz;
        rayhit4.ray.tnear[i] = 0.0f;
        rayhit4.ray.tfar[i] = INFINITY;
        rayhit4.ray.time[i] = 0.0f;
        rayhit4.ray.mask[i] = -1;
        rayhit4.ray.id[i] = 0;
        rayhit4.ray.flags[i] = 0;
        rayhit4.hit.geomID[i] = RTC_INVALID_GEOMETRY_ID;
        rayhit4.hit.primID[i] = RTC_INVALID_GEOMETRY_ID;
        rayhit4.hit.instID[0][i] = RTC_INVALID_GEOMETRY_ID;
    }

    int valid4[4] = {
        -1, -1, -1, -1
    };
    rtcIntersect4(valid4, instance->scene, &rayhit4);

    bool* hits[] = {
        hitOut1, hitOut2, hitOut3, hitOut4
    };
    unsigned int* geomIDs[] = {
        geomIDOut1, geomIDOut2, geomIDOut3, geomIDOut4
    };
    for (int i = 0; i < 4; i++) {
        *hits[i] = rayhit4.hit.geomID[i] != RTC_INVALID_GEOMETRY_ID;
        *geomIDs[i] = rayhit4.hit.geomID[i];
    }
}

extern "C" void traceRay8(int id,
    SimpleRay* ray1, bool* hitOut1, unsigned int* geomIDOut1,
    SimpleRay* ray2, bool* hitOut2, unsigned int* geomIDOut2,
    SimpleRay* ray3, bool* hitOut3, unsigned int* geomIDOut3,
    SimpleRay* ray4, bool* hitOut4, unsigned int* geomIDOut4,
    SimpleRay* ray5, bool* hitOut5, unsigned int* geomIDOut5,
    SimpleRay* ray6, bool* hitOut6, unsigned int* geomIDOut6,
    SimpleRay* ray7, bool* hitOut7, unsigned int* geomIDOut7,
    SimpleRay* ray8, bool* hitOut8, unsigned int* geomIDOut8)
{
    std::lock_guard<std::mutex> lock(raytracerMutex);
    if (!raytracers.count(id)) return;

    RaytracerInstance* instance = raytracers[id];

    RTCRayHit8 rayhit8 = {};
    SimpleRay* rays[] = { ray1, ray2, ray3, ray4, ray5, ray6, ray7, ray8 };
    for (int i = 0; i < 8; i++) {
        rayhit8.ray.dir_x[i] = rays[i]->dirx;
        rayhit8.ray.dir_y[i] = rays[i]->diry;
        rayhit8.ray.dir_z[i] = rays[i]->dirz;
        rayhit8.ray.org_x[i] = rays[i]->posx;
        rayhit8.ray.org_y[i] = rays[i]->posy;
        rayhit8.ray.org_z[i] = rays[i]->posz;
        rayhit8.ray.tnear[i] = 0.0f;
        rayhit8.ray.tfar[i] = INFINITY;
        rayhit8.ray.time[i] = 0.0f;
        rayhit8.ray.mask[i] = -1;
        rayhit8.ray.id[i] = 0;
        rayhit8.ray.flags[i] = 0;
        rayhit8.hit.geomID[i] = RTC_INVALID_GEOMETRY_ID;
        rayhit8.hit.primID[i] = RTC_INVALID_GEOMETRY_ID;
        rayhit8.hit.instID[0][i] = RTC_INVALID_GEOMETRY_ID;
    }

    int valid8[8] = { -1,-1,-1,-1,-1,-1,-1,-1 };
    rtcIntersect8(valid8, instance->scene, &rayhit8);

    bool* hits[] = { hitOut1, hitOut2, hitOut3, hitOut4, hitOut5, hitOut6, hitOut7, hitOut8 };
    unsigned int* geomIDs[] = { geomIDOut1, geomIDOut2, geomIDOut3, geomIDOut4, geomIDOut5, geomIDOut6, geomIDOut7, geomIDOut8 };
    for (int i = 0; i < 8; i++) {
        *hits[i] = rayhit8.hit.geomID[i] != RTC_INVALID_GEOMETRY_ID;
        *geomIDs[i] = rayhit8.hit.geomID[i];
    }
}

extern "C" void traceRay16(int id,
    SimpleRay* ray1, bool* hitOut1, unsigned int* geomIDOut1,
    SimpleRay* ray2, bool* hitOut2, unsigned int* geomIDOut2,
    SimpleRay* ray3, bool* hitOut3, unsigned int* geomIDOut3,
    SimpleRay* ray4, bool* hitOut4, unsigned int* geomIDOut4,
    SimpleRay* ray5, bool* hitOut5, unsigned int* geomIDOut5,
    SimpleRay* ray6, bool* hitOut6, unsigned int* geomIDOut6,
    SimpleRay* ray7, bool* hitOut7, unsigned int* geomIDOut7,
    SimpleRay* ray8, bool* hitOut8, unsigned int* geomIDOut8,
    SimpleRay* ray9, bool* hitOut9, unsigned int* geomIDOut9,
    SimpleRay* ray10, bool* hitOut10, unsigned int* geomIDOut10,
    SimpleRay* ray11, bool* hitOut11, unsigned int* geomIDOut11,
    SimpleRay* ray12, bool* hitOut12, unsigned int* geomIDOut12,
    SimpleRay* ray13, bool* hitOut13, unsigned int* geomIDOut13,
    SimpleRay* ray14, bool* hitOut14, unsigned int* geomIDOut14,
    SimpleRay* ray15, bool* hitOut15, unsigned int* geomIDOut15,
    SimpleRay* ray16, bool* hitOut16, unsigned int* geomIDOut16,
    int valid1, int valid2, int valid3, int valid4, int valid5, int valid6,
    int valid7, int valid8, int valid9, int valid10, int valid11, int valid12,
    int valid13, int valid14, int valid15, int valid16)
{
    std::lock_guard<std::mutex> lock(raytracerMutex);
    if (!raytracers.count(id)) return;

    RaytracerInstance* instance = raytracers[id];

    RTCRayHit16 rayhit16 = {};
    SimpleRay* rays[] = {
        ray1, ray2, ray3, ray4, ray5, ray6, ray7, ray8,
        ray9, ray10, ray11, ray12, ray13, ray14, ray15, ray16
    };
    for (int i = 0; i < 16; i++) {
        rayhit16.ray.dir_x[i] = rays[i]->dirx;
        rayhit16.ray.dir_y[i] = rays[i]->diry;
        rayhit16.ray.dir_z[i] = rays[i]->dirz;
        rayhit16.ray.org_x[i] = rays[i]->posx;
        rayhit16.ray.org_y[i] = rays[i]->posy;
        rayhit16.ray.org_z[i] = rays[i]->posz;
        rayhit16.ray.tnear[i] = 0.0f;
        rayhit16.ray.tfar[i] = INFINITY;
        rayhit16.ray.time[i] = 0.0f;
        rayhit16.ray.mask[i] = -1;
        rayhit16.ray.id[i] = 0;
        rayhit16.ray.flags[i] = 0;
        rayhit16.hit.geomID[i] = RTC_INVALID_GEOMETRY_ID;
        rayhit16.hit.primID[i] = RTC_INVALID_GEOMETRY_ID;
        rayhit16.hit.instID[0][i] = RTC_INVALID_GEOMETRY_ID;
    }

    int validMask[16] = {
        valid1, valid2, valid3, valid4, valid5, valid6, valid7, valid8,
        valid9, valid10, valid11, valid12, valid13, valid14, valid15, valid16
    };
    rtcIntersect16(validMask, instance->scene, &rayhit16);

    bool* hits[] = {
        hitOut1, hitOut2, hitOut3, hitOut4, hitOut5, hitOut6, hitOut7, hitOut8,
        hitOut9, hitOut10, hitOut11, hitOut12, hitOut13, hitOut14, hitOut15, hitOut16
    };
    unsigned int* geomIDs[] = {
        geomIDOut1, geomIDOut2, geomIDOut3, geomIDOut4, geomIDOut5, geomIDOut6, geomIDOut7, geomIDOut8,
        geomIDOut9, geomIDOut10, geomIDOut11, geomIDOut12, geomIDOut13, geomIDOut14, geomIDOut15, geomIDOut16
    };
    for (int i = 0; i < 16; i++) {
        *hits[i] = rayhit16.hit.geomID[i] != RTC_INVALID_GEOMETRY_ID;
        *geomIDs[i] = rayhit16.hit.geomID[i];
    }
}


void loadGeometry(const char* json, int id) {
    JSON_Value* rootVal = json_parse_string(json);
    JSON_Object* rootObj = json_value_get_object(rootVal);
    JSON_Array* geometryArr = json_object_get_array(rootObj, "geometry");
    RaytracerInstance* raytracer = raytracers[id];
	RTCDevice device = raytracer->device;
	RTCScene scene = raytracer->scene;

    rtcReleaseScene(scene);
    raytracer->scene = rtcNewScene(device);
    scene = raytracer->scene;
    rtcSetSceneFlags(scene, RTC_SCENE_FLAG_DYNAMIC | RTC_SCENE_FLAG_ROBUST);
   
    for (size_t i = 0; i < json_array_get_count(geometryArr); ++i) {
        JSON_Object* meshObj = json_array_get_object(geometryArr, i);
        JSON_Array* parts = json_object_get_array(meshObj, "meshParts");

        for (size_t j = 0; j < json_array_get_count(parts); ++j) {
            JSON_Object* part = json_array_get_object(parts, j);
            JSON_Array* indices = json_object_get_array(part, "indices");
            JSON_Array* vertices = json_object_get_array(part, "vertices");

            size_t indexCount = json_array_get_count(indices);
            size_t vertexCount = json_array_get_count(vertices);

            unsigned* inds = new unsigned[indexCount];
            float* verts = new float[vertexCount];

            for (size_t k = 0; k < indexCount; ++k)
                inds[k] = (unsigned)json_array_get_number(indices, k);
            for (size_t i = 0; i < vertexCount; ++i) {
                verts[i] = (float)json_array_get_number(vertices, i);
            }

            size_t triangleCount = indexCount / 3;
            size_t vertexCount3 = vertexCount / 3;

            RTCGeometry geom = rtcNewGeometry(device, RTC_GEOMETRY_TYPE_TRIANGLE);

            rtcSetSharedGeometryBuffer(
                geom,
                RTC_BUFFER_TYPE_VERTEX,
                0,
                RTC_FORMAT_FLOAT3,
                verts,
                0,
                sizeof(float) * 3,
                vertexCount3
            );

            rtcSetSharedGeometryBuffer(
                geom,
                RTC_BUFFER_TYPE_INDEX,
                0,
                RTC_FORMAT_UINT3,
                inds,
                0,
                sizeof(unsigned) * 3,
                triangleCount
            );

            rtcCommitGeometry(geom);
            rtcAttachGeometry(scene, geom);
            rtcReleaseGeometry(geom);
        }
    }

    rtcCommitScene(scene);
    json_value_free(rootVal);
}


//------------------------- HashLink -------------------------//

HL_PRIM void HL_NAME(new_embree)(_NO_ARG) {
	createRaytracer();
}
DEFINE_PRIM(_VOID, new_embree, _NO_ARG);

HL_PRIM void HL_NAME(dispose_raytracer_embree)(int id) {
	disposeRaytracer(id);
}
DEFINE_PRIM(_VOID, dispose_raytracer_embree, _I32);

HL_PRIM void HL_NAME(build_bvh_embree)(int id) {
	buildBVH(id);
}
DEFINE_PRIM(_VOID, build_bvh_embree, _I32);

HL_PRIM void HL_NAME(refit_bvh_embree)(int id) {
	refitBVH(id);
}
DEFINE_PRIM(_VOID, refit_bvh_embree, _I32);

HL_PRIM void HL_NAME(rebuild_bvh_embree)(int id) {
	rebuildBVH(id);
}
DEFINE_PRIM(_VOID, rebuild_bvh_embree, _I32);

HL_PRIM void HL_NAME(load_geometry_embree)(vstring* jsonStr, int id) {
    loadGeometry(hl_to_utf8(jsonStr->bytes), id);
}
DEFINE_PRIM(_VOID, load_geometry_embree, _STRING _I32);

HL_PRIM vdynamic* HL_NAME(trace_ray_embree)(int id, vdynamic* _ray) {
    SimpleRay ray = {
        .posx = (float)hl_dyn_getd(_ray, hl_hash_utf8("posx")),
        .posy = (float)hl_dyn_getd(_ray, hl_hash_utf8("posy")),
        .posz = (float)hl_dyn_getd(_ray, hl_hash_utf8("posz")),
        .dirx = (float)hl_dyn_getd(_ray, hl_hash_utf8("dirx")),
        .diry = (float)hl_dyn_getd(_ray, hl_hash_utf8("diry")),
        .dirz = (float)hl_dyn_getd(_ray, hl_hash_utf8("dirz"))
    };

    bool hit = false;
    unsigned int geomID = 0;
    traceRay(id, &ray, &hit, &geomID);

    vdynamic* result = (vdynamic*)hl_alloc_dynobj();
    hl_dyn_seti(result, hl_hash_utf8("hit"), &hlt_bool, hit);
    hl_dyn_seti(result, hl_hash_utf8("geomID"), &hlt_i32, geomID);
    return result;
}
DEFINE_PRIM(_DYN, trace_ray_embree, _I32 _DYN);

HL_PRIM vdynamic* HL_NAME(trace_rays4_embree)(int id, vdynamic* _r1, vdynamic* _r2, vdynamic* _r3, vdynamic* _r4) {
    SimpleRay rays[4];
    vdynamic* raysIn[4] = { _r1, _r2, _r3, _r4 };
    for (int i = 0; i < 4; i++) {
        vdynamic* r = raysIn[i];
        rays[i] = {
            .posx = (float)hl_dyn_getd(r, hl_hash_utf8("posx")),
            .posy = (float)hl_dyn_getd(r, hl_hash_utf8("posy")),
            .posz = (float)hl_dyn_getd(r, hl_hash_utf8("posz")),
            .dirx = (float)hl_dyn_getd(r, hl_hash_utf8("dirx")),
            .diry = (float)hl_dyn_getd(r, hl_hash_utf8("diry")),
            .dirz = (float)hl_dyn_getd(r, hl_hash_utf8("dirz"))
        };
    }

    bool hits[4] = {};
    unsigned int geomIDs[4] = {};

    traceRay4(id, &rays[0], &hits[0], &geomIDs[0], &rays[1], &hits[1], &geomIDs[1],
        &rays[2], &hits[2], &geomIDs[2], &rays[3], &hits[3], &geomIDs[3]);

    vdynamic* result = (vdynamic*)hl_alloc_dynobj();
    for (int i = 0; i < 4; i++) {
        char nameHit[8], nameID[10];
        sprintf(nameHit, "hit%d", i + 1);
        sprintf(nameID, "geomID%d", i + 1);
        hl_dyn_seti(result, hl_hash_utf8(nameHit), &hlt_bool, hits[i]);
        hl_dyn_seti(result, hl_hash_utf8(nameID), &hlt_i32, geomIDs[i]);
    }
    return result;
}
DEFINE_PRIM(_DYN, trace_rays4_embree, _I32 _DYN _DYN _DYN _DYN);

HL_PRIM vdynamic* HL_NAME(trace_rays8_embree)(int id, vdynamic* _r1, vdynamic* _r2, vdynamic* _r3, vdynamic* _r4, vdynamic* _r5, vdynamic* _r6, vdynamic* _r7, vdynamic* _r8) {
    SimpleRay rays[8];
    vdynamic* raysIn[8] = { _r1, _r2, _r3, _r4, _r5, _r6, _r7, _r8 };
    for (int i = 0; i < 8; i++) {
        vdynamic* r = raysIn[i];
        rays[i] = {
            .posx = (float)hl_dyn_getd(r, hl_hash_utf8("posx")),
            .posy = (float)hl_dyn_getd(r, hl_hash_utf8("posy")),
            .posz = (float)hl_dyn_getd(r, hl_hash_utf8("posz")),
            .dirx = (float)hl_dyn_getd(r, hl_hash_utf8("dirx")),
            .diry = (float)hl_dyn_getd(r, hl_hash_utf8("diry")),
            .dirz = (float)hl_dyn_getd(r, hl_hash_utf8("dirz"))
        };
    }

    bool hits[8] = {};
    unsigned int geomIDs[8] = {};

    traceRay8(id, &rays[0], &hits[0], &geomIDs[0], &rays[1], &hits[1], &geomIDs[1],
        &rays[2], &hits[2], &geomIDs[2], &rays[3], &hits[3], &geomIDs[3],
        &rays[4], &hits[4], &geomIDs[4], &rays[5], &hits[5], &geomIDs[5],
        &rays[6], &hits[6], &geomIDs[6], &rays[7], &hits[7], &geomIDs[7]);

    vdynamic* result = (vdynamic*)hl_alloc_dynobj();
    for (int i = 0; i < 8; i++) {
        char nameHit[8], nameID[10];
        sprintf(nameHit, "hit%d", i + 1);
        sprintf(nameID, "geomID%d", i + 1);
        hl_dyn_seti(result, hl_hash_utf8(nameHit), &hlt_bool, hits[i]);
        hl_dyn_seti(result, hl_hash_utf8(nameID), &hlt_i32, geomIDs[i]);
    }
    return result;
}
DEFINE_PRIM(_DYN, trace_rays8_embree, _I32 _DYN _DYN _DYN _DYN _DYN _DYN _DYN _DYN);

HL_PRIM vdynamic* HL_NAME(trace_rays16_embree)(int id,
    vdynamic* _r1, vdynamic* _r2, vdynamic* _r3, vdynamic* _r4,
    vdynamic* _r5, vdynamic* _r6, vdynamic* _r7, vdynamic* _r8,
    vdynamic* _r9, vdynamic* _r10, vdynamic* _r11, vdynamic* _r12,
    vdynamic* _r13, vdynamic* _r14, vdynamic* _r15, vdynamic* _r16, 
    int valid1, int valid2, int valid3, int valid4, int valid5, int valid6,
    int valid7, int valid8, int valid9, int valid10, int valid11, int valid12,
    int valid13, int valid14, int valid15, int valid16) {

    SimpleRay rays[16];
    vdynamic* raysIn[16] = { _r1, _r2, _r3, _r4, _r5, _r6, _r7, _r8, _r9, _r10, _r11, _r12, _r13, _r14, _r15, _r16 };
    for (int i = 0; i < 16; i++) {
        vdynamic* r = raysIn[i];
        rays[i] = {
            .posx = (float)hl_dyn_getd(r, hl_hash_utf8("posx")),
            .posy = (float)hl_dyn_getd(r, hl_hash_utf8("posy")),
            .posz = (float)hl_dyn_getd(r, hl_hash_utf8("posz")),
            .dirx = (float)hl_dyn_getd(r, hl_hash_utf8("dirx")),
            .diry = (float)hl_dyn_getd(r, hl_hash_utf8("diry")),
            .dirz = (float)hl_dyn_getd(r, hl_hash_utf8("dirz"))
        };
    }

    bool hits[16] = {};
    unsigned int geomIDs[16] = {};

    traceRay16(id,
        &rays[0], &hits[0], &geomIDs[0], &rays[1], &hits[1], &geomIDs[1],
        &rays[2], &hits[2], &geomIDs[2], &rays[3], &hits[3], &geomIDs[3],
        &rays[4], &hits[4], &geomIDs[4], &rays[5], &hits[5], &geomIDs[5],
        &rays[6], &hits[6], &geomIDs[6], &rays[7], &hits[7], &geomIDs[7],
        &rays[8], &hits[8], &geomIDs[8], &rays[9], &hits[9], &geomIDs[9],
        &rays[10], &hits[10], &geomIDs[10], &rays[11], &hits[11], &geomIDs[11],
        &rays[12], &hits[12], &geomIDs[12], &rays[13], &hits[13], &geomIDs[13],
        &rays[14], &hits[14], &geomIDs[14], &rays[15], &hits[15], &geomIDs[15], 
        valid1, valid2, valid3, valid4, valid5, valid6, valid7, valid8, valid9,
        valid10, valid11, valid12, valid13, valid14, valid15, valid16);

    vdynamic* result = (vdynamic*)hl_alloc_dynobj();
    for (int i = 0; i < 16; i++) {
        char nameHit[8], nameID[10];
        sprintf(nameHit, "hit%d", i + 1);
        sprintf(nameID, "geomID%d", i + 1);
        hl_dyn_seti(result, hl_hash_utf8(nameHit), &hlt_bool, hits[i]);
        hl_dyn_seti(result, hl_hash_utf8(nameID), &hlt_i32, geomIDs[i]);
    }
    return result;
}
DEFINE_PRIM(_DYN, trace_rays16_embree, _I32
    _DYN _DYN _DYN _DYN _DYN _DYN _DYN _DYN
    _DYN _DYN _DYN _DYN _DYN _DYN _DYN _DYN
    _I32 _I32 _I32 _I32 _I32 _I32 _I32 _I32
    _I32 _I32 _I32 _I32 _I32 _I32 _I32 _I32
);