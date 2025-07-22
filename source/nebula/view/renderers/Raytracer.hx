package nebula.view.renderers;

import flixel.*;
import haxe.Json;
import hlwnative.HLApplicationStatus;
import lime.math.Vector2;
import lime.utils.Log;
import nebula.mesh.MeshPart;
import nebulatracer.NebulaTracer;
import openfl.display.BitmapData;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.geom.Vector3D;
import sys.thread.Mutex;
import sys.thread.Thread;

typedef Geometry =
{
	var geometry:Array<GeometryMesh>;
}

typedef GeometryMesh =
{
	var meshParts:Array<GeometryMeshPart>;
}

typedef GeometryMeshPart =
{
	var indices:Array<Int>;
	var vertices:Array<Float>;
}

class Raytracer implements ViewRenderer extends FlxCameraRenderer
{
	public var mutex:Mutex = new Mutex();
	public var raytracer:NebulaTracer;
	public var globalIllum:FlxSprite;
	public var giRes:Int = 10;
	// public var numBounces:Int = 3; bounces later..
	public var geom:Array<MeshPart> = [];
	public var prevGeoms:Array<Array<MeshPart>> = [];

	public function new(view:N3DView)
	{
		super(view);
		globalIllum = new FlxSprite();
		globalIllum.makeGraphic(view.width, view.height, 0x00D9FF);
		FlxG.state.add(globalIllum);
		raytracer = new NebulaTracer();
	}

	function jsonifyGeom():String
	{
		var geometry:Geometry = {
			geometry: []
		}
		for (mesh in view.meshes)
		{
			var geometryMesh:GeometryMesh = {
				meshParts: []
			}
			for (meshPart in mesh.meshParts)
			{
				var indices = [];
				for (index in meshPart.indices)
					indices.push(index);
				var vertices = [];
				for (vertex in meshPart.vertices)
				{
					vertices.push(vertex.x);
					vertices.push(vertex.y);
					vertices.push(vertex.z);
				}
				var geometryMeshPart:GeometryMeshPart = {
					indices: indices,
					vertices: vertices
				}
				geometryMesh.meshParts.push(geometryMeshPart);
			}
			geometry.geometry.push(geometryMesh);
		}
		return Json.stringify(geometry);
	}

	function compareMeshParts(a:MeshPart, b:MeshPart):Float
	{
		if (a.vertices.length != b.vertices.length || a.indices.length != b.indices.length)
			return 1;

		var vertexDiff:Float = 0;
		for (i in 0...a.vertices.length)
		{
			final va = a.vertices[i];
			final vb = b.vertices[i];
			vertexDiff += Math.abs(va.x - vb.x) + Math.abs(va.y - vb.y) + Math.abs(va.z - vb.z);
		}
		vertexDiff /= a.vertices.length;
		var scaledVertexDiff = Math.min(vertexDiff / 10.0, 1.0);

		var indexDiff:Int = 0;
		for (i in 0...a.indices.length)
		{
			if (a.indices[i] != b.indices[i])
				indexDiff++;
		}
		var indexDiffRatio = indexDiff / a.indices.length;

		var combined = 0.5 * scaledVertexDiff + 0.5 * indexDiffRatio;
		return Math.min(combined, 1.0);
	}

	function compareGeoms(a:Array<MeshPart>, b:Array<MeshPart>):Float
	{
		if (a.length == 0 && b.length == 0)
			return 0;

		var total:Float = 0;
		var maxCount:Int = cast Math.max(a.length, b.length);
		for (i in 0...maxCount)
		{
			if (i >= a.length || i >= b.length)
			{
				total += 1;
				continue;
			}

			final partA = a[i];
			final partB = b[i];

			var diff = compareMeshParts(partA, partB);
			if (diff >= 0.2)
				total += diff;
		}

		return (total / maxCount) * 100;
	}

