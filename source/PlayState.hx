package;

import flixel.*;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Timer;
import nebula.mesh.*;
import nebula.view.*;
import nebula.view.renderers.*;
import openfl.Vector;
import openfl.geom.Vector3D;
import sys.thread.Thread;

using StringTools;

class PlayState extends FlxState
{
	var cpuRaytracer:Raytracer;
	var separated:Bool = false;
	var view:N3DView;
	var controls:FlxText;
	var cam:FlxCamera;

	override public function new(?separated:Bool = false)
	{
		super();
		this.separated = separated;
	}

	override public function create():Void
	{
		super.create();
		controls = new FlxText(2, 2, 0, '
        ----Controls----
        W: Forward
        S: Backward
        A: Left
        D: Right
        Space: Up
        Shift: Down
        Hold Left Mouse Button: Look
        -----Config-----
        R: Set separated to ${!separated}(reloads scene)
        Separated: $separated');
		controls.text += separated ? '
        Enter: Show/Start Render
        Escape: Hide render
        ' : '
        Minus: Increase GI resolution
        Plus: Decrease GI resolution
        ';
		controls.setFormat(null, 8, 0xFFFFFFFF, LEFT, OUTLINE, 0xFF000000);
		add(controls);
		if (separated)
		{
			view = new N3DView(FlxG.width, FlxG.height, FlxCameraRenderer);
			add(view);
			cpuRaytracer = new Raytracer(view);
		}
		else
		{
			view = new N3DView(FlxG.width, FlxG.height, Raytracer);
			add(view);
			cpuRaytracer = cast view.renderer;
			cpuRaytracer.giRes = 8;
		}
		cam = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		cam.bgColor.alpha = 0;
		FlxG.cameras.add(cam, false);
		controls.camera = cam;
		initializeScene();
	}

	function initializeScene()
	{
		var sphereDetail = 6; // 20 is high, 6 is low
		view.camX = -142.09870267358;
		view.camY = -186.576563254764;
		view.camZ = 246.719622723706;
		view.camPitch = 0.605;
		view.camYaw = 0.45;

		var floorParts = createCheckerFloor(8, 40);
		view.pushMesh(new Mesh(0, 0, 0, floorParts));

		// Spheres
		var radius = 20;
		var redSphere = createSphereMesh(-80, -radius, 20, radius, FlxColor.RED, sphereDetail, sphereDetail);
		redSphere.raytracingProperties = {reflectiveness: 1, lightness: 0};
		var greenSphere = createSphereMesh(0, -radius, 20, radius, FlxColor.GREEN, sphereDetail, sphereDetail);
		greenSphere.raytracingProperties = {reflectiveness: 1, lightness: 0};
		var blueSphere = createSphereMesh(80, -radius, 20, radius, FlxColor.BLUE, sphereDetail, sphereDetail);
		blueSphere.raytracingProperties = {reflectiveness: 1, lightness: 0};

		view.pushMesh(new Mesh(0, 0, 1, [redSphere, greenSphere, blueSphere]));

		// Sun sphere
		var sun = createSphereMesh(0, -150, -150, 30, FlxColor.YELLOW, sphereDetail, sphereDetail);
		sun.raytracingProperties = {reflectiveness: 0, lightness: 1};
		// view.pushMesh(new Mesh(0, 0, 1, [sun]));
		cpuRaytracer.lights.push(new Vector3D(0, -150, -150));
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
				part.raytracingProperties = {reflectiveness: 0.1, lightness: 0};

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

	function formatTimeVerbose(seconds:Float):String
	{
		var totalMs = Std.int(seconds * 1000);
		var h = Std.int(totalMs / 3600000);
		var m = Std.int((totalMs % 3600000) / 60000);
		var s = Std.int((totalMs % 60000) / 1000);
		var ms = totalMs % 1000;

		var parts = [];

		if (h > 0)
			parts.push(h + "h");
		if (m > 0)
			parts.push(m + "m");
		if (s > 0)
			parts.push(s + "s");
		if (ms > 0 || parts.length == 0)
			parts.push(ms + "ms");

		return parts.join(" ");
	}

	var renderText = '';
	var lastRenderTime:Float = 0;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (separated)
		{
			controls.text = controls.text.substr(0, controls.text.length - renderText.length);
			renderText = cpuRaytracer.rendering ? 'Rendering... ${Math.round(cpuRaytracer.prog / cpuRaytracer.maxProg * 100)}%' : lastRenderTime != 0 ? 'Last Render Time: ${formatTimeVerbose(lastRenderTime)}' : '';
			controls.text += renderText;
			var threaded = true;
			if (FlxG.keys.justPressed.ENTER)
			{
				cpuRaytracer.globalIllum.visible = true;
				if (threaded)
					Thread.create(() ->
					{
						var start = Timer.stamp();
						cpuRaytracer.renderScene();
						var end = Timer.stamp();
						lastRenderTime = end - start;
					});
				else
					cpuRaytracer.renderScene();
			}
			if (FlxG.keys.justPressed.ESCAPE)
				cpuRaytracer.globalIllum.visible = false;
		}
		if (FlxG.keys.justPressed.R)
			FlxG.switchState(() -> new PlayState(!separated));
		if (FlxG.keys.justPressed.MINUS && !separated)
			cpuRaytracer.giRes -= 1;
		if (FlxG.keys.justPressed.PLUS && !separated)
			cpuRaytracer.giRes += 1;
	}
}
