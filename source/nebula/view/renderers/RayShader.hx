package nebula.view.renderers;

import flixel.addons.display.FlxRuntimeShader;

class RayShader extends FlxRuntimeShader
{
	override public function new()
	{
		super('
#pragma header

float fov = 70.0;
vec3 obj[3];

float sdTriangle(vec3 p, vec3 a, vec3 b, vec3 c) {
    vec3 ba = b - a; vec3 pa = p - a;
    vec3 cb = c - b; vec3 pb = p - b;
    vec3 ac = a - c; vec3 pc = p - c;
    
    vec3 nor = normalize(cross(ba, ac));
    
    // Signed distance to plane
    float distPlane = dot(nor, pa);
    
    // Distances to edges (using projections clamped between 0 and 1)
    float d1 = length(pa - ba * clamp(dot(ba, pa) / dot(ba, ba), 0.0, 1.0));
    float d2 = length(pb - cb * clamp(dot(cb, pb) / dot(cb, cb), 0.0, 1.0));
    float d3 = length(pc - ac * clamp(dot(ac, pc) / dot(ac, ac), 0.0, 1.0));
    
    float edgeDist = min(min(d1, d2), d3);
    
    // If point projects inside triangle, distance is distance to plane, else distance to closest edge
    if (dot(cross(ba, nor), pa) >= 0.0 &&
        dot(cross(cb, nor), pb) >= 0.0 &&
        dot(cross(ac, nor), pc) >= 0.0) {
        return abs(distPlane);
    }
    return edgeDist;
}

void main() {
    obj[0] = vec3(-10.0, -10.0, -200.0);
    obj[1] = vec3(10.0, -10.0, -100.0);
    obj[2] = vec3(0.0, 10.0, -100.0);
    
    vec2 uv = openfl_TextureCoordv * 2.0 - 1.0;
    float aspect = openfl_TextureSize.x / openfl_TextureSize.y;
    uv.x *= aspect;
    float z = -1.0 / tan(radians(fov) * 0.5);
    vec3 rayDir = normalize(vec3(uv, z));
    
    vec3 rayPos = vec3(0.0);
    vec3 rayColor = vec3(0.0); // Start black background
    float hitThreshold = 0.01;
    float totalDist = 0.0;
    const int maxSteps = 1000;
    
    for(int i = 0; i < maxSteps; i++) {
        float dist = sdTriangle(rayPos, obj[0], obj[1], obj[2]);
        if(dist < hitThreshold) {
            rayColor = vec3(1.0, 0.0, 0.0); // Hit red
            break;
        }
        if(dist > maxSteps) {
            break; // Too far, no hit
        }
        rayPos += rayDir * dist;
        totalDist += dist;
    }
    
    gl_FragColor = vec4(rayColor, 1.0);
}

        ');
	}
}
