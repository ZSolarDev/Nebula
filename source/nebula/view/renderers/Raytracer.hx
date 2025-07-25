package nebula.view.renderers;

import flixel.*;
import flixel.util.FlxColor;
import haxe.Json;
import nebula.mesh.MeshPart;
import nebula.utils.Vec3DHelper;
import nebulatracer.NebulaTracer;
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

typedef Light =
{
	var pos:Vector3D;
	var color:FloatColor;
	var power:Float;
	var meshPart:MeshPart;
}

class Raytracer implements ViewRenderer extends FlxCamera
{
	public var raytracer:NebulaTracer;
	public var prog:Int;
	public var maxProg:Int;
	public var view:N3DView;
	public var geom:Array<MeshPart> = [];
	public var prevGeoms:Array<Array<MeshPart>> = [];
	public var lights:Array<Light> = [];

	public function new(view:N3DView)
	{
		super();
		super(0, 0, view.width, view.height);
		this.view = view;
		// FlxG.cameras.reset(this);
		FlxG.state.add(this);
		bgColor.alpha = 0;
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

		var normalDiff:Float = 0;
		for (i in 0...a.normals.length)
		{
			final na = a.normals[i];
			final nb = b.normals[i];
			normalDiff += Math.abs(na.x - nb.x) + Math.abs(na.y - nb.y) + Math.abs(na.z - nb.z);
		}
		normalDiff /= a.normals.length;
		var scaledNormalDiff = Math.min(normalDiff / 10.0, 1.0);

		var combined = 0.5 * scaledVertexDiff + 0.5 * indexDiffRatio + 0.5 * scaledNormalDiff;
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

	function deepCopyGeom(source:Array<MeshPart>):Array<MeshPart>
	{
		var out = [];
		for (part in source)
		{
			var copied = new MeshPart(part.vertices.copy(), part.indices.copy(), part.uvt.copy(), part.normals.copy(), part.graphic, false);
			out.push(copied);
		}
		return out;
	}

	function reflect(dir:Vector3D, normal:Vector3D):Vector3D
	{
		var dot = Vec3DHelper.dot(dir, normal);
		return Vec3DHelper.subtract(dir, Vec3DHelper.multiplyScalar(normal, 2 * dot));
	}

	function averageColors(colors:Array<FloatColor>):FloatColor
	{
		if (colors.length == 0)
			return new FloatColor(0, 0, 0);

		var rSum = 0.0;
		var gSum = 0.0;
		var bSum = 0.0;

		for (color in colors)
		{
			rSum += color.red;
			gSum += color.green;
			bSum += color.blue;
		}

		var len = colors.length;
		var rAvg = rSum / len;
		var gAvg = gSum / len;
		var bAvg = bSum / len;

		return new FloatColor(rAvg, gAvg, bAvg);
	}

	public var rendering = false;

	public function renderScene()
	{
		if (rendering)
			return;
		rendering = true;
		geom = [];
		lights = [];

		for (mesh in view.meshes)
		{
			for (meshPart in mesh.meshParts)
			{
				geom.push(meshPart);
				if (meshPart.raytracingProperties.isEmitter)
					lights = lights.concat(meshPart.raytracingProperties.lightPointers);
			}
		}

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
	}
}

class FloatColor
{
	public var red:Float;
	public var green:Float;
	public var blue:Float;

	public function new(red:Float, green:Float, blue:Float)
	{
		this.red = red;
		this.green = green;
		this.blue = blue;
	}

	public static function multiplyFloat(color:FloatColor, val:Float):FloatColor
		return new FloatColor(color.red * val, color.green * val, color.blue * val);

	public static function multiplyColor(color1:FloatColor, color2:FloatColor):FloatColor
		return new FloatColor(color1.red * color2.red, color1.green * color2.green, color1.blue * color2.blue);

	public static function addColor(color1:FloatColor, color2:FloatColor):FloatColor
		return new FloatColor(color1.red + color2.red, color1.green + color2.green, color1.blue + color2.blue);

	public static function addFloat(color1:FloatColor, val:Float):FloatColor
		return new FloatColor(color1.red + val, color1.green + val, color1.blue + val);

	public static function subtractColor(color1:FloatColor, color2:FloatColor):FloatColor
		return new FloatColor(color1.red - color2.red, color1.green - color2.green, color1.blue - color2.blue);

	public static function lerpColor(color1:FloatColor, color2:FloatColor, t:Float):FloatColor
		return new FloatColor(color1.red
			+ (color2.red - color1.red) * t, color1.green
			+ (color2.green - color1.green) * t,
			color1.blue
			+ (color2.blue - color1.blue) * t);

	public static function fromFlxColor(color:FlxColor):FloatColor
		return fromRGB(color.red, color.green, color.blue);

	public static function fromRGB(red:Int, green:Int, blue:Int):FloatColor
		return new FloatColor(red / 255, green / 255, blue / 255);
}
