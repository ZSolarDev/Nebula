package;

import flixel.*;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Timer;
import nebula.mesh.*;
import nebula.utils.Vec3DHelper;
import nebula.view.*;
import nebula.view.renderers.*;
import nebulatracer.native.Embree;
import openfl.Vector;
import openfl.geom.Vector3D;
import sys.thread.Thread;

using StringTools;

enum Plane
{
	XY;
	XZ;
	YZ;
}

enum abstract TestSceneType(Int)
{
	var THREE_SPHERES = 0;
	var CORNELL_BOX = 1;
	var TEXTURE_TEST = 2;
}

class PlayState extends FlxState
{
	var cpuRaytracer:Raytracer;
	var separated:Bool = false;
	var view:N3DView;
	var controls:FlxText;
	var cam:FlxCamera;
	var scene(default, set):TestSceneType;
	var maxScenes = 3;

	function set_scene(val:TestSceneType):TestSceneType
	{
		scene = val;
		cpuRaytracer.lights = [];
		view.camX = 0;
		view.camY = 0;
		view.camZ = 0;
		view.camPitch = 0;
		view.camYaw = 0;
		view.meshes = [];
		switch (val)
		{
			case THREE_SPHERES:
				var sphereDetail = 20;
				view.camX = -142.09870267358;
				view.camY = -186.576563254764;
				view.camZ = 246.719622723706;
				view.camPitch = 0.605;
				view.camYaw = 0.45;

				var floorParts = createCheckerFloor(8, 40);
				view.pushMesh(new Mesh(0, 0, 0, floorParts));

				var radius = 20;
				var redSphere = createSphereMesh(-80, -radius, 20, radius, FlxColor.RED, sphereDetail, sphereDetail);
				redSphere.raytracingProperties = {
					reflectiveness: 1,
					lightColor: FlxColor.BLACK,
					lightPower: 0,
					isEmitter: false,
					lightPointers: []
				};
				var greenSphere = createSphereMesh(0, -radius, 20, radius, FlxColor.GREEN, sphereDetail, sphereDetail);
				greenSphere.raytracingProperties = {
					reflectiveness: 1,
					lightColor: FlxColor.BLACK,
					lightPower: 0,
					isEmitter: false,
					lightPointers: []
				};
				var blueSphere = createSphereMesh(80, -radius, 20, radius, FlxColor.BLUE, sphereDetail, sphereDetail);
				blueSphere.raytracingProperties = {
					reflectiveness: 1,
					lightColor: FlxColor.BLACK,
					lightPower: 0,
					isEmitter: false,
					lightPointers: []
				};

				view.pushMesh(new Mesh(0, 0, 0, [redSphere, greenSphere, blueSphere]));

				var sun = createSphereMesh(0, -150, -150, 30, FlxColor.YELLOW, sphereDetail, sphereDetail);
				sun.raytracingProperties = {
					reflectiveness: 0,
					isEmitter: true,
					lightColor: FlxColor.YELLOW,
					lightPower: 320,
					lightPointers: [
						{
							pos: new Vector3D(0, -150, -150),
							meshPart: sun
						}
					]
				};

				var otherSun = createSphereMesh(0, -150, 300, 30, FlxColor.YELLOW, sphereDetail, sphereDetail);
				otherSun.raytracingProperties = {
					reflectiveness: 0,
					isEmitter: true,
					lightColor: FlxColor.YELLOW,
					lightPower: 320,
					lightPointers: [
						{
							pos: new Vector3D(0, -150, 300),
							meshPart: otherSun
						}
					]
				};
				view.pushMesh(new Mesh(0, 0, 0, [sun, otherSun]));
			case CORNELL_BOX:
				var sphereDetail = 30;

				view.camX = 0;
				view.camY = 0;
				view.camZ = 200;
				view.camPitch = 0;
				view.camYaw = 0;

				var wallSize = 100.0;

				var floor = makeQuad(-wallSize, -wallSize, -wallSize, wallSize * 2, wallSize * 2, FlxColor.GRAY, XZ);
				floor.raytracingProperties = {
					reflectiveness: 0,
					isEmitter: false,
					lightColor: FlxColor.BLACK,
					lightPower: 0,
					lightPointers: []
				}
				var ceiling = makeQuad(-wallSize, wallSize, -wallSize, wallSize * 2, wallSize * 2, FlxColor.GRAY, XZ);
				ceiling.raytracingProperties = {
					reflectiveness: 0,
					isEmitter: false,
					lightColor: FlxColor.BLACK,
					lightPower: 0,
					lightPointers: []
				}
				var backWall = makeQuad(-wallSize, -wallSize, -wallSize, wallSize * 2, wallSize * 2, FlxColor.GRAY, XY);
				backWall.raytracingProperties = {
					reflectiveness: 0,
					isEmitter: false,
					lightColor: FlxColor.BLACK,
					lightPower: 0,
					lightPointers: []
				}
				var leftWall = makeQuad(-wallSize, -wallSize, -wallSize, wallSize * 2, wallSize * 2, FlxColor.RED, YZ);
				leftWall.raytracingProperties = {
					reflectiveness: 0,
					isEmitter: false,
					lightColor: FlxColor.BLACK,
					lightPower: 0,
					lightPointers: []
				}
				var rightWall = makeQuad(wallSize, -wallSize, -wallSize, wallSize * 2, wallSize * 2, FlxColor.GREEN, YZ);
				rightWall.raytracingProperties = {
					reflectiveness: 0,
					isEmitter: false,
					lightColor: FlxColor.BLACK,
					lightPower: 400,
					lightPointers: []
				}

				view.pushMesh(new Mesh(0, 0, 0, [floor, ceiling, backWall, leftWall, rightWall]));

				var radius1 = 60;
				var radius2 = 40;
				var sphere1 = createSphereMesh(-30, wallSize - radius1, -30, radius1, FlxColor.WHITE, sphereDetail, sphereDetail);
				sphere1.raytracingProperties = {
					reflectiveness: 1,
					isEmitter: false,
					lightColor: FlxColor.BLACK,
					lightPower: 0,
					lightPointers: []
				};
				var sphere2 = createSphereMesh(40, wallSize - radius2, 30, radius2, FlxColor.WHITE, sphereDetail, sphereDetail);
				sphere2.raytracingProperties = {
					reflectiveness: 1,
					isEmitter: false,
					lightColor: FlxColor.BLACK,
					lightPower: 0,
					lightPointers: []
				};
				view.pushMesh(new Mesh(0, 0, 0, [sphere1, sphere2]));

				var lightSize = 40.0;
				var lightY = 0;
				lightY -= cast wallSize / 2;
				lightY += 10;
				var light = makeQuad(-lightSize / 2, -wallSize + 0.1, -lightSize / 2, lightSize, lightSize, FlxColor.WHITE, XZ);
				light.raytracingProperties = {
					reflectiveness: 0,
					isEmitter: true,
					lightColor: FlxColor.WHITE,
					lightPower: 400,
					lightPointers: [
						{
							pos: new Vector3D(0, -wallSize + 0.1, 0),
							meshPart: light
						}
					]
				};
				view.pushMesh(new Mesh(0, 0, 1, [light]));
			case TEXTURE_TEST:
				var part1 = new MeshPart(new Vector<Vector3D>(), new Vector<Int>(), new Vector<Float>(), new Vector<Vector3D>(), 'assets/images/breh.png');
				part1.raytracingProperties = {
					reflectiveness: 0,
					isEmitter: false,
					lightColor: FlxColor.BLACK,
					lightPower: 0,
					lightPointers: []
				};
				part1.vertices.push(new Vector3D(-50, -50, 0));
				part1.vertices.push(new Vector3D(50, -50, 0));
				part1.vertices.push(new Vector3D(0, 50, 0));

				part1.normals.push(new Vector3D(0, 0, 1));
				part1.normals.push(new Vector3D(0, 0, 1));
				part1.normals.push(new Vector3D(0, 0, 1));

				part1.indices.push(0);
				part1.indices.push(1);
				part1.indices.push(2);

				part1.uvs.push(0);
				part1.uvs.push(0);
				part1.uvs.push(1);
				part1.uvs.push(0);
				part1.uvs.push(0.5);
				part1.uvs.push(1);

				var mesh1 = new Mesh(0, 0, -200, [part1]);

				view.pushMesh(mesh1);

				var part2 = new MeshPart(new Vector<Vector3D>(), new Vector<Int>(), new Vector<Float>(), new Vector<Vector3D>(), 'assets/images/minion.jpg');
				part2.raytracingProperties = {
					reflectiveness: 0,
					isEmitter: true,
					lightColor: FlxColor.WHITE,
					lightPower: 50,
					lightPointers: []
				};
				part2.vertices.push(new Vector3D(-50, -50, 0));
				part2.vertices.push(new Vector3D(50, -50, 0));
				part2.vertices.push(new Vector3D(0, 50, 0));

				part2.normals.push(new Vector3D(0, 0, 1));
				part2.normals.push(new Vector3D(0, 0, 1));
				part2.normals.push(new Vector3D(0, 0, 1));

				part2.indices.push(0);
				part2.indices.push(1);
				part2.indices.push(2);

				part2.uvs.push(0);
				part2.uvs.push(0);
				part2.uvs.push(1);
				part2.uvs.push(0);
				part2.uvs.push(0.5);
				part2.uvs.push(1);

				var mesh2 = new Mesh(0, -30, -300, [part2]);

				view.pushMesh(mesh2);
		}
		return val;
	}