	public function pixelToWorld(x:Float, y:Float):Ray
	{
		final fov = view.fov;
		final aspectRatio = view.width / view.height;

		var ndcX = (2 * x) / view.width - 1;
		var ndcY = 1 - (2 * y) / view.height;

		var fovRad = Math.PI * fov / 180;
		var tanFov = Math.tan(fovRad / 2);

		var camX = ndcX * aspectRatio * tanFov;
		var camY = ndcY * tanFov;
		var camZ = -1;

		var dir = new Vector3D(camX, camY, camZ);
		dir.normalize();

		// Apply pitch and yaw to dir (order: yaw then pitch)
		var yaw = view.camYaw * Math.PI / 180;
		var pitch = view.camPitch * Math.PI / 180;

		var cosPitch = Math.cos(pitch);
		var sinPitch = Math.sin(pitch);
		var cosYaw = Math.cos(yaw);
		var sinYaw = Math.sin(yaw);

		var dx = dir.x * cosYaw + dir.z * sinYaw;
		var dy = dir.x * sinYaw * sinPitch + dir.y * cosPitch - dir.z * cosYaw * sinPitch;
		var dz = -dir.x * sinYaw * cosPitch + dir.y * sinPitch + dir.z * cosYaw * cosPitch;

		dir.setTo(dx, dy, dz);
		dir.normalize();

		var ray:Ray = {
			pos: new Vector3D(view.camX, view.camY, view.camZ),
			dir: dir
		};
		return ray;
	}

	function deepCopyGeom(source:Array<MeshPart>):Array<MeshPart>
	{
		var out = [];
		for (part in source)
		{
			var copied = new MeshPart(part.vertices.copy(), part.indices.copy(), part.uvt.copy(), part.graphic, false);
			out.push(copied);
		}
		return out;
	}

	var rendering = false;

	override public function render()
	{
		super.render();
	}

	override public function draw()
	{
		if (rendering)
			return;
		rendering = true;
		super.draw(); // do rasterization, init depth buffer, normal buffer, etc. before GI
		geom = [];
		globalIllum.pixels.fillRect(new Rectangle(0, 0, view.width, view.height), 0x00000000);

		for (mesh in view.meshes)
			for (meshPart in mesh.meshParts)
				geom.push(meshPart);

		if (prevGeoms.length != 0)
		{
			if (geom != prevGeoms[prevGeoms.length - 1])
			{
				final oldGeom = prevGeoms[0];
				final change = compareGeoms(oldGeom, geom);

				if (change > 0)
				{
					Log.info('Rebuilding BVH (Change: $change%)');
					raytracer.geometry = jsonifyGeom();
					raytracer.rebuildBVH();
				}

				prevGeoms.shift(); // remove oldest
			}
		}
		else
		{
			raytracer.geometry = jsonifyGeom();
			raytracer.buildBVH();
		}
		// keep a history of the last 20 geoms to detect if theres a big enough change to rebuild the bvh
		if (prevGeoms.length < 20)
			prevGeoms.push(deepCopyGeom(geom));

		var completed:Bool = false;
		var output:Array<
			{
				ray:Ray,
				hit:Bool,
				geomID:Int,
				dist:Float,
				screenPos:Vector2
			}> = [];
		Thread.create(() ->
		{
			var results:Array<
				{
					ray:Ray,
					hit:Bool,
					geomID:Int,
					dist:Float,
					screenPos:Vector2
				}> = [];
			var giRes = giRes;
			for (y in 0...view.height)
			{
				if (y % giRes != 0)
					continue;

				for (x in 0...view.width)
				{
					if (x % giRes != 0)
						continue;

					var ray = pixelToWorld(x, y);
					mutex.acquire();
					var res = raytracer.traceRay(ray);
					mutex.release();
					if (res.hit)
					{
						mutex.acquire();
						var part = geom[res.geomID];
						globalIllum.pixels.lock();
						globalIllum.pixels.fillRect(new Rectangle(x, y, giRes, giRes), part.color);
						globalIllum.pixels.unlock();
						mutex.release();
					}
					else
					{
						mutex.acquire();
						globalIllum.pixels.fillRect(new Rectangle(x, y, giRes, giRes), 0xFF00D9FF);
						mutex.release();
					}
					results.push({
						ray: ray,
						hit: res.hit,
						geomID: res.geomID,
						dist: res.dist,
						screenPos: new Vector2(x, y)
					});
				}
			}
			mutex.acquire();
			output = results;
			completed = true;
			mutex.release();
		});
		while (!completed)
			Sys.sleep(0.001);
		rendering = false;
	}
}
