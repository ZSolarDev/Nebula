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

extern "C" void traceRays(int id, SimpleRay* rays, int count, bool* hitOut, unsigned int* geomIDOut) {
    if (!rays || !hitOut || !geomIDOut) return;
    std::lock_guard<std::mutex> lock(raytracerMutex);
    if (!raytracers.count(id)) return;

    RaytracerInstance* instance = raytracers[id];
    int processed = 0;
    while (processed < count) {
        int remaining = count - processed;
        int batchSize = 1;

        if (remaining >= 16) batchSize = 16;
        else if (remaining >= 8) batchSize = 8;
        else if (remaining >= 4) batchSize = 4;

        if (batchSize == 1) {
            RTCRayHit rayhit = {};
            SimpleRay* ray = &rays[processed];

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

            hitOut[processed] = rayhit.hit.geomID != RTC_INVALID_GEOMETRY_ID;
            geomIDOut[processed] = rayhit.hit.geomID;

            processed += 1;
        }
        else if (batchSize == 4) {
            RTCRayHit4 rayhits = {};
            for (int i = 0; i < 4; i++) {
                SimpleRay* ray = &rays[processed + i];
                rayhits.ray.org_x[i] = ray->posx;
                rayhits.ray.org_y[i] = ray->posy;
                rayhits.ray.org_z[i] = ray->posz;
                rayhits.ray.dir_x[i] = ray->dirx;
                rayhits.ray.dir_y[i] = ray->diry;
                rayhits.ray.dir_z[i] = ray->dirz;
                rayhits.ray.tnear[i] = 0.0f;
                rayhits.ray.tfar[i] = INFINITY;
                rayhits.ray.time[i] = 0.0f;
                rayhits.ray.mask[i] = -1;
                rayhits.ray.id[i] = 0;
                rayhits.ray.flags[i] = 0;

                rayhits.hit.geomID[i] = RTC_INVALID_GEOMETRY_ID;
                rayhits.hit.primID[i] = RTC_INVALID_GEOMETRY_ID;
                rayhits.hit.instID[0][i] = RTC_INVALID_GEOMETRY_ID;
            }
            int validMask = 0b1111;
            rtcIntersect4(&validMask, instance->scene, (RTCRayHit4*)&rayhits, nullptr);
            for (int i = 0; i < 4; i++) {
                hitOut[processed + i] = rayhits.hit.geomID[i] != RTC_INVALID_GEOMETRY_ID;
                geomIDOut[processed + i] = rayhits.hit.geomID[i];
            }
            processed += 4;
        }
        else if (batchSize == 8) {
            RTCRayHit8 rayhits = {};
            for (int i = 0; i < 8; i++) {
                SimpleRay* ray = &rays[processed + i];
                rayhits.ray.org_x[i] = ray->posx;
                rayhits.ray.org_y[i] = ray->posy;
                rayhits.ray.org_z[i] = ray->posz;
                rayhits.ray.dir_x[i] = ray->dirx;
                rayhits.ray.dir_y[i] = ray->diry;
                rayhits.ray.dir_z[i] = ray->dirz;
                rayhits.ray.tnear[i] = 0.0f;
                rayhits.ray.tfar[i] = INFINITY;
                rayhits.ray.time[i] = 0.0f;
                rayhits.ray.mask[i] = -1;
                rayhits.ray.id[i] = 0;
                rayhits.ray.flags[i] = 0;

                rayhits.hit.geomID[i] = RTC_INVALID_GEOMETRY_ID;
                rayhits.hit.primID[i] = RTC_INVALID_GEOMETRY_ID;
                rayhits.hit.instID[0][i] = RTC_INVALID_GEOMETRY_ID;
            }
            int validMask = 0xFF;
            rtcIntersect8(&validMask, instance->scene, (RTCRayHit8*)&rayhits, nullptr);
            for (int i = 0; i < 8; i++) {
                hitOut[processed + i] = rayhits.hit.geomID[i] != RTC_INVALID_GEOMETRY_ID;
                geomIDOut[processed + i] = rayhits.hit.geomID[i];
            }
            processed += 8;
        }
        else if (batchSize == 16) {
            RTCRayHit16 rayhits = {};
            for (int i = 0; i < 16; i++) {
                SimpleRay* ray = &rays[processed + i];
                rayhits.ray.org_x[i] = ray->posx;
                rayhits.ray.org_y[i] = ray->posy;
                rayhits.ray.org_z[i] = ray->posz;
                rayhits.ray.dir_x[i] = ray->dirx;
                rayhits.ray.dir_y[i] = ray->diry;
                rayhits.ray.dir_z[i] = ray->dirz;
                rayhits.ray.tnear[i] = 0.0f;
                rayhits.ray.tfar[i] = INFINITY;
                rayhits.ray.time[i] = 0.0f;
                rayhits.ray.mask[i] = -1;
                rayhits.ray.id[i] = 0;
                rayhits.ray.flags[i] = 0;

                rayhits.hit.geomID[i] = RTC_INVALID_GEOMETRY_ID;
                rayhits.hit.primID[i] = RTC_INVALID_GEOMETRY_ID;
                rayhits.hit.instID[0][i] = RTC_INVALID_GEOMETRY_ID;
            }
            int validMask = 0xFFFF;
            rtcIntersect16(&validMask, instance->scene, (RTCRayHit16*)&rayhits, nullptr);
            for (int i = 0; i < 16; i++) {
                hitOut[processed + i] = rayhits.hit.geomID[i] != RTC_INVALID_GEOMETRY_ID;
                geomIDOut[processed + i] = rayhits.hit.geomID[i];
            }
            processed += 16;
        }
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

static vclosure* stored_callback = nullptr;

HL_PRIM void HL_NAME(set_callback_embree)(vclosure* cb) {
    if (stored_callback) hl_remove_root(&stored_callback);
    stored_callback = cb;
    if (stored_callback) hl_add_root(&stored_callback);
}
DEFINE_PRIM(_VOID, set_callback_embree, _FUN(_VOID, _DYN));


void call_callback(int i, bool hit, unsigned int geomID) {
    if (!stored_callback) return;

    vdynamic* result = (vdynamic*)hl_alloc_dynobj();
    hl_dyn_seti(result, hl_hash_utf8("hit"), &hlt_bool, hit);
    hl_dyn_seti(result, hl_hash_utf8("geomID"), &hlt_i32, geomID);
    hl_dyn_seti(result, hl_hash_utf8("index"), &hlt_i32, i);

    vdynamic* args[1] = { result };
    hl_dyn_call(stored_callback, args, 1);
}

HL_PRIM void HL_NAME(trace_rays_embree)(int id, int len, varray* _rays) {
    SimpleRay* rays = new SimpleRay[len];
    for (int i = 0; i < len; i++) {
        vdynamic** rayArray = hl_aptr(_rays, vdynamic*);
        vdynamic* rayDyn = rayArray[i];
        SimpleRay ray = {};
        ray.posx = (float)hl_dyn_getd(rayDyn, hl_hash_utf8("posx"));
        ray.posy = (float)hl_dyn_getd(rayDyn, hl_hash_utf8("posy"));
        ray.posz = (float)hl_dyn_getd(rayDyn, hl_hash_utf8("posz"));
        ray.dirx = (float)hl_dyn_getd(rayDyn, hl_hash_utf8("dirx"));
        ray.diry = (float)hl_dyn_getd(rayDyn, hl_hash_utf8("diry"));
        ray.dirz = (float)hl_dyn_getd(rayDyn, hl_hash_utf8("dirz"));

        rays[i] = ray;
    }

    bool* hit = new bool[len];
    unsigned int* geomID = new unsigned int[len];
    traceRays(id, rays, len, hit, geomID);

    for (int i = 0; i < len; i++) {
        call_callback(i, hit[i], geomID[i]);
    }

    delete[] rays;
    delete[] hit;
    delete[] geomID;
}
DEFINE_PRIM(_VOID, trace_rays_embree, _I32 _I32 _ARR);
