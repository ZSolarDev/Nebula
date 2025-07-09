package;

import flixel.*;
import nebula.mesh.*;
import nebula.mesh.loaders.*;
import nebula.mesh.savers.*;
import nebula.view.*;
import nebula.view.renderers.*;
import openfl.Vector;
import openfl.geom.Vector3D;

class PlayState extends FlxState
{
	var mesh1:Mesh;
	var mesh2:Mesh;
	var view:N3DView;

	override public function create():Void
	{
		super.create();
		// view = new N3DView(FlxG.width, FlxG.height, FlxCameraRenderer);
		// add(view);

		var part1 = new MeshPart(new Vector<Vector3D>(), new Vector<Int>(), new Vector<Float>(), 'assets/images/breh.png');

		// Half-size for positioning from center
		var s = 50;

		// Vertices (8 corners of the cube)
		part1.vertices.push(new Vector3D(-s, -s, -s)); // 0
		part1.vertices.push(new Vector3D(s, -s, -s)); // 1
		part1.vertices.push(new Vector3D(s, s, -s)); // 2
		part1.vertices.push(new Vector3D(-s, s, -s)); // 3
		part1.vertices.push(new Vector3D(-s, -s, s)); // 4
		part1.vertices.push(new Vector3D(s, -s, s)); // 5
		part1.vertices.push(new Vector3D(s, s, s)); // 6
		part1.vertices.push(new Vector3D(-s, s, s)); // 7

		// Indices (2 triangles per face)
		var faces = [
			// Front
			0,
			1,
			2,
			0,
			2,
			3,
			// Back
			5,
			4,
			7,
			5,
			7,
			6,
			// Left
			4,
			0,
			3,
			4,
			3,
			7,
			// Right
			1,
			5,
			6,
			1,
			6,
			2,
			// Top
			3,
			2,
			6,
			3,
			6,
			7,
			// Bottom
			4,
			5,
			1,
			4,
			1,
			0
		];
		for (i in faces)
			part1.indices.push(i);

		// UVT (simple planar mapping for now, repeated for each vertex)
		var uv = [
			[0, 0], [1, 0], [1, 1], [0, 1], // back/front face UVs
			[0, 0], [1, 0], [1, 1],                       [0, 1]
		];
		for (uvset in uv)
		{
			part1.uvt.push(uvset[0]);
			part1.uvt.push(uvset[1]);
		}

		mesh1 = new Mesh(0, 0, -200, [part1]);

		// view.pushMesh(mesh1);
		new JsonMeshSaver().saveMesh(mesh1, './mesh.json');

		var part2 = new MeshPart(new Vector<Vector3D>(), new Vector<Int>(), new Vector<Float>(), 'assets/images/minion.jpg');
		part2.vertices.push(new Vector3D(-50, -50, 0));
		part2.vertices.push(new Vector3D(50, -50, 0));
		part2.vertices.push(new Vector3D(0, 50, 0));

		part2.indices.push(0);
		part2.indices.push(1);
		part2.indices.push(2);

		part2.uvt.push(0);
		part2.uvt.push(0);
		part2.uvt.push(1);
		part2.uvt.push(0);
		part2.uvt.push(0.5);
		part2.uvt.push(1);

		mesh2 = new Mesh(0, -30, -300, [part2]);

		// view.pushMesh(mesh2);
		var spr = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFFFFFFFF);
		spr.shader = new RayShader();
		add(spr);
		// new JsonMeshSaver().saveMesh(mesh2, './mesh2.json');
		// var font = FlxBitmapFont.fromMonospace('assets/font.png',
		//	'!"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~•', FlxPoint.get(7, 7), null, FlxPoint.get(0, 0));
		// var text = new FlxBitmapText(0, 0, 'The Quick Brown Fox Jumps Over The Lazy Dog\nThe Quick Brown Fox Jumps Over The Lazy Dog', font);
		// text.scale.set(3, 3);
		// add(text);
		// var text = new Text({x: 100, y: 20}, 'The Quick Brown Fox Jumps Over The Lazy Dog\nThe Quick Brown Fox Jumps Over The Lazy Dog', 0xFFFFFF,
		//	{x: 2, y: 2}, 1280, LEFT);
		// add(text);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		// mesh1.yaw += 0.03 * elapsed * 2;
		// mesh2.yaw -= 0.03 * elapsed * 2;
		// mesh1.pitch += 0.05 * elapsed * 2;
		// mesh2.pitch -= 0.05 * elapsed * 2;
		// mesh1.roll += 0.1 * elapsed * 2;
		// mesh2.roll -= 0.1 * elapsed * 2;
	}
}
