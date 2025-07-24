package nebula.view.renderers;

import flixel.*;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import haxe.Json;
import nebula.mesh.MeshPart;
import nebula.mesh.datatypes.MeshJson.Vec3D;
import nebula.tonemapper.*;
import nebula.utils.Vec3DHelper;
import nebula.view.renderers.Raytracer.FloatColor;
import nebula.view.renderers.Raytracer.Geometry;
import nebula.view.renderers.Raytracer.GeometryMesh;
import nebula.view.renderers.Raytracer.GeometryMeshPart;
import nebula.view.renderers.Raytracer.Light;
import nebulatracer.NebulaTracer;
import nebulatracer.RaytracerExt.TraceResult;
import openfl.geom.Rectangle;
import openfl.geom.Vector3D;
import sys.thread.Mutex;

class RaytracerNew implements ViewRenderer extends FlxCamera
{
	public var mutex:Mutex = new Mutex();
	public var raytracer:NebulaTracer;
	public var globalIllum:FlxSprite;
	public var giRes:Int = 1;
	public var prog:Int;
	public var maxProg:Int;
	public var view:N3DView;
	public var numBounces:Int = 2;
	public var geom:Array<MeshPart> = [];
	public var prevGeoms:Array<Array<MeshPart>> = [];
	public var lights:Array<Light> = [];
	public var skyColor:FlxColor = 0x00000000;
	public var giSamples:Int = 32;
	public var tonemapper:Tonemapper = new ClampTonemapper();
	public var hemisphereRandomness = 0.1;
	public var raysPerPixel = 20;

	public function new(view:N3DView)
	{
		super();
		super(0, 0, view.width, view.height);
		this.view = view;
		// FlxG.cameras.reset(this);
		FlxG.state.add(this);
		// var bg = new FlxSprite(0, 0, FlxGraphic.fromBitmapData(new BitmapData(view.width, view.height, true, 0xFF00D9FF)));
		// bg.camera = this;
		bgColor.alpha = 0;
		globalIllum = new FlxSprite();
		globalIllum.makeGraphic(view.width, view.height, skyColor);
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

	static function getTriangleNormal(part:MeshPart, primID:Int):Vector3D
	{
		var i0 = part.indices[primID * 3];
		var i1 = part.indices[primID * 3 + 1];
		var i2 = part.indices[primID * 3 + 2];

		var v0 = part.vertices[i0];
		var v1 = part.vertices[i1];
		var v2 = part.vertices[i2];

		var edge1 = Vec3DHelper.subtract(v1, v0);
		var edge2 = Vec3DHelper.subtract(v2, v0);

		var normal = Vec3DHelper.cross(edge1, edge2);
		return Vec3DHelper.normalize(normal);
	}

	public function pixelToWorld(x:Float, y:Float):Ray
	{
		final fov = view.fov;
		final aspectRatio = view.width / view.height;

		var ndcX = (2 * x) / view.width - 1;
		var ndcY = (2 * y) / view.height - 1;

		var fovRad = Math.PI * fov / 180;
		var tanFov = Math.tan(fovRad / 2);

		var camX = ndcX * aspectRatio * tanFov;
		var camY = ndcY * tanFov;
		var camZ = -1;

		var dir = new Vector3D(camX, camY, camZ);
		dir.normalize();

		var yaw = view.camYaw;
		var pitch = view.camPitch;

		// --- Apply Pitch (X axis) ---
		var cosPitch = Math.cos(pitch);
		var sinPitch = Math.sin(pitch);

		var y1 = dir.y * cosPitch - dir.z * sinPitch;
		var z1 = dir.y * sinPitch + dir.z * cosPitch;
		var x1 = dir.x;

		// --- Apply Yaw (Y axis) after pitch ---
		var cosYaw = Math.cos(yaw);
		var sinYaw = Math.sin(yaw);

		var x2 = x1 * cosYaw - z1 * sinYaw;
		var z2 = x1 * sinYaw + z1 * cosYaw;

		dir.setTo(x2, y1, z2);
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

	function randomGaussian()
	{
		var theta:Float = 2 * 3.1415926 * Math.random();
		var rho:Float = Math.sqrt(-2 * Math.log(Math.random()));
		return rho * Math.cos(theta);
	}

	function randomDirection():Vector3D
	{
		var x = randomGaussian();
		var y = randomGaussian();
		var z = randomGaussian();
		return Vec3DHelper.normalize(new Vector3D(x, y, z));
	}

	function generateHemisphereDirection(normal:Vector3D):Vector3D
	{
		var dir:Vector3D = randomDirection();
		return Vec3DHelper.multiplyScalar(dir, cast FlxMath.signOf(Vec3DHelper.dot(normal, dir)));
	}

	public function traceRay(ray:Ray):FloatColor
	{
		var color:FloatColor = new FloatColor(1, 1, 1);
		var incomingLight:FloatColor = new FloatColor(0, 0, 0);

		for (i in 0...numBounces)
		{
			var res:TraceResult = raytracer.traceRay(ray);
			if (res.hit)
			{
				var part = geom[res.geomID];
				ray.pos = Vec3DHelper.add(ray.pos, Vec3DHelper.multiplyScalar(ray.dir, res.distance));
				ray.dir = generateHemisphereDirection(getTriangleNormal(part, res.primID));
				var material = part.raytracingProperties;
				var emittedLight = FloatColor.multiplyFloat(FloatColor.fromFlxColor(part.color), material.emissiveness);
				incomingLight = FloatColor.addColor(incomingLight, FloatColor.multiplyColor(emittedLight, color));
				color = FloatColor.multiplyColor(color, FloatColor.fromFlxColor(part.color));
			}
			else
				break;
		}

		return incomingLight;
	}

	public var rendering = false;

	public function renderScene()
	{
		if (rendering)
			return;
		rendering = true;
		geom = [];
		lights = [];
		globalIllum.pixels.fillRect(new Rectangle(0, 0, view.width, view.height), skyColor);

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

		prog = 0;
		var colors = [];
		{
			for (y in 0...view.height)
			{
				if (y % giRes != 0)
					continue;

				for (x in 0...view.width)
				{
					if (x % giRes != 0)
						continue;

					var ray = pixelToWorld(x, y);
					var color:FloatColor = new FloatColor(0, 0, 0);
					for (rayIndex in 0...raysPerPixel)
						color = FloatColor.addColor(color, traceRay(ray));
					color = FloatColor.multiplyFloat(color, 1.0 / raysPerPixel);
					var finalColor = tonemapper.map(color);
					finalColor.alpha = 255;
					globalIllum.pixels.fillRect(new Rectangle(x, y, giRes, giRes), finalColor);
					prog++;
				}
			}
		}
		rendering = false;
	}
}
