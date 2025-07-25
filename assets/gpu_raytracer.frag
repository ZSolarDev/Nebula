/*
HUGE CREDITS TO SEBASTIAN LAGUE!!

My ray intersection code is heavily based off of his first video on raytracing:
https://www.youtube.com/watch?v=Qz0KTGYJtUk
*/
struct Ray {
    vec3 pos;
    vec3 dir;
};

struct Triangle {
    vec3 posA;
    vec3 posB;
    vec3 posC;
    vec3 normalA;
    vec3 normalB;
    vec3 normalC;
};

struct InternalTraceResult {
    bool hit;
    vec3 hitPoint;
    vec3 normal;
    float dist;
};

struct TraceResult {
    bool hit;
    vec3 hitPoint;
    vec3 normal;
    int objectID;
    int primID;
    float dist;
};

uniform int giSamples;
uniform int width;
uniform int height;
uniform float camX;
uniform float camY;
uniform float camZ;
uniform float camPitch;
uniform float camYaw;
uniform float fov;
uniform float bounceLightRandomness;
uniform float shadowsRandomness;
uniform float vertices[512];
uniform float normals[512];
uniform float indices[512];
uniform int objectCount;
uniform int objectSeparators[256];

InternalTraceResult rayTriangle(Ray ray, Triangle tri)
{
    vec3 edgeAB = tri.posB - tri.posA;
    vec3 edgeAC = tri.posC - tri.posA;
    vec3 normalVector = cross(edgeAB, edgeAC);
    vec3 ao = ray.pos - tri.posA;
    vec3 dao = cross(ao, ray.dir);

    float determinant = -dot(ray.dir, normalVector);
    float invDet = 1 / determinant;

    float dst = dot(ao, normalVector) * invDet;
    float u = dot(edgeAC, dao) * invDet;
    float v = -dot(edgeAB, dao) * invDet;
    float w = 1 - u - v;

    InternalTraceResult traceRes;
    traceRes.hit = determinant >= 1E-6 && dst >= 0 && v >= 0 && w >= 0;
    traceRes.hitPoint = ray.pos + ray.dir * dst;
    traceRes.normal = normalize(tri.normalA * w + tri.normalB * u + tri.normalC * v);
    traceRes.dist = dst;
    return traceRes;
}

int getObjectID(int globalTriID) {
    for (int j = 0; j < objectCount - 1; j++) {
        if (globalTriID >= objectSeparators[j] && globalTriID < objectSeparators[j + 1]) {
            return j;
        }
    }
    return objectCount - 1;
}

ivec3 getIndicesFromObject(int objectID, int primID) {
    int globalTriIndex = objectSeparators[objectID] + primID;
    int indexStart = globalTriIndex * 3;
    return ivec3(
        indices[indexStart],
        indices[indexStart + 1],
        indices[indexStart + 2]
    );
}

void getVerticesFromObject(int objectID, int primID, out vec3 v0, out vec3 v1, out vec3 v2) {
    ivec3 idx = getIndicesFromObject(objectID, primID);
    v0 = vertices[idx.x];
    v1 = vertices[idx.y];
    v2 = vertices[idx.z];
}

void getNormalsFromObject(int objectID, int primID, out vec3 n0, out vec3 n1, out vec3 n2) {
    ivec3 idx = getIndicesFromObject(objectID, primID);
    n0 = normals[idx.x];
    n1 = normals[idx.y];
    n2 = normals[idx.z];
}




TraceResult traceRayAcrossScene(Ray ray)
{
    TraceResult result;
    result.hit = false;
    result.hitPoint = vec3(0.0, 0.0, 0.0);
    result.normal = vec3(0.0, 0.0, 0.0);
    result.objectID = 0;
    result.primID = 0;
    result.dist = 0.0;
    for (int i = 0; i < 512; i++) {
        int i0 = int(indices[i * 3]);
        int i1 = int(indices[i * 3 + 1]);
        int i2 = int(indices[i * 3 + 2]);
    
        vec3 v0 = vec3(
            vertices[i0 * 3],
            vertices[i0 * 3 + 1],
            vertices[i0 * 3 + 2]
        );
        vec3 v1 = vec3(
            vertices[i1 * 3],
            vertices[i1 * 3 + 1],
            vertices[i1 * 3 + 2]
        );
        vec3 v2 = vec3(
            vertices[i2 * 3],
            vertices[i2 * 3 + 1],
            vertices[i2 * 3 + 2]
        );
    
        vec3 n0 = vec3(
            normals[i0 * 3],
            normals[i0 * 3 + 1],
            normals[i0 * 3 + 2]
        );
        vec3 n1 = vec3(
            normals[i1 * 3],
            normals[i1 * 3 + 1],
            normals[i1 * 3 + 2]
        );
        vec3 n2 = vec3(
            normals[i2 * 3],
            normals[i2 * 3 + 1],
            normals[i2 * 3 + 2]
        );

        Triangle tri;
        tri.posA = v0;
        tri.posB = v1;
        tri.posC = v2;
        tri.normalA = n0;
        tri.normalB = n1;
        tri.normalC = n2;
        InternalTraceResult res = rayTriangle(ray, tri);
        if (res.hit)
        {
            int objectID = getObjectID(i);
            int localPrimID = i - objectSeparators[objectID];

            result.hit = true;
            result.hitPoint = res.hitPoint;
            result.normal = res.normal;
            result.dist = res.dist;
            result.objectID = objectID;
            result.primID = localPrimID;
            break;
        }
    }
    return result;
}

Ray pixelToWorld(float ux, float uy)
{
    float x = ux * width;
    float y = uy * height;

        float aspectRatio = width / height;

        float ndcX = (2 * x) / width - 1;
        float ndcY = (2 * y) / height - 1;

        float fovRad = 3.14159265359 * fov / 180;
        float tanFov = tan(fovRad / 2);

        float _camX = ndcX * aspectRatio * tanFov;
        float _camY = ndcY * tanFov;
        float _camZ = -1;

        vec3 dir = vec3(_camX, _camY, _camZ);
        dir = normalize(dir);

        float yaw = camYaw;
        float pitch = camPitch;

                // --- Apply Pitch (X axis) ---
        float cosPitch = cos(pitch);
        float sinPitch = sin(pitch);

        float y1 = dir.y * cosPitch - dir.z * sinPitch;
        float z1 = dir.y * sinPitch + dir.z * cosPitch;
        float x1 = dir.x;

                // --- Apply Yaw (Y axis) after pitch ---
        float cosYaw = cos(yaw);
        float sinYaw = sin(yaw);

        float x2 = x1 * cosYaw - z1 * sinYaw;
        float z2 = x1 * sinYaw + z1 * cosYaw;

        dir = vec3(x2, y1, z2);
        dir = normalize(dir);

        Ray ray;
    ray.pos = vec3(camX, camY, camZ);
        ray.dir = dir;
        return ray;
}

void main()
{
    Ray ray = pixelToWorld(openfl_TextureCoordv.x, openfl_TextureCoordv.y);
    vec4 color = flixel_texture2D(bitmap, openfl_TextureCoordv);
    gl_FragColor = vec4(ray.dir, 0);
}