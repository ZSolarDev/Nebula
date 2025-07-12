package nebula.view.renderers;

import flixel.*;
import openfl.Lib;
import openfl.Vector;
import openfl.display.BitmapData;
import openfl.display.Stage3D;
import openfl.display3D.Context3D;
import openfl.display3D.Program3D;
import openfl.display3D.textures.Texture;
import openfl.events.Event;
import openfl.geom.Vector3D;

// TODO: Finish this
class GPURaytracer extends FlxSprite implements ViewRenderer
{
	public var view:N3DView;
	public var stage3D:Stage3D;
	public var program:Program3D;
	public var context3D:Context3D;
	public var texture:Texture;

	public function new(view:N3DView)
	{
		super(0, 0);
		this.view = view;
		makeGraphic(view.width, view.height, 0x00D9FF);
		FlxG.state.add(this);
		stage3D = Lib.current.stage.stage3Ds[0];
		stage3D.addEventListener(Event.CONTEXT3D_CREATE, onContext3DCreate);
		stage3D.requestContext3D(AUTO, STANDARD_EXTENDED);
	}

	function onContext3DCreate(event:Event)
	{
		context3D = stage3D.context3D;
		context3D.configureBackBuffer(Lib.current.stage.stageWidth, Lib.current.stage.stageHeight, 0, true);
		program = context3D.createProgram(GLSL);
		program.uploadSources('
        attribute vec3 aPosition;
        attribute vec2 aTexCoord;
        uniform mat4 uProjectionMatrix;
        varying vec2 vTexCoord;
        void main() {
            gl_Position = uProjectionMatrix * vec4(aPosition, 1.0);
            vTexCoord = aTexCoord;
        }
        ', '
        #pragma header

        uniform sampler2D triangleDataTex;
        uniform int triangleCount;
        uniform float fov;
        uniform float textureWidth;
        uniform float textureHeight;
        uniform vec3 minPos;
        uniform vec3 camPos;
        uniform vec3 camForward;
        uniform vec3 camRight;
        uniform vec3 camUp;
        uniform vec3 size;
        float epsilon = 0.001;
        
        varying vec2 vTexCoord;

        float decodeFloat(vec4 rgba) {
            return rgba.r + rgba.g / 255.0 + rgba.b / (255.0 * 255.0) + rgba.a / (255.0 * 255.0 * 255.0);
        }

        vec3 decodeVec3(float baseIndex) {
        	float u0 = (baseIndex + 0.5) / textureWidth;
        	float u1 = (baseIndex + 1.5) / textureWidth;
        	float u2 = (baseIndex + 2.5) / textureWidth;

        	vec3 result; //highp?
        	result.x = decodeFloat(texture2D(triangleDataTex, vec2(u0, 0.5)));
        	result.y = decodeFloat(texture2D(triangleDataTex, vec2(u1, 0.5)));
        	result.z = decodeFloat(texture2D(triangleDataTex, vec2(u2, 0.5)));
        	return result;
        }


        float rand(vec2 co)
        {
            return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
        }

        void main() {
            vec2 uv = vTexCoord * 2.0 - 1.0;
            uv.y = -uv.y; // flip vertically
            float aspect = textureWidth / textureHeight;
            uv.x *= aspect;
            
            // Debug: Show triangle count as color
            if (triangleCount == 0) {
                gl_FragColor = vec4(1.0, 0.0, 1.0, 1.0); // Magenta = no triangles
                return;
            }
            
            // Proper camera ray generation
            float fovRad = radians(fov);
            float z = -1.0 / tan(fovRad * 0.5);
            
            // Create ray in camera space, then transform to world space
            vec3 rayDirCam = normalize(vec3(uv.x, uv.y, z));
            vec3 rayDir = normalize(rayDirCam.x * camRight + rayDirCam.y * camUp + rayDirCam.z * camForward);
            vec3 rayPos = camPos;
            
            float closest = 1000000.0;
            int hitIndex = -1;
            
            // Debug: Test first triangle data
            if (triangleCount > 0) {
                int base = 0;
                vec3 normA = decodeVec3(float(base));
                normA = (normA - epsilon) / (1.0 - 2.0 * epsilon);
                vec3 a = normA * size + minPos;
                vec3 normB = decodeVec3(float(base + 3));
                normB = (normB - epsilon) / (1.0 - 2.0 * epsilon);
                vec3 b = normB * size + minPos;
                vec3 normC = decodeVec3(float(base + 6));
                normC = (normC - epsilon) / (1.0 - 2.0 * epsilon);
                vec3 c = normC * size + minPos;
                
                // Debug: Show triangle positions as colors in corner
                if (uv.x < -0.8 && uv.y > 0.8) {
                    gl_FragColor = vec4(abs(a) / 100.0, 1.0);
                    return;
                }
                if (uv.x < -0.6 && uv.y > 0.8) {
                    gl_FragColor = vec4(abs(b) / 100.0, 1.0);
                    return;
                }
                if (uv.x < -0.4 && uv.y > 0.8) {
                    gl_FragColor = vec4(abs(c) / 100.0, 1.0);
                    return;
                }
            }
            
            // Ray-triangle intersection with debug info
            for (int i = 0; i < triangleCount; i++) {
                int base = i * 18;
                vec3 normA = decodeVec3(float(base));
                normA = (normA - epsilon) / (1.0 - 2.0 * epsilon);
                vec3 a = normA * size + minPos;
                vec3 normB = decodeVec3(float(base + 3));
                normB = (normB - epsilon) / (1.0 - 2.0 * epsilon);
                vec3 b = normB * size + minPos;
                vec3 normC = decodeVec3(float(base + 6));
                normC = (normC - epsilon) / (1.0 - 2.0 * epsilon);
                vec3 c = normC * size + minPos;
                
                // Debug: Show triangle bounds
                float minDist = min(distance(rayPos, a), min(distance(rayPos, b), distance(rayPos, c)));
                if (minDist < 10.0 && uv.x > 0.8 && uv.y > 0.8) {
                    gl_FragColor = vec4(1.0 - minDist / 10.0, 0.0, 0.0, 1.0);
                    return;
                }
                
                // Möller-Trumbore intersection
                vec3 edge1 = b - a;
                vec3 edge2 = c - a;
                vec3 h = cross(rayDir, edge2);
                float det = dot(edge1, h);
                
                // Debug: Show determinant issues
                if (abs(det) < 0.000001) {
                    if (uv.x > 0.6 && uv.y > 0.6) {
                        gl_FragColor = vec4(0.0, 1.0, 0.0, 1.0); // Green = degenerate triangle
                        return;
                    }
                    continue;
                }
                
                // Debug: Show if we have valid triangles but no intersection
                if (i == 0 && uv.x > 0.6 && uv.y < -0.6) {
                    gl_FragColor = vec4(1.0, 1.0, 0.0, 1.0); // Yellow = valid triangle found
                    return;
                }
                
                float invDet = 1.0 / det;
                vec3 s = rayPos - a;
                float u = invDet * dot(s, h);
                
                if (u < 0.0 || u > 1.0) continue;
                
                vec3 q = cross(s, edge1);
                float v = invDet * dot(rayDir, q);
                
                if (v < 0.0 || u + v > 1.0) continue;
                
                float t = invDet * dot(edge2, q);
                
                // Debug: Show intersection tests
                if (t > 0.001) {
                    if (uv.x > 0.4 && uv.y > 0.4) {
                        gl_FragColor = vec4(0.0, 0.0, 1.0, 1.0); // Blue = valid intersection
                        return;
                    }
                }
                
                // Debug: Show UV coordinates
                if (uv.x > 0.4 && uv.y < -0.4) {
                    gl_FragColor = vec4(u, v, 0.0, 1.0); // Show UV coords
                    return;
                }
                
                // Debug: Show t value
                if (t > 0.001 && uv.x < -0.4 && uv.y < -0.4) {
                    gl_FragColor = vec4(t / 100.0, 0.0, 0.0, 1.0); // Show t distance
                    return;
                }
                
                if (t > 0.001 && t < closest) {
                    closest = t;
                    hitIndex = i;
                }
            }
            
            if (hitIndex == -1) {
                // Sky color
                gl_FragColor = vec4(0.5, 0.7, 1.0, 1.0);
                return;
            }
            
            // We hit something! Show hit triangle color
            int base = hitIndex * 18;
            vec3 albedo = decodeVec3(float(base + 15));
            gl_FragColor = vec4(albedo, 1.0);
        }
        ');
		texture = context3D.createTexture(Lib.current.stage.stageWidth, Lib.current.stage.stageHeight, RGBA_HALF_FLOAT, false);
	}

	function decodeFloatFromRGBA(rgba:Array<Int>):Float
	{
		var c = [rgba[0] / 255.0, rgba[1] / 255.0, rgba[2] / 255.0, rgba[3] / 255.0];

		// Reconstruct float from packed channels:
		// This is the inverse of your encoding formula
		return c[0] + c[1] / 255.0 + c[2] / (255.0 * 255.0) + c[3] / (255.0 * 255.0 * 255.0);
	}

	public function encodeFloatToRGBA(v:Float):Array<Int>
	{
		var scale = [1.0, 255.0, 65025.0, 16581375.0];
		var enc = [v * scale[0], v * scale[1], v * scale[2], v * scale[3]];

		for (i in 0...4)
			enc[i] = enc[i] - Math.floor(enc[i]);

		enc[0] -= enc[1] / 255.0;
		enc[1] -= enc[2] / 255.0;
		enc[2] -= enc[3] / 255.0;

		return [
			Std.int(enc[0] * 255.0),
			Std.int(enc[1] * 255.0),
			Std.int(enc[2] * 255.0),
			Std.int(enc[3] * 255.0)
		];
	}

	public function colorToRGBFloat(c:Int):Array<Float>
	{
		return [
			((c >> 16) & 0xFF) / 255.0, // R
			((c >> 8) & 0xFF) / 255.0, // G
			(c & 0xFF) / 255.0 // B
		];
	}

	public function render()
	{
		var tris = view.triangles;

		if (tris.length == 0)
		{
			trace('No triangles to render!');
			return;
		}

		var bmp = new BitmapData(tris.length * 18, 1, true, 0);
		var px = 0;

		var pitch = view.camPitch;
		var yaw = view.camYaw;
		var camPos = new Vector3D(view.camX, view.camY, view.camZ);

		// Camera is at positive Z looking toward negative Z
		// So forward should point toward negative Z
		var fx = Math.cos(pitch) * Math.sin(yaw);
		var fy = Math.sin(pitch);
		var fz = -Math.cos(pitch) * Math.cos(yaw); // Negative Z forward
		var forward = new Vector3D(fx, fy, fz);

		var right = new Vector3D(Math.sin(yaw - Math.PI / 2), 0, Math.cos(yaw - Math.PI / 2));
		var up = right.crossProduct(forward);

		// Store world space bounds instead of camera space
		var minX = 1e20, minY = 1e20, minZ = 1e20;
		var maxX = -1e20, maxY = -1e20, maxZ = -1e20;
		for (tri in tris)
		{
			for (p in [tri[0].pos, tri[1].pos, tri[2].pos])
			{
				if (p.x < minX)
					minX = p.x;
				if (p.y < minY)
					minY = p.y;
				if (p.z < minZ)
					minZ = p.z;
				if (p.x > maxX)
					maxX = p.x;
				if (p.y > maxY)
					maxY = p.y;
				if (p.z > maxZ)
					maxZ = p.z;
			}
		}
		var sizeX = maxX - minX;
		var sizeY = maxY - minY;
		var sizeZ = maxZ - minZ;
		for (tri in tris)
		{
			// Keep triangles in world space
			var p0 = tri[0].pos;
			var p1 = tri[1].pos;
			var p2 = tri[2].pos;

			var edge1 = p1.subtract(p0);
			var edge2 = p2.subtract(p0);
			var normal = edge1.crossProduct(edge2);
			normal.normalize();

			var rgb = colorToRGBFloat(tri[0].meshPart.color);

			var epsilon = 0.001;
			var normP0x = ((p0.x - minX) / sizeX) * (1.0 - 2 * epsilon) + epsilon;
			var normP0y = ((p0.y - minY) / sizeY) * (1.0 - 2 * epsilon) + epsilon;
			var normP0z = ((p0.z - minZ) / sizeZ) * (1.0 - 2 * epsilon) + epsilon;

			var normP1x = ((p1.x - minX) / sizeX) * (1.0 - 2 * epsilon) + epsilon;
			var normP1y = ((p1.y - minY) / sizeY) * (1.0 - 2 * epsilon) + epsilon;
			var normP1z = ((p1.z - minZ) / sizeZ) * (1.0 - 2 * epsilon) + epsilon;

			var normP2x = ((p2.x - minX) / sizeX) * (1.0 - 2 * epsilon) + epsilon;
			var normP2y = ((p2.y - minY) / sizeY) * (1.0 - 2 * epsilon) + epsilon;
			var normP2z = ((p2.z - minZ) / sizeZ) * (1.0 - 2 * epsilon) + epsilon;

			var data = [
				normP0x,
				normP0y,
				normP0z,
				normP1x,
				normP1y,
				normP1z,
				normP2x,
				normP2y,
				normP2z,
				normal.x * 0.5 + 0.5,
				normal.y * 0.5 + 0.5,
				normal.z * 0.5 + 0.5,
				1.0,
				0.0,
				0.0, // roughness, metalness, emission (dummy)
				rgb[0],
				rgb[1],
				rgb[2]
			];

			for (fID in 0...data.length)
			{
				var f = data[fID];
				var rgba = encodeFloatToRGBA(f);
				var color = (rgba[0] << 24) | (rgba[1] << 16) | (rgba[2] << 8) | rgba[3];
				bmp.setPixel32(px++, 0, color);
			}
		}

		if (context3D != null)
		{
			texture.uploadFromBitmapData(bmp);
			context3D.setTextureAt(0, texture);
			context3D.setProgramConstantsFromVector(FRAGMENT, 0, Vector.ofArray([tris.length, view.fov, 0, 0])); // just tris.length and fov for now
			context3D.setProgramConstantsFromVector(FRAGMENT, 1, Vector.ofArray([minX, minY, minZ, 0]));
			context3D.setProgramConstantsFromVector(FRAGMENT, 2, Vector.ofArray([sizeX, sizeY, sizeZ, 0]));
			context3D.setProgramConstantsFromVector(FRAGMENT, 3, Vector.ofArray([view.camX, view.camY, view.camZ, 0]));
			context3D.setProgramConstantsFromVector(FRAGMENT, 4, Vector.ofArray([fx, fy, fz, 0]));
			context3D.setProgramConstantsFromVector(FRAGMENT, 5, Vector.ofArray([right.x, right.y, right.z, 0]));
			context3D.setProgramConstantsFromVector(FRAGMENT, 6, Vector.ofArray([up.x, up.y, up.z, 0]));
			context3D.setProgramConstantsFromVector(FRAGMENT, 7, Vector.ofArray([view.width, view.height, 0.0, 0.0]));
			var vertices:Array<Float> = [-1, -1, 0, 0, 0, 1, -1, 0, 1, 0, 1, 1, 0, 1, 1, -1, 1, 0, 0, 1];
			var vertexBuffer = context3D.createVertexBuffer(4, 5);
			vertexBuffer.uploadFromVector(Vector.ofArray(vertices), 0, 4);
			context3D.setVertexBufferAt(0, vertexBuffer, 0, FLOAT_3);
			context3D.setVertexBufferAt(1, vertexBuffer, 3, FLOAT_2);
			var indices = [0, 1, 2, 0, 2, 3];
			var indexBuffer = context3D.createIndexBuffer(6);
			indexBuffer.uploadFromVector(Vector.ofArray(indices), 0, 6);
			context3D.setVertexBufferAt(0, vertexBuffer, 0, FLOAT_3);
			context3D.setProgram(program);
			context3D.drawTriangles(indexBuffer);
		}

		// var shader = cast(this.shader, RayShader);
		// shader.setTriangleData(bmp, tris.length, [minX, minY, minZ], [sizeX, sizeY, sizeZ], [view.camX, view.camY, view.camZ], [fx, fy, fz],
		//	[right.x, right.y, right.z], [up.x, up.y, up.z]);
	}
}
