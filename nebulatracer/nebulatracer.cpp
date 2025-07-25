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
#include <shaderc/shaderc.h>
#include <locale>
#include <vulkan/vulkan.h>
#include <cstring>
#include <stdexcept>



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



// Globals
VkInstance instance;
VkPhysicalDevice physicalDevice = VK_NULL_HANDLE;
VkDevice device;
VkQueue computeQueue;
uint32_t computeQueueFamilyIndex = 0;
VkCommandPool commandPool;
VkCommandBuffer commandBuffer;
VkPipeline computePipeline;
VkPipelineLayout pipelineLayout;
VkDescriptorSetLayout descriptorSetLayout;
VkDescriptorPool descriptorPool;
VkShaderModule computeShaderModule = VK_NULL_HANDLE;

void initVulkan() {
    // Create Instance
    VkApplicationInfo appInfo{};
    appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    appInfo.pApplicationName = "Vulkan Compute";
    appInfo.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
    appInfo.pEngineName = "No Engine";
    appInfo.engineVersion = VK_MAKE_VERSION(1, 0, 0);
    appInfo.apiVersion = VK_API_VERSION_1_2;

    VkInstanceCreateInfo instanceCreateInfo{};
    instanceCreateInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    instanceCreateInfo.pApplicationInfo = &appInfo;

    if (vkCreateInstance(&instanceCreateInfo, nullptr, &instance) != VK_SUCCESS) {
        throw std::runtime_error("Failed to create Vulkan instance");
    }

    // Pick Physical Device with compute support
    uint32_t deviceCount = 0;
    vkEnumeratePhysicalDevices(instance, &deviceCount, nullptr);
    if (deviceCount == 0) {
        throw std::runtime_error("Failed to find GPUs with Vulkan support");
    }
    std::vector<VkPhysicalDevice> devices(deviceCount);
    vkEnumeratePhysicalDevices(instance, &deviceCount, devices.data());

    for (const auto& deviceCandidate : devices) {
        uint32_t queueFamilyCount = 0;
        vkGetPhysicalDeviceQueueFamilyProperties(deviceCandidate, &queueFamilyCount, nullptr);
        std::vector<VkQueueFamilyProperties> queueFamilies(queueFamilyCount);
        vkGetPhysicalDeviceQueueFamilyProperties(deviceCandidate, &queueFamilyCount, queueFamilies.data());

        for (uint32_t i = 0; i < queueFamilyCount; i++) {
            if (queueFamilies[i].queueFlags & VK_QUEUE_COMPUTE_BIT) {
                physicalDevice = deviceCandidate;
                computeQueueFamilyIndex = i;
                break;
            }
        }
        if (physicalDevice != VK_NULL_HANDLE)
            break;
    }
    if (physicalDevice == VK_NULL_HANDLE) {
        throw std::runtime_error("Failed to find a GPU with compute support");
    }

    // Create Logical Device and Compute Queue
    float queuePriority = 1.0f;
    VkDeviceQueueCreateInfo queueCreateInfo{};
    queueCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    queueCreateInfo.queueFamilyIndex = computeQueueFamilyIndex;
    queueCreateInfo.queueCount = 1;
    queueCreateInfo.pQueuePriorities = &queuePriority;

    VkDeviceCreateInfo deviceCreateInfo{};
    deviceCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    deviceCreateInfo.queueCreateInfoCount = 1;
    deviceCreateInfo.pQueueCreateInfos = &queueCreateInfo;

    if (vkCreateDevice(physicalDevice, &deviceCreateInfo, nullptr, &device) != VK_SUCCESS) {
        throw std::runtime_error("Failed to create logical device");
    }

    vkGetDeviceQueue(device, computeQueueFamilyIndex, 0, &computeQueue);

    // Create Command Pool
    VkCommandPoolCreateInfo poolInfo{};
    poolInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    poolInfo.queueFamilyIndex = computeQueueFamilyIndex;
    poolInfo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;

    if (vkCreateCommandPool(device, &poolInfo, nullptr, &commandPool) != VK_SUCCESS) {
        throw std::runtime_error("Failed to create command pool");
    }

    // Allocate Command Buffer
    VkCommandBufferAllocateInfo allocInfo{};
    allocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    allocInfo.commandPool = commandPool;
    allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    allocInfo.commandBufferCount = 1;

    if (vkAllocateCommandBuffers(device, &allocInfo, &commandBuffer) != VK_SUCCESS) {
        throw std::runtime_error("Failed to allocate command buffer");
    }
}

