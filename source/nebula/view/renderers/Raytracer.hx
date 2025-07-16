package nebula.view.renderers;

import flixel.*;
import haxe.Json;
import lime.math.Vector2;
import lime.utils.Log;
import nebula.mesh.MeshPart;
import nebulatracer.NebulaTracer.NTracerEngine;
import nebulatracer.NebulaTracer;
import openfl.geom.Rectangle;
import openfl.geom.Vector3D;

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

class Raytracer implements ViewRenderer extends FlxSprite
{
	public var view:N3DView;
	public var raytracer:NebulaTracer;
	// public var numBounces:Int = 3; bounces later..
	public var geom:Array<MeshPart> = [];
	public var prevGeoms:Array<Array<MeshPart>> = [];
	public var bvhThreshold:Float = 35;

	public function new(view:N3DView, ?raytracerEngine:NTracerEngine = EMBREE)
	{
		super();
		this.view = view;
		FlxG.state.add(this);
		makeGraphic(view.width, view.height, 0x00D9FF);
		raytracer = new NebulaTracer(raytracerEngine);
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

	function pixelToWorld(x:Float, y:Float):Ray
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

	public function render()
	{
		geom = [];
		pixels.fillRect(new Rectangle(0, 0, view.width, view.height), 0x00000000);

		for (mesh in view.meshes)
			for (meshPart in mesh.meshParts)
				geom.push(meshPart);

		if (prevGeoms.length != 0)
		{
			if (geom != prevGeoms[prevGeoms.length - 1])
			{
				final oldGeom = prevGeoms[0];
				final change = compareGeoms(oldGeom, geom);

				if (change >= bvhThreshold)
				{
					Log.info('Rebuilding BVH (Change: $change%)');
					raytracer.geometry = jsonifyGeom();
					raytracer.rebuildBVH();
				}
				else
				{
					if (change > 0)
					{
						Log.info('Refitting BVH (Change: $change%)');
						raytracer.geometry = jsonifyGeom();
						raytracer.refitBVH();
					}
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

		// TODO: Fix this Once OptiX and DXR are implemented
		// var rays:Array<{ray:Ray, screenPos:Vector2}> = [];
		// var rayMap:Map<Int, Ray> = new Map();
		// for (y in 0...view.height)
		// for (x in 0...view.width)
		// rays.push({ray: pixelToWorld(x, y), screenPos: new Vector2(x, y)});
		// for (i in 0...rays.length)
		// rayMap.set(i, rays[i].ray);
		// raytracer.traceRays(rayMap, (res) ->
		// {
		// var ray = rays[res.index];
		// if (res.hit)
		// pixels.setPixel32(cast ray.screenPos.x, cast ray.screenPos.y, geom[res.geomID].color);
		// else
		// pixels.setPixel32(cast ray.screenPos.x, cast ray.screenPos.y, 0xFF00D9FF);
		// });
		for (y in 0...view.height)
		{
			for (x in 0...view.width)
			{
				var ray = pixelToWorld(x, y);
				var res = raytracer.traceRay(ray);
				if (res.hit)
				{
					var part = geom[res.geomID];
					pixels.setPixel32(cast x, cast y, part.color);
				}
				else
				{
					pixels.setPixel32(cast x, cast y, 0xFF00D9FF);
				}
			}
		}
	}
}
