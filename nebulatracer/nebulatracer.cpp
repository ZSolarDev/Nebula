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
#include <thread>
#include <chrono>
#include <mutex>

std::mutex glMutex;

#ifdef MemoryBarrier
#undef MemoryBarrier // (>_<)
#endif


GLFWwindow* window;
GLFWwindow* limeCtx;

typedef struct
{
    hl_type* t;
    float posx, posy, posz;
    float dirx, diry, dirz;
} SimpleRay;

typedef struct
{
    hl_type* t;
    bool hit;
	float distance;
    int geomID;
    int primID;
} HitResult;

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

extern "C" HitResult traceRay(int id, SimpleRay* ray) {
    std::lock_guard<std::mutex> lock(raytracerMutex);
    HitResult result = {};
    RaytracerInstance* instance = raytracers[id];

    RTCRayHit rayhit = {};
    rayhit.ray = {};
    rayhit.hit = {};
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
	result.distance = rayhit.ray.tfar;
	result.hit = rayhit.hit.geomID != RTC_INVALID_GEOMETRY_ID;
	result.geomID = rayhit.hit.geomID;
	result.primID = rayhit.hit.primID;
    return result;
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
int curTask = -1;
void* taskData = nullptr;
const char* src = nullptr;
bool taskCompleted = false;
void* dataIn;
int groupsX;
int groupsY;
int groupsZ;
int sizeInBytesIn;
int sizeInBytesOut;
void GLLoop()
{
    while (true) {
        glMutex.lock();
		int dupeTask = curTask;
        glMutex.unlock();
        switch (dupeTask) {
		    case 0: // init OpenGL context
                taskData = nullptr;
                if (!glfwInit()) {
                    std::cerr << "Failed to initialize GLFW\n";
                }
                glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);
                glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
                glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
                glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

                window = glfwCreateWindow(1, 1, "_COMPUTE", nullptr, nullptr);
                if (!window) {
                    std::cerr << "Failed to create GLFW window\n";
                    glfwTerminate();
                }

                glfwMakeContextCurrent(window);
                gladLoadGL(glfwGetProcAddress);
				glMutex.lock();
				taskCompleted = true;
                glMutex.unlock();
                curTask = -1;
                break;
			case 1: // crate compute shader (src: glsl source)
                taskData = nullptr;
                GLuint shader = glCreateShader(GL_COMPUTE_SHADER);
                glShaderSource(shader, 1, &src, nullptr);
                glCompileShader(shader);

                GLint success;
                glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
                if (!success) {
                    char log[512];
                    glGetShaderInfoLog(shader, 512, nullptr, log);
                    std::cerr << "Compute shader compilation failed:\n" << log << std::endl;
                }
                GLuint program = glCreateProgram();
                glAttachShader(program, shader);
                glLinkProgram(program);

                glGetProgramiv(program, GL_LINK_STATUS, &success);
                if (!success) {
                    char log[512];
                    glGetProgramInfoLog(program, 512, nullptr, log);
                    std::cerr << "Program linking failed:\n" << log << std::endl;
                }
                glDeleteShader(shader);
				taskData = (void*)program;
                glMutex.lock();
                taskCompleted = true;
                glMutex.unlock();
                curTask = -1;
                break;
            case 2: // run compute shader (taskData: output bytes, dataIn: input data, groupsX/Y/Z: work group sizes, sizeInBytesIn/Out: sizes of input/output data)
                GLuint ssboIn, ssboOut;

                // input
                glGenBuffers(1, &ssboIn);
                glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssboIn);
                glBufferData(GL_SHADER_STORAGE_BUFFER, sizeInBytesIn, dataIn, GL_DYNAMIC_DRAW);
                glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssboIn);

                // output
                glGenBuffers(1, &ssboOut);
                glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssboOut);
                glBufferData(GL_SHADER_STORAGE_BUFFER, sizeInBytesOut, nullptr, GL_DYNAMIC_READ);
                glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, ssboOut);

                glUseProgram(program);
                glDispatchCompute(groupsX, groupsY, groupsZ);
                glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

                // map output buffer
                glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssboOut);
                void* ptr = glMapBuffer(GL_SHADER_STORAGE_BUFFER, GL_READ_ONLY);
                vbyte* dataOut = hl_alloc_bytes(sizeInBytesOut);
                if (ptr) {
                    memcpy(dataOut, ptr, sizeInBytesOut);
                    glUnmapBuffer(GL_SHADER_STORAGE_BUFFER);
                }
                else {
                    std::cerr << "Failed to map output buffer\n";
                }

                glDeleteBuffers(1, &ssboIn);
                glDeleteBuffers(1, &ssboOut);
                GLenum err = glGetError();
                if (err != GL_NO_ERROR) {
                    std::cerr << "OpenGL error after dispatch: " << err << std::endl;
                }

                taskData = dataOut;
                glMutex.lock();
                taskCompleted = true;
                glMutex.unlock();
                curTask = -1;
                break;
            default:
                break;
		}
        std::this_thread::sleep_for(std::chrono::microseconds(10));
    }
}

GLuint program;
void initOpenGL() {
    taskCompleted = false;
    std::thread glThread(GLLoop);
    glThread.detach();
    curTask = 0;
}

void load_compute_shader(const char* glsl) {
    taskCompleted = false;
    src = glsl;
    curTask = 1;
    while (!taskCompleted) {
        std::this_thread::sleep_for(std::chrono::microseconds(10));
    }
    program = (GLuint)taskData;
}

vbyte* run_compute_shader(void* tdataIn, int tgroupsX, int tgroupsY, int tgroupsZ, int tsizeInBytesIn, int tsizeInBytesOut) {
    dataIn = tdataIn;
    groupsX = tgroupsX;
    groupsY = tgroupsY;
    groupsZ = tgroupsZ;
    sizeInBytesIn = tsizeInBytesIn;
    sizeInBytesOut = tsizeInBytesOut;
    taskCompleted = false;
    curTask = 2;
    while (!taskCompleted) {
        std::this_thread::sleep_for(std::chrono::microseconds(10));
    }
    vbyte* dataOut = (vbyte*)taskData;
	return dataOut;
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

HL_PRIM HitResult* HL_NAME(trace_ray_embree)(int id, SimpleRay* _ray) {
    HitResult res = traceRay(id, _ray);
    HitResult* finalRes = (HitResult*)hl_gc_alloc_raw(sizeof(HitResult));
	finalRes->distance = res.distance;
	finalRes->hit = res.hit;
	finalRes->geomID = res.geomID;
	finalRes->primID = res.primID;
    return finalRes;
}
DEFINE_PRIM(_OBJ(_BOOL _F32 _I32 _I32), trace_ray_embree, _I32 _OBJ(_F32 _F32 _F32 _F32 _F32 _F32));

HL_PRIM void HL_NAME(init_opengl)(_NO_ARG) {
	initOpenGL();
}
DEFINE_PRIM(_VOID, init_opengl, _NO_ARG);

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
DEFINE_PRIM(_BYTES, run_compute_shader_from_src, _STRING _BYTES _I32 _I32 _I32 _I32 _I32);

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
DEFINE_PRIM(_BYTES, run_compute_shader, _I32 _BYTES _I32 _I32 _I32 _I32 _I32);

HL_PRIM void HL_NAME(create_compute_shader)(vstring* src) {
    create_compute_shader(hl_to_utf8(src->bytes));
}
DEFINE_PRIM(_VOID, create_compute_shader, _STRING);

HL_PRIM void HL_NAME(remove_compute_shader)(int id) {
    remove_compute_shader(id);
}
DEFINE_PRIM(_VOID, remove_compute_shader, _I32);