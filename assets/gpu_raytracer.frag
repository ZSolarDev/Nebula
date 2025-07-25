#pragma header

struct Ray {
    vec3 pos;
    vec3 dir;
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