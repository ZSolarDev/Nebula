#define HL_NAME(n) nebulatracer_##n

#define GLAD_MX
#include "gl.h"
#include <GLFW/glfw3.h>
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

#ifdef MemoryBarrier
#undef MemoryBarrier // (>_<)
#endif


GLFWwindow* window = nullptr;
GladGLContext* ctx;
GLFWwindow* oldCtx = glfwGetCurrentContext();

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

extern "C" void traceRay(int id, SimpleRay* ray, bool* hitOut, unsigned int* geomIDOut, float* distOut) {
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
	*distOut = rayhit.ray.tfar;
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

//--------- OpenGL Compute Shaders(Ugh, why is lime so outdated... >:<) ---------//
void initOpenGL() {
    if (!glfwInit()) {
        std::cerr << "Failed to initialize GLFW\n";
        return;
    }
    glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    window = glfwCreateWindow(1, 1, "_COMPUTE", nullptr, oldCtx);
    if (!window) {
        std::cerr << "Failed to create GLFW window\n";
        glfwTerminate();
        return;
    }

    glfwMakeContextCurrent(window);
    int version = gladLoadGLContext(ctx, glfwGetProcAddress);
    if (version == 0) {
        printf("Failed to initialize OpenGL context for window 1\n");
        glfwDestroyWindow(window);
        glfwTerminate();
        return;
    }

    glfwMakeContextCurrent(oldCtx);
}

static GLuint loadComputeShader(const char* src) {
    GLuint shader = ctx->CreateShader(GL_COMPUTE_SHADER);
    ctx->ShaderSource(shader, 1, &src, nullptr);
    ctx->CompileShader(shader);

    GLint success;
    ctx->GetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (!success) {
        char log[512];
        ctx->GetShaderInfoLog(shader, 512, nullptr, log);
        std::cerr << "Compute shader compilation failed:\n" << log << std::endl;
    }

    GLuint program = ctx->CreateProgram();
    ctx->AttachShader(program, shader);
    ctx->LinkProgram(program);

    ctx->GetProgramiv(program, GL_LINK_STATUS, &success);
    if (!success) {
        char log[512];
        ctx->GetProgramInfoLog(program, 512, nullptr, log);
        std::cerr << "Program linking failed:\n" << log << std::endl;
    }

    ctx->DeleteShader(shader);
    return program;
}

std::unordered_map<int, GLuint> programs;

vbyte* run_compute_shader_from_src(const char* src, void* dataIn, int groupsX, int groupsY, int groupsZ, int sizeInBytesIn, int sizeInBytesOut) {
    glfwMakeContextCurrent(window);
    GLuint ssboIn, ssboOut;

    // input
    ctx->GenBuffers(1, &ssboIn);
    ctx->BindBuffer(GL_SHADER_STORAGE_BUFFER, ssboIn);
    ctx->BufferData(GL_SHADER_STORAGE_BUFFER, sizeInBytesIn, dataIn, GL_DYNAMIC_DRAW);
    ctx->BindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssboIn);

    // output
    ctx->GenBuffers(1, &ssboOut);
    ctx->BindBuffer(GL_SHADER_STORAGE_BUFFER, ssboOut);
    ctx->BufferData(GL_SHADER_STORAGE_BUFFER, sizeInBytesOut, nullptr, GL_DYNAMIC_READ);
    ctx->BindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, ssboOut);

    GLuint program = loadComputeShader(src);
    ctx->UseProgram(program);

    ctx->DispatchCompute(groupsX, groupsY, groupsZ);
    ctx->MemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

	// map output buffer
    ctx->BindBuffer(GL_SHADER_STORAGE_BUFFER, ssboOut);
    void* ptr = ctx->MapBuffer(GL_SHADER_STORAGE_BUFFER, GL_READ_ONLY);
	vbyte* dataOut = hl_alloc_bytes(sizeInBytesOut);
    if (ptr) {
        memcpy(dataOut, ptr, sizeInBytesOut);
        ctx->UnmapBuffer(GL_SHADER_STORAGE_BUFFER);
    }
    else {
        std::cerr << "Failed to map output buffer\n";
    }

    ctx->DeleteBuffers(1, &ssboIn);
    ctx->DeleteBuffers(1, &ssboOut);
    ctx->DeleteProgram(program);
    glfwMakeContextCurrent(oldCtx);

    return dataOut;
}