void createDescriptorSetLayout() {
    VkDescriptorSetLayoutBinding bindings[2]{};

    bindings[0].binding = 0;
    bindings[0].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    bindings[0].descriptorCount = 1;
    bindings[0].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;

    bindings[1].binding = 1;
    bindings[1].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    bindings[1].descriptorCount = 1;
    bindings[1].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;

    VkDescriptorSetLayoutCreateInfo layoutInfo{};
    layoutInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
    layoutInfo.bindingCount = 2;
    layoutInfo.pBindings = bindings;

    if (vkCreateDescriptorSetLayout(device, &layoutInfo, nullptr, &descriptorSetLayout) != VK_SUCCESS) {
        throw std::runtime_error("Failed to create descriptor set layout");
    }
}

void createPipelineLayout() {
    VkPipelineLayoutCreateInfo pipelineLayoutInfo{};
    pipelineLayoutInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    pipelineLayoutInfo.setLayoutCount = 1;
    pipelineLayoutInfo.pSetLayouts = &descriptorSetLayout;

    if (vkCreatePipelineLayout(device, &pipelineLayoutInfo, nullptr, &pipelineLayout) != VK_SUCCESS) {
        throw std::runtime_error("Failed to create pipeline layout");
    }
}

void createComputePipeline(const char* glsl) {  
    if (computeShaderModule != VK_NULL_HANDLE) {  
        vkDestroyShaderModule(device, computeShaderModule, nullptr);  
        computeShaderModule = VK_NULL_HANDLE;  
    }  

    shaderc_compiler_t compiler = shaderc_compiler_initialize();  
    shaderc_compile_options_t options = shaderc_compile_options_initialize();  
    shaderc_compile_options_set_source_language(options, shaderc_source_language_glsl);  
    shaderc_compilation_result_t result = shaderc_compile_into_spv(  
        compiler,  
        glsl,  
        strlen(glsl),  
        shaderc_compute_shader,  
        "_VKCompute.comp",  
        "main",  
        options  
    );  
    if (shaderc_result_get_compilation_status(result) != shaderc_compilation_status_success) {  
        std::cerr << "Shader compilation failed: " << shaderc_result_get_error_message(result) << std::endl;  
        return;  
    }  

    const uint32_t* spirvCode = reinterpret_cast<const uint32_t*>(shaderc_result_get_bytes(result));  
    size_t spirvSize = shaderc_result_get_length(result);  

    VkShaderModuleCreateInfo shaderModuleCreateInfo{};  
    shaderModuleCreateInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;  
    shaderModuleCreateInfo.codeSize = spirvSize;  
    shaderModuleCreateInfo.pCode = spirvCode;  

    if (vkCreateShaderModule(device, &shaderModuleCreateInfo, nullptr, &computeShaderModule) != VK_SUCCESS) {  
        throw std::runtime_error("Failed to create shader module");  
    }  

    VkPipelineShaderStageCreateInfo shaderStageInfo{};  
    shaderStageInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;  
    shaderStageInfo.stage = VK_SHADER_STAGE_COMPUTE_BIT;  
    shaderStageInfo.module = computeShaderModule;  
    shaderStageInfo.pName = "main";  

    VkComputePipelineCreateInfo pipelineCreateInfo{};  
    pipelineCreateInfo.sType = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;  
    pipelineCreateInfo.stage = shaderStageInfo;  
    pipelineCreateInfo.layout = pipelineLayout;  

    if (computePipeline != VK_NULL_HANDLE) {  
        vkDestroyPipeline(device, computePipeline, nullptr);  
        computePipeline = VK_NULL_HANDLE;  
    }  

    if (vkCreateComputePipelines(device, VK_NULL_HANDLE, 1, &pipelineCreateInfo, nullptr, &computePipeline) != VK_SUCCESS) {  
        throw std::runtime_error("Failed to create compute pipeline");  
    }  
}

VkBuffer createBuffer(VkDeviceSize size, VkBufferUsageFlags usage, VkDeviceMemory& bufferMemory) {
    VkBuffer buffer;

    VkBufferCreateInfo bufferInfo{};
    bufferInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
    bufferInfo.size = size;
    bufferInfo.usage = usage;
    bufferInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;

    if (vkCreateBuffer(device, &bufferInfo, nullptr, &buffer) != VK_SUCCESS) {
        throw std::runtime_error("Failed to create buffer");
    }

    VkMemoryRequirements memRequirements;
    vkGetBufferMemoryRequirements(device, buffer, &memRequirements);

    VkPhysicalDeviceMemoryProperties memProperties;
    vkGetPhysicalDeviceMemoryProperties(physicalDevice, &memProperties);

    VkMemoryAllocateInfo allocInfo{};
    allocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    allocInfo.allocationSize = memRequirements.size;

    bool memTypeFound = false;
    for (uint32_t i = 0; i < memProperties.memoryTypeCount; i++) {
        if ((memRequirements.memoryTypeBits & (1 << i)) &&
            (memProperties.memoryTypes[i].propertyFlags & (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT))) {
            allocInfo.memoryTypeIndex = i;
            memTypeFound = true;
            break;
        }
    }
    if (!memTypeFound) {
        throw std::runtime_error("Failed to find suitable memory type");
    }

    if (vkAllocateMemory(device, &allocInfo, nullptr, &bufferMemory) != VK_SUCCESS) {
        throw std::runtime_error("Failed to allocate buffer memory");
    }

    vkBindBufferMemory(device, buffer, bufferMemory, 0);

    return buffer;
}

