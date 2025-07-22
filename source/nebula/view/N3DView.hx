package nebula.view;

import flixel.*;
import lime.utils.Log;
import nebula.mesh.*;
import nebula.view.renderers.ViewRenderer;
import openfl.Vector;
import openfl.geom.Vector3D;
import sys.thread.Thread;

typedef ClippingVertex =
{
	var pos:Vector3D;
	var u:Float;
	var v:Float;
	var invZ:Float;
	var meshPart:MeshPart;
}

typedef TransformedMesh =
{
	var mesh:MeshPart;
	var verts:Vector<Float>;
	var indices:Vector<Int>;
}

class N3DView extends FlxBasic
{
	public var renderer:ViewRenderer;
	public var render:Bool = true;
	public var meshes:Array<Mesh> = [];
	public var camSpaceTris:Array<Array<ClippingVertex>> = [];
	public var fov:Float;
	public var nearPlane:Float = 1;
	public var farPlane:Float = 100000;
	public var aspect:Float = 1;
	public var camX:Float = 0;
	public var camY:Float = 0;
	public var camZ:Float = 0;
	public var camYaw:Float = 0;
	public var camPitch:Float = 0;
	public var width:Int;
	public var height:Int;
	public var projectionMatrix(get, never):Array<Float>;
	public var projectedMeshes:Array<ProjectionMesh> = [];

	public function new(width:Int, height:Int, renderer:Class<ViewRenderer>, fov:Float = 70, aspect:Float = 0, nearPlane:Float = 0.1, farPlane:Float = 100000)
	{
		super();
		this.width = width;
		this.height = height;
		this.renderer = Type.createInstance(renderer, [this]);
		this.fov = fov;
		if (aspect == 0)
			aspect = width / height;
		this.aspect = aspect;
		this.nearPlane = nearPlane;
		this.farPlane = farPlane;
	}

	public function pushMesh(mesh:Mesh)
	{
		meshes.push(mesh);
	}

	function project(v:Vector3D):Vector<Float>
	{
		var x = v.x, y = v.y, z = v.z;

		var projectionMatrix = this.projectionMatrix;
		var px = x * projectionMatrix[0] + y * projectionMatrix[4] + z * projectionMatrix[8] + projectionMatrix[12];
		var py = x * projectionMatrix[1] + y * projectionMatrix[5] + z * projectionMatrix[9] + projectionMatrix[13];
		var pz = x * projectionMatrix[2] + y * projectionMatrix[6] + z * projectionMatrix[10] + projectionMatrix[14];
		var pw = x * projectionMatrix[3] + y * projectionMatrix[7] + z * projectionMatrix[11] + projectionMatrix[15];

		px /= pw;
		py /= pw;
		pz /= pw;

		// Convert NDC to screen space
		var sx = (px + 1) * 0.5 * width;
		var sy = (py + 1) * 0.5 * height;

		return new Vector(4, false, [sx, sy, pz, pw]);
	}

	function get_projectionMatrix():Array<Float>
	{
		var fovRadians = fov * Math.PI / 180;
		var f = 1.0 / Math.tan(fovRadians / 2);
		var nf = 1 / (nearPlane - farPlane);

		return [
			f / aspect, 0,                               0,  0,
			         0, f,                               0,  0,
			         0, 0,     (farPlane + nearPlane) * nf, -1,
			         0, 0, (2 * farPlane * nearPlane) * nf,  0
		];
	}

	function applyRotation(v:Vector3D, yaw:Float, pitch:Float, roll:Float):Vector3D
	{
		var x = v.x;
		var y = v.y;
		var z = v.z;

		// yaw (y axis)
		var cosy = Math.cos(yaw);
		var siny = Math.sin(yaw);
		var x1 = x * cosy - z * siny;
		var z1 = x * siny + z * cosy;
		var y1 = y;

		// pitch (x axis)
		var cosp = Math.cos(pitch);
		var sinp = Math.sin(pitch);
		var y2 = y1 * cosp - z1 * sinp;
		var z2 = y1 * sinp + z1 * cosp;
		var x2 = x1;

		// roll (z axis)
		var cosr = Math.cos(roll);
		var sinr = Math.sin(roll);
		var x3 = x2 * cosr - y2 * sinr;
		var y3 = x2 * sinr + y2 * cosr;
		var z3 = z2;

		return new Vector3D(x3, y3, z3);
	}