	override public function new(?separated:Bool = true)
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
        J: Switches the scene
        R: Set separated to ${!separated}(reloads scene)
        Separated: $separated');
		controls.text += separated ? '
        Enter: Show/Start Render
        Escape: Hide render
        Backspace: Hide/Show Rasterizer
        ' : '
        Minus: Decerase GI resolution
        Plus: Increase GI resolution
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
			cpuRaytracer.resolution = 8;
		}
		cam = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		cam.bgColor.alpha = 0;
		FlxG.cameras.add(cam, false);
		controls.camera = cam;
		scene = TEXTURE_TEST;
	}

	function createSphereMesh(x:Float, y:Float, z:Float, radius:Float, color:Int, latSteps:Int = 6, lonSteps:Int = 6):MeshPart
	{
		var part = new MeshPart(new Vector<Vector3D>(), new Vector<Int>(), new Vector<Float>(), new Vector<Vector3D>(), '');
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
				var nx = px - x;
				var ny = py - y;
				var nz = pz - z;
				var normal = new Vector3D(nx, ny, nz);
				normal.normalize();
				part.normals.push(normal);
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

	function makeQuad(x:Float, y:Float, z:Float, sizeX:Float, sizeY:Float, color:Int, plane:Plane, backFace:Bool = false):MeshPart
	{
		var part = new MeshPart(new Vector<Vector3D>(), new Vector<Int>(), new Vector<Float>(), new Vector<Vector3D>(), '');
		part.color = color;

		var v1:Vector3D;
		var v2:Vector3D;
		var v3:Vector3D;
		var v4:Vector3D;

		switch (plane)
		{
			case XY:
				v1 = new Vector3D(x, y, z);
				v2 = new Vector3D(x + sizeX, y, z);
				v3 = new Vector3D(x + sizeX, y + sizeY, z);
				v4 = new Vector3D(x, y + sizeY, z);
			case XZ:
				v1 = new Vector3D(x, y, z);
				v2 = new Vector3D(x + sizeX, y, z);
				v3 = new Vector3D(x + sizeX, y, z + sizeY);
				v4 = new Vector3D(x, y, z + sizeY);
			case YZ:
				v1 = new Vector3D(x, y, z);
				v2 = new Vector3D(x, y + sizeX, z);
				v3 = new Vector3D(x, y + sizeX, z + sizeY);
				v4 = new Vector3D(x, y, z + sizeY);
		}

		part.vertices.push(v1);
		part.vertices.push(v2);
		part.vertices.push(v3);
		part.vertices.push(v4);

		var edge1 = v2.subtract(v1);
		var edge2 = v3.subtract(v1);
		var normal = Vec3DHelper.normalize(Vec3DHelper.cross(edge1, edge2));

		if (backFace)
			normal = Vec3DHelper.multiplyScalar(normal, -1);

		part.normals.push(normal);
		part.normals.push(normal);
		part.normals.push(normal);
		part.normals.push(normal);

		if (backFace)
		{
			part.indices.push(0);
			part.indices.push(2);
			part.indices.push(1);
			part.indices.push(0);
			part.indices.push(3);
			part.indices.push(2);
		}
		else
		{
			part.indices.push(0);
			part.indices.push(1);
			part.indices.push(2);
			part.indices.push(0);
			part.indices.push(2);
			part.indices.push(3);
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

				var part = new MeshPart(new Vector<Vector3D>(), new Vector<Int>(), new Vector<Float>(), new Vector<Vector3D>(), '');
				part.color = color;
				part.raytracingProperties = {
					reflectiveness: 0.1,
					isEmitter: false,
					lightColor: FlxColor.BLACK,
					lightPower: 0.0,
					lightPointers: []
				}

				part.vertices.push(new Vector3D(x, 0, y));
				part.vertices.push(new Vector3D(x + tileSize, 0, y));
				part.vertices.push(new Vector3D(x + tileSize, 0, y + tileSize));
				part.vertices.push(new Vector3D(x, 0, y + tileSize));

				var normal = new Vector3D(0, 1, 0);
				part.normals.push(normal);
				part.normals.push(normal);
				part.normals.push(normal);
				part.normals.push(normal);

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
				cpuRaytracer.targetTex.visible = true;
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
				cpuRaytracer.targetTex.visible = false;
			if (FlxG.keys.justPressed.BACKSPACE)
			{
				view.render = !view.render;
			}
		}
		if (FlxG.keys.justPressed.R && !cpuRaytracer.rendering)
			FlxG.switchState(() -> new PlayState(!separated));
		else if (FlxG.keys.justPressed.R && cpuRaytracer.rendering)
			trace('Rendering, please wait for it to finish before switching modes.');
		if (FlxG.keys.justPressed.MINUS && !separated)
			cpuRaytracer.resolution -= 1;
		if (FlxG.keys.justPressed.PLUS && !separated)
			cpuRaytracer.resolution += 1;

		if (FlxG.keys.justPressed.J)
			scene = cast(cast(scene, Int) + 1) % maxScenes;
	}
}