vbyte* runComputeShader(void* inputData, size_t inputSize, size_t outputSize, int groupsX, int groupsY, int groupsZ) {
    vkResetCommandBuffer(commandBuffer, 0);

    // Create input buffer + memory
    VkDeviceMemory inputBufferMemory;
    VkBuffer inputBuffer = createBuffer(inputSize, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT, inputBufferMemory);

    // Map and copy input data
    void* mappedInput;
    vkMapMemory(device, inputBufferMemory, 0, inputSize, 0, &mappedInput);
    std::memcpy(mappedInput, inputData, inputSize);
    vkUnmapMemory(device, inputBufferMemory);

    // Create output buffer + memory
    VkDeviceMemory outputBufferMemory;
    VkBuffer outputBuffer = createBuffer(outputSize, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_SRC_BIT, outputBufferMemory);

    // Create Descriptor Pool if not created
    if (descriptorPool == VK_NULL_HANDLE) {
        VkDescriptorPoolSize poolSize{};
        poolSize.type = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        poolSize.descriptorCount = 2;

        VkDescriptorPoolCreateInfo poolCreateInfo{};
        poolCreateInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
        poolCreateInfo.maxSets = 1;
        poolCreateInfo.poolSizeCount = 1;
        poolCreateInfo.pPoolSizes = &poolSize;

        if (vkCreateDescriptorPool(device, &poolCreateInfo, nullptr, &descriptorPool) != VK_SUCCESS) {
            throw std::runtime_error("Failed to create descriptor pool");
        }
    }

    // Allocate Descriptor Set
    VkDescriptorSetAllocateInfo allocInfoDS{};
    allocInfoDS.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
    allocInfoDS.descriptorPool = descriptorPool;
    allocInfoDS.descriptorSetCount = 1;
    allocInfoDS.pSetLayouts = &descriptorSetLayout;

    VkDescriptorSet descriptorSet;
    if (vkAllocateDescriptorSets(device, &allocInfoDS, &descriptorSet) != VK_SUCCESS) {
        throw std::runtime_error("Failed to allocate descriptor set");
    }

    // Setup Descriptor Buffer Info
    VkDescriptorBufferInfo inputBufferInfo{};
    inputBufferInfo.buffer = inputBuffer;
    inputBufferInfo.offset = 0;
    inputBufferInfo.range = inputSize;

    VkDescriptorBufferInfo outputBufferInfo{};
    outputBufferInfo.buffer = outputBuffer;
    outputBufferInfo.offset = 0;
    outputBufferInfo.range = outputSize;

    VkWriteDescriptorSet descriptorWrites[2]{};

    descriptorWrites[0].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    descriptorWrites[0].dstSet = descriptorSet;
    descriptorWrites[0].dstBinding = 0;
    descriptorWrites[0].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    descriptorWrites[0].descriptorCount = 1;
    descriptorWrites[0].pBufferInfo = &inputBufferInfo;

    descriptorWrites[1].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    descriptorWrites[1].dstSet = descriptorSet;
    descriptorWrites[1].dstBinding = 1;
    descriptorWrites[1].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    descriptorWrites[1].descriptorCount = 1;
    descriptorWrites[1].pBufferInfo = &outputBufferInfo;

    vkUpdateDescriptorSets(device, 2, descriptorWrites, 0, nullptr);

    // Record command buffer
    VkCommandBufferBeginInfo beginInfo{};
    beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;

    if (vkBeginCommandBuffer(commandBuffer, &beginInfo) != VK_SUCCESS) {
        throw std::runtime_error("Failed to begin command buffer");
    }

    vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_COMPUTE, computePipeline);
    vkCmdBindDescriptorSets(commandBuffer, VK_PIPELINE_BIND_POINT_COMPUTE, pipelineLayout, 0, 1, &descriptorSet, 0, nullptr);

    vkCmdDispatch(commandBuffer, groupsX, groupsY, groupsZ);
    VkMemoryBarrier memoryBarrier{};
    memoryBarrier.sType = VK_STRUCTURE_TYPE_MEMORY_BARRIER;
    memoryBarrier.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
    memoryBarrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;

    vkCmdPipelineBarrier(
        commandBuffer,
        VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
        VK_PIPELINE_STAGE_HOST_BIT,
        0,
        1, &memoryBarrier,
        0, nullptr,
        0, nullptr
    );

    if (vkEndCommandBuffer(commandBuffer) != VK_SUCCESS) {
        throw std::runtime_error("Failed to record command buffer");
    }

    // Submit and wait
    VkSubmitInfo submitInfo{};
    submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
    submitInfo.commandBufferCount = 1;
    submitInfo.pCommandBuffers = &commandBuffer;

    VkFenceCreateInfo fenceInfo{};
    fenceInfo.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;

    VkFence fence;
    if (vkCreateFence(device, &fenceInfo, nullptr, &fence) != VK_SUCCESS) {
        throw std::runtime_error("Failed to create fence");
    }

    if (vkQueueSubmit(computeQueue, 1, &submitInfo, fence) != VK_SUCCESS) {
        throw std::runtime_error("Failed to submit queue");
    }

    if (vkWaitForFences(device, 1, &fence, VK_TRUE, UINT64_MAX) != VK_SUCCESS) {
        throw std::runtime_error("Failed to wait for fence");
    }
    vkDestroyFence(device, fence, nullptr);

    // Read back output data
    void* mappedOutput;
    if (vkMapMemory(device, outputBufferMemory, 0, outputSize, 0, &mappedOutput) != VK_SUCCESS) {
        throw std::runtime_error("Failed to map output buffer memory");
    }

    vbyte* outputData = hl_alloc_bytes(outputSize);
    memcpy(outputData, mappedOutput, outputSize);
    vkUnmapMemory(device, outputBufferMemory);

    // Cleanup buffers and memories
    vkDestroyBuffer(device, inputBuffer, nullptr);
    vkFreeMemory(device, inputBufferMemory, nullptr);
    vkDestroyBuffer(device, outputBuffer, nullptr);
    vkFreeMemory(device, outputBufferMemory, nullptr);

    return outputData;
}

