package nebula.view.renderers;

import flixel.*;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import haxe.Json;
import hlwnative.HLApplicationStatus;
import lime.math.Vector2;
import lime.utils.Log;
import nebula.mesh.MeshPart;
import nebula.utils.Vec3DHelper;
import nebulatracer.NebulaTracer;
import nebulatracer.RaytracerExt.TraceResult;
import openfl.display.BitmapData;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.geom.Vector3D;
import sys.FileSystem;
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

typedef Light =
{
	var pos:Vector3D;
	var color:FlxColor;
	var power:Float;
}

class Raytracer implements ViewRenderer extends FlxCamera
{
	public var mutex:Mutex = new Mutex();
	public var raytracer:NebulaTracer;
	public var globalIllum:FlxSprite;
	public var giRes:Int = 1;
	public var prog:Int;
	public var maxProg:Int;
	public var view:N3DView;
	public var numBounces:Int = 1;
	public var geom:Array<MeshPart> = [];
	public var prevGeoms:Array<Array<MeshPart>> = [];
	public var lights:Array<Light> = [];
	public var skyColor:FlxColor = 0x00000000;
	public var giSamples:Int = 32;

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

		// --- Apply Pitch (X axis) FIRST ---
		var cosPitch = Math.cos(pitch);
		var sinPitch = Math.sin(pitch);

		var y1 = dir.y * cosPitch - dir.z * sinPitch;
		var z1 = dir.y * sinPitch + dir.z * cosPitch;
		var x1 = dir.x;

		// --- Apply Yaw (Y axis) AFTER pitch ---
		var cosYaw = Math.cos(yaw);
		var sinYaw = Math.sin(yaw);

		var x2 = x1 * cosYaw - z1 * sinYaw;
		var z2 = x1 * sinYaw + z1 * cosYaw;

		dir.setTo(x2, y1, z2);
		dir.normalize();

		var ray:Ray = {
			pos: new Vector3D(view.camX, view.camY, view.camZ),
			dir: dir,
			energy: 1
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

	public function traceRay(ray:Ray):{hit:Bool, color:FlxColor}
	{
		var color:FlxColor = 0x000000;
		var res:TraceResult = raytracer.traceRay(ray);
		if (res.hit)
		{
			var part = geom[res.geomID];
			var hitPos = Vec3DHelper.add(ray.pos, Vec3DHelper.scale(ray.dir, res.distance));

			for (light in lights)
			{
				var toLight = Vec3DHelper.subtract(light.pos, hitPos);
				var dirToLight = Vec3DHelper.normalize(toLight);
				var shadowRay:Ray = {
					pos: Vec3DHelper.add(hitPos, Vec3DHelper.scale(dirToLight, 0.001)),
					dir: dirToLight,
					energy: 1
				};

				var shadowRes = raytracer.traceRay(shadowRay);
				if (shadowRes.geomID == -1)
				{
					var diff = Vec3DHelper.subtract(light.pos, shadowRay.pos);
					var distFalloff = 1.0 - (diff.length / light.power);
					distFalloff = Math.max(0, distFalloff);
					var shadowStrength = 1.0 - distFalloff;
					var darkenedSkyColor = multiplyColorBrightness(skyColor, shadowStrength * 0.1);
					var finalPartColor = FlxColor.interpolate(part.color, darkenedSkyColor, shadowStrength * 0.9);
					color += FlxColor.interpolate(finalPartColor, light.color, distFalloff * 0.5);
				}
			}

			for (bounce in 0...numBounces)
			{
				var triIndex = res.primID;
				var i0 = part.indices[triIndex * 3];
				var i1 = part.indices[triIndex * 3 + 1];
				var i2 = part.indices[triIndex * 3 + 2];

				var v0 = part.vertices[i0];
				var v1 = part.vertices[i1];
				var v2 = part.vertices[i2];

				var edge1 = Vec3DHelper.subtract(v1, v0);
				var edge2 = Vec3DHelper.subtract(v2, v0);
				var normal = Vec3DHelper.normalize(Vec3DHelper.cross(edge1, edge2));
				var reflectedRay:Ray = {
					pos: hitPos,
					dir: normal,
					energy: 1
				};
				var reflectedTrace:TraceResult = raytracer.traceRay(reflectedRay);
				if (reflectedTrace.hit)
				{
					var partColor:FlxColor = geom[reflectedTrace.geomID].color;
					partColor.brightness -= bounce / numBounces;
					color = FlxColor.interpolate(color, partColor, 0.5);
				}
				else
				{
					var finalSkyColor:FlxColor = skyColor;
					finalSkyColor.brightness -= bounce / numBounces;
					color = FlxColor.interpolate(color, finalSkyColor, 0.5);
				}
			}

			return {hit: true, color: color};
		}
		else
			return {hit: false, color: skyColor};
	}

	function averageColors(colors:Array<FlxColor>):FlxColor
	{
		if (colors.length == 0)
			return 0;

		var rSum = 0;
		var gSum = 0;
		var bSum = 0;

		for (color in colors)
		{
			rSum += color.red;
			gSum += color.green;
			bSum += color.blue;
		}

		var len = colors.length;
		var rAvg = Std.int(rSum / len);
		var gAvg = Std.int(gSum / len);
		var bAvg = Std.int(bSum / len);

		return FlxColor.fromRGB(rAvg, gAvg, bAvg);
	}

	public var rendering = false;

	public function renderScene()
	{
		if (rendering)
			return;
		rendering = true;
		geom = [];
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

		prog = 0;
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
					var finalColor = FlxColor.BLACK;
					var res = traceRay(ray);
					finalColor = res.color;
					finalColor.alpha = 255;
					globalIllum.pixels.fillRect(new Rectangle(x, y, giRes, giRes), finalColor);
					prog++;
				}
			}
		}
		rendering = false;
	}

	function multiplyColorBrightness(color:FlxColor, brightness:Float):FlxColor
		return FlxColor.fromRGB(Std.int(color.red * brightness), Std.int(color.green * brightness), Std.int(color.blue * brightness));
}