vbyte* run_compute_shader(int id, void* dataIn, int groupsX, int groupsY, int groupsZ, int sizeInBytesIn, int sizeInBytesOut) {
    glfwMakeContextCurrent(window);
    GLuint ssboIn, ssboOut;

    // input
    ctx->GenBuffers(1, &ssboIn);
    ctx->BindBuffer(GL_SHADER_STORAGE_BUFFER, ssboIn);
    ctx->BufferData(GL_SHADER_STORAGE_BUFFER, sizeInBytesIn, dataIn, GL_DYNAMIC_DRAW);
    ctx->BindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssboIn);

    // output
    ctx->GenBuffers(1, &ssboOut);
    ctx->BindBuffer(GL_SHADER_STORAGE_BUFFER, ssboOut);
    ctx->BufferData(GL_SHADER_STORAGE_BUFFER, sizeInBytesOut, nullptr, GL_DYNAMIC_READ);
    ctx->BindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, ssboOut);

    GLuint program = programs[id];

    ctx->DispatchCompute(groupsX, groupsY, groupsZ);
    ctx->MemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

    // map output buffer
    ctx->BindBuffer(GL_SHADER_STORAGE_BUFFER, ssboOut);
    void* ptr = ctx->MapBuffer(GL_SHADER_STORAGE_BUFFER, GL_READ_ONLY);
    vbyte* dataOut = hl_alloc_bytes(sizeInBytesOut);
    if (ptr) {
        memcpy(dataOut, ptr, sizeInBytesOut);
        ctx->UnmapBuffer(GL_SHADER_STORAGE_BUFFER);
    }
    else {
        std::cerr << "Failed to map output buffer\n";
    }

    ctx->DeleteBuffers(1, &ssboIn);
    ctx->DeleteBuffers(1, &ssboOut);
    glfwMakeContextCurrent(oldCtx);

    return dataOut;
}

void create_compute_shader(const char* src) {
    glfwMakeContextCurrent(window);
    GLuint program = loadComputeShader(src);
    programs[programs.size() + 1] = program;
    glfwMakeContextCurrent(oldCtx);
}

void set_compute_shader(int id) {
    glfwMakeContextCurrent(window);
    ctx->UseProgram(programs[id]);
    glfwMakeContextCurrent(oldCtx);
}

void remove_compute_shader(int id) {
    glfwMakeContextCurrent(window);
    ctx->DeleteProgram(programs[id]);
	programs.erase(id);
    glfwMakeContextCurrent(oldCtx);
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
	float dist = 0.0f;
    unsigned int geomID = 0;
    traceRay(id, &ray, &hit, &geomID, &dist);

    vdynamic* result = (vdynamic*)hl_alloc_dynobj();
    hl_dyn_seti(result, hl_hash_utf8("hit"), &hlt_bool, hit);
    hl_dyn_seti(result, hl_hash_utf8("dist"), &hlt_f32, dist);
    hl_dyn_seti(result, hl_hash_utf8("geomID"), &hlt_i32, geomID);
    return result;
}
DEFINE_PRIM(_DYN, trace_ray_embree, _I32 _DYN);

HL_PRIM vbyte* HL_NAME(run_compute_shader_from_src)(vstring* src, vbyte* dataIn, int groupsX, int groupsY, int groupsZ, int sizeBytesIn, int sizeBytesOut) {
    return run_compute_shader_from_src(
        hl_to_utf8(src->bytes),
        dataIn,
		groupsX,
		groupsY,
		groupsZ,
		sizeBytesIn,
		sizeBytesOut
	);
}
DEFINE_PRIM(_BYTES, run_compute_shader_from_src, _STRING _BYTES, _I32 _I32 _I32 _I32 _I32);

HL_PRIM vbyte* HL_NAME(run_compute_shader)(int id, vbyte* dataIn, int groupsX, int groupsY, int groupsZ, int sizeBytesIn, int sizeBytesOut) {
    return run_compute_shader(
        id,
        dataIn,
        groupsX,
        groupsY,
        groupsZ,
        sizeBytesIn,
        sizeBytesOut
    );
}
DEFINE_PRIM(_BYTES, run_compute_shader, _I32 _BYTES, _I32 _I32 _I32 _I32 _I32);

HL_PRIM void HL_NAME(create_compute_shader)(vstring* src) {
    create_compute_shader(hl_to_utf8(src->bytes));
}
DEFINE_PRIM(_VOID, create_compute_shader, _STRING);

HL_PRIM void HL_NAME(set_compute_shader)(int id) {
    set_compute_shader(id);
}
DEFINE_PRIM(_VOID, set_compute_shader, _I32);

HL_PRIM void HL_NAME(remove_compute_shader)(int id) {
    remove_compute_shader(id);
}
DEFINE_PRIM(_VOID, remove_compute_shader, _I32);