void destroyShaderAndPipeline() {
    if (computePipeline != VK_NULL_HANDLE) {
        vkDestroyPipeline(device, computePipeline, nullptr);
        computePipeline = VK_NULL_HANDLE;
    }
    if (pipelineLayout != VK_NULL_HANDLE) {
        vkDestroyPipelineLayout(device, pipelineLayout, nullptr);
        pipelineLayout = VK_NULL_HANDLE;
    }
    if (descriptorSetLayout != VK_NULL_HANDLE) {
        vkDestroyDescriptorSetLayout(device, descriptorSetLayout, nullptr);
        descriptorSetLayout = VK_NULL_HANDLE;
    }
    if (computeShaderModule != VK_NULL_HANDLE) {
        vkDestroyShaderModule(device, computeShaderModule, nullptr);
        computeShaderModule = VK_NULL_HANDLE;
    }
    if (descriptorPool != VK_NULL_HANDLE) {
        vkDestroyDescriptorPool(device, descriptorPool, nullptr);
        descriptorPool = VK_NULL_HANDLE;
    }
}

void cleanupVulkan() {
    destroyShaderAndPipeline();

    if (commandPool != VK_NULL_HANDLE) {
        vkDestroyCommandPool(device, commandPool, nullptr);
        commandPool = VK_NULL_HANDLE;
    }

    if (device != VK_NULL_HANDLE) {
        vkDestroyDevice(device, nullptr);
        device = VK_NULL_HANDLE;
    }

    if (instance != VK_NULL_HANDLE) {
        vkDestroyInstance(instance, nullptr);
        instance = VK_NULL_HANDLE;
    }
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

HL_PRIM void HL_NAME(init_vulkan)(_NO_ARG) {
	initVulkan();
}
DEFINE_PRIM(_VOID, init_vulkan, _NO_ARG);

HL_PRIM vbyte* HL_NAME(run_compute_shader)(vbyte* dataIn, int sizeBytesIn, int sizeBytesOut, int groupsX, int groupsY, int groupsZ) {
    return runComputeShader(dataIn, sizeBytesIn, sizeBytesOut, groupsX, groupsY, groupsZ);
}
DEFINE_PRIM(_BYTES, run_compute_shader, _BYTES _I32 _I32 _I32 _I32 _I32);

HL_PRIM void HL_NAME(create_compute_shader)(vstring* src) {
    createDescriptorSetLayout();
    createPipelineLayout();
    createComputePipeline(hl_to_utf8(src->bytes));
}
DEFINE_PRIM(_VOID, create_compute_shader, _STRING);

HL_PRIM void HL_NAME(destroy_compute_shader)(_NO_ARG) {
    destroyShaderAndPipeline();
}
DEFINE_PRIM(_VOID, destroy_compute_shader, _NO_ARG);

HL_PRIM void HL_NAME(destroy_vulkan)(_NO_ARG) {
    cleanupVulkan();
}
DEFINE_PRIM(_VOID, destroy_vulkan, _NO_ARG);