	override public function update(elapsed:Float)
	{
		camSpaceTris = [];
		super.update(elapsed);

		// --- camera Movement ---
		var speed = 100 * elapsed;

		// get forward vector including pitch and yaw
		var forwardX = Math.sin(-camYaw) * Math.cos(-camPitch);
		var forwardY = -Math.sin(camPitch);
		var forwardZ = Math.cos(-camYaw) * Math.cos(-camPitch);

		// right vector on XZ plane only (pitch ignored for strafing)
		var rightX = -Math.cos(-camYaw);
		var rightZ = Math.sin(-camYaw);

		// movement deltas
		var dx = 0.0;
		var dy = 0.0;
		var dz = 0.0;

		if (FlxG.keys.pressed.W)
		{
			dx -= forwardX;
			dy -= forwardY;
			dz -= forwardZ;
		}
		if (FlxG.keys.pressed.S)
		{
			dx += forwardX;
			dy += forwardY;
			dz += forwardZ;
		}
		if (FlxG.keys.pressed.D)
		{
			dx -= rightX;
			dz -= rightZ;
		}
		if (FlxG.keys.pressed.A)
		{
			dx += rightX;
			dz += rightZ;
		}

		// normalize to prevent faster diagonal movement
		var length = Math.sqrt(dx * dx + dy * dy + dz * dz);
		if (length > 0)
		{
			dx /= length;
			dy /= length;
			dz /= length;

			camX += dx * speed;
			camY += dy * speed;
			camZ += dz * speed;
		}

		// y movement independent from yaw
		if (FlxG.keys.pressed.SPACE)
			camY -= speed;
		if (FlxG.keys.pressed.SHIFT)
			camY += speed;

		// --- camera rotation ---
		if (FlxG.mouse.pressed)
		{
			camYaw += FlxG.mouse.deltaX * 0.005;
			camPitch += FlxG.mouse.deltaY * 0.005;
			camPitch = Math.max(Math.min(camPitch, Math.PI / 2), -Math.PI / 2);
		}

		// --- projection ---
		projectedMeshes = [];

		for (mesh in meshes)
		{
			for (meshPart in mesh.meshParts)
			{
				var cx = 0.0;
				var cy = 0.0;
				var cz = 0.0;
				for (v in meshPart.vertices)
				{
					cx += v.x;
					cy += v.y;
					cz += v.z;
				}
				cx /= meshPart.vertices.length;
				cy /= meshPart.vertices.length;
				cz /= meshPart.vertices.length;

				var centerWorld = new Vector3D(cx + mesh.x, cy + mesh.y, cz + mesh.z);
				var relCenter = new Vector3D(centerWorld.x - camX, centerWorld.y - camY, centerWorld.z - camZ);
				var camSpaceCenter = applyRotation(relCenter, -camYaw, -camPitch, 0);

				var pm:ProjectionMesh = {
					mesh: meshPart,
					meshPos: new Vector3D(mesh.x, mesh.y, mesh.z),
					verts: new Vector<Float>(),
					uvt: new Vector<Float>(),
					indices: new Vector<Int>(),
					camZ: camSpaceCenter.z
				};

				var indices = meshPart.indices;
				var verts = meshPart.vertices;

				for (i in 0...cast indices.length / 3)
				{
					var idx0 = indices[i * 3];
					var idx1 = indices[i * 3 + 1];
					var idx2 = indices[i * 3 + 2];

					var local0 = new Vector3D(verts[idx0].x - cx, verts[idx0].y - cy, verts[idx0].z - cz);
					var local1 = new Vector3D(verts[idx1].x - cx, verts[idx1].y - cy, verts[idx1].z - cz);
					var local2 = new Vector3D(verts[idx2].x - cx, verts[idx2].y - cy, verts[idx2].z - cz);

					local0.x *= mesh.scaleX;
					local0.y *= mesh.scaleY;
					local0.z *= mesh.scaleZ;

					local1.x *= mesh.scaleX;
					local1.y *= mesh.scaleY;
					local1.z *= mesh.scaleZ;

					local2.x *= mesh.scaleX;
					local2.y *= mesh.scaleY;
					local2.z *= mesh.scaleZ;

					// rotate local by mesh rotation
					var rotated0 = applyRotation(local0, mesh.yaw, mesh.pitch, mesh.roll);
					var rotated1 = applyRotation(local1, mesh.yaw, mesh.pitch, mesh.roll);
					var rotated2 = applyRotation(local2, mesh.yaw, mesh.pitch, mesh.roll);

					// move back to mesh position in world space
					rotated0.x += cx + mesh.x;
					rotated0.y += cy + mesh.y;
					rotated0.z += cz + mesh.z;

					rotated1.x += cx + mesh.x;
					rotated1.y += cy + mesh.y;
					rotated1.z += cz + mesh.z;

					rotated2.x += cx + mesh.x;
					rotated2.y += cy + mesh.y;
					rotated2.z += cz + mesh.z;

					// transform to camera space: translate by inverse camera position
					var rel0 = new Vector3D(rotated0.x - camX, rotated0.y - camY, rotated0.z - camZ);
					var rel1 = new Vector3D(rotated1.x - camX, rotated1.y - camY, rotated1.z - camZ);
					var rel2 = new Vector3D(rotated2.x - camX, rotated2.y - camY, rotated2.z - camZ);

					// rotate by inverse camera rotation
					var camSpace0 = applyRotation(rel0, -camYaw, -camPitch, 0);
					var camSpace1 = applyRotation(rel1, -camYaw, -camPitch, 0);
					var camSpace2 = applyRotation(rel2, -camYaw, -camPitch, 0);

					var v0:ClippingVertex = {
						pos: new Vector3D(camSpace0.x, camSpace0.y, camSpace0.z, 1),
						u: meshPart.uvt[idx0 * 2],
						v: meshPart.uvt[idx0 * 2 + 1],
						invZ: 1 / -camSpace0.z,
						meshPart: meshPart
					};
					var v1:ClippingVertex = {
						pos: new Vector3D(camSpace1.x, camSpace1.y, camSpace1.z, 1),
						u: meshPart.uvt[idx1 * 2],
						v: meshPart.uvt[idx1 * 2 + 1],
						invZ: 1 / -camSpace1.z,
						meshPart: meshPart
					};
					var v2:ClippingVertex = {
						pos: new Vector3D(camSpace2.x, camSpace2.y, camSpace2.z, 1),
						u: meshPart.uvt[idx2 * 2],
						v: meshPart.uvt[idx2 * 2 + 1],
						invZ: 1 / -camSpace2.z,
						meshPart: meshPart
					};

					var triangle = [v0, v1, v2];
					camSpaceTris.push(triangle);
					var skip = false;
					for (i in 0...3) // URGENT: implement proper vertex clipping
					{
						var projected = project(triangle[i].pos);
						if (triangle[i].pos.z > -50 || projected[3] < 0.01)
						{
							skip = true;
							break;
						}
					}
					if (skip)
						continue;

					var baseIdx = Std.int(pm.verts.length / 2);
					for (i in 0...3)
					{
						var cv:ClippingVertex = triangle[i];
						if (cv.pos.z > -nearPlane)
							cv.pos.z = -nearPlane - 0.001;
						var p = project(cv.pos);

						pm.verts.push(p[0]);
						pm.verts.push(p[1]);
						pm.uvt.push(cv.u);
						pm.uvt.push(cv.v);
						pm.uvt.push(1);

						pm.indices.push(baseIdx + i);
					}
				}

				projectedMeshes.push(pm);
			}
		}
		if (render)
			renderView(elapsed);
	}

	public function renderView(elapsed:Float)
	{
		if (renderer != null)
			renderer.renderScene();
		else
			Log.warn('A renderer for this N3DView was not provided, failed to render.');
	}
}
