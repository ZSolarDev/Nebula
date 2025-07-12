package;

import flixel.*;
import flixel.util.FlxColor;
import haxe.Timer;
import nebula.mesh.*;
import nebula.view.*;
import nebula.view.renderers.*;
import openfl.Vector;
import openfl.geom.Vector3D;
import sys.thread.Thread;

class PlayState extends FlxState
{
	var cpuRaytracer:CPURaytracer;
	var view:N3DView;

	override public function create():Void
	{
		super.create();
		view = new N3DView(FlxG.width, FlxG.height, GPURaytracer);
		add(view);
		cpuRaytracer = new CPURaytracer(view);
		// initializeScene();
		var part = new MeshPart(new Vector<Vector3D>(), new Vector<Int>(), new Vector<Float>(), '');
		part.color = 0xFFFFFFFF;
		part.vertices.push(new Vector3D(-50, -50, 0));
		part.vertices.push(new Vector3D(50, -50, 0));
		part.vertices.push(new Vector3D(0, 50, 0));

		part.indices.push(0);
		part.indices.push(1);
		part.indices.push(2);

		part.uvt.push(0);
		part.uvt.push(0);
		part.uvt.push(1);
		part.uvt.push(0);
		part.uvt.push(0.5);
		part.uvt.push(1);

		var mesh = new Mesh(0, 0, -300, [part]);
		view.pushMesh(mesh);
	}

	function initializeScene()
	{
		view.camX = -142.09870267358;
		view.camY = -186.576563254764;
		view.camZ = 246.719622723706;
		view.camPitch = 0.605;
		view.camYaw = 0.45;

		var floorParts = createCheckerFloor(8, 40);
		view.pushMesh(new Mesh(0, 0, 0, floorParts));

		// Spheres
		var radius = 20;
		var redSphere = createSphereMesh(-80, -radius, 20, radius, FlxColor.RED, 30, 30);
		var greenSphere = createSphereMesh(0, -radius, 20, radius, FlxColor.GREEN, 30, 30);
		var blueSphere = createSphereMesh(80, -radius, 20, radius, FlxColor.BLUE, 30, 30);

		view.pushMesh(new Mesh(0, 0, 1, [redSphere, greenSphere, blueSphere]));

		// Sun sphere
		var sun = createSphereMesh(0, -150, -150, 30, FlxColor.YELLOW, 30, 30);
		view.pushMesh(new Mesh(0, 0, 1, [sun]));
	}

	function createSphereMesh(x:Float, y:Float, z:Float, radius:Float, color:Int, latSteps:Int = 6, lonSteps:Int = 6):MeshPart
	{
		var part = new MeshPart(new Vector<Vector3D>(), new Vector<Int>(), new Vector<Float>(), '');
		part.color = color;

		for (lat in 0...latSteps + 1)
		{
			var theta = Math.PI * lat / latSteps;
			var sinTheta = Math.sin(theta);
			var cosTheta = Math.cos(theta);

			for (lon in 0...lonSteps + 1)
			{
				var phi = 2 * Math.PI * lon / lonSteps;
				var sinPhi = Math.sin(phi);
				var cosPhi = Math.cos(phi);

				var px = x + radius * sinTheta * cosPhi;
				var py = y + radius * cosTheta;
				var pz = z + radius * sinTheta * sinPhi;

				part.vertices.push(new Vector3D(px, py, pz));
			}
		}

		var vertsPerRow = lonSteps + 1;
		for (lat in 0...latSteps)
		{
			for (lon in 0...lonSteps)
			{
				var a = lat * vertsPerRow + lon;
				var b = a + vertsPerRow;

				part.indices.push(a);
				part.indices.push(b);
				part.indices.push(a + 1);

				part.indices.push(b);
				part.indices.push(b + 1);
				part.indices.push(a + 1);
			}
		}

		return part;
	}

	function createCheckerFloor(size:Int, tileSize:Float):Array<MeshPart>
	{
		var parts = [];
		var half:Int = cast size / 2;

		for (i in -half...half)
		{
			for (j in -half...half)
			{
				var x = i * tileSize;
				var y = j * tileSize;
				var color = ((i + j) % 2 == 0) ? FlxColor.WHITE : FlxColor.BLACK;

				var part = new MeshPart(new Vector<Vector3D>(), new Vector<Int>(), new Vector<Float>(), '');
				part.color = color;

				part.vertices.push(new Vector3D(x, 0, y));
				part.vertices.push(new Vector3D(x + tileSize, 0, y));
				part.vertices.push(new Vector3D(x + tileSize, 0, y + tileSize));
				part.vertices.push(new Vector3D(x, 0, y + tileSize));

				// Two triangles
				part.indices.push(0);
				part.indices.push(1);
				part.indices.push(2);
				part.indices.push(0);
				part.indices.push(2);
				part.indices.push(3);

				parts.push(part);
			}
		}
		return parts;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var threaded = true;
		if (FlxG.keys.pressed.ENTER)
		{
			cpuRaytracer.visible = true;
			if (threaded)
				Thread.create(() ->
				{
					var start = Timer.stamp();
					cpuRaytracer.render();
					var end = Timer.stamp();
					trace('Render time: ${end - start}');
				});
			else
				cpuRaytracer.render();
		}
		if (FlxG.keys.pressed.ESCAPE)
			cpuRaytracer.visible = false;
	}
}
