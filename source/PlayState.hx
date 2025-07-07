package;

import flixel.*;
import nebula.mesh.*;
import nebula.mesh.loaders.*;
import nebula.mesh.savers.*;
import nebula.view.*;
import nebula.view.renderers.FlxCameraRenderer;
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
		view = new N3DView(FlxG.width, FlxG.height, FlxCameraRenderer);
		add(view);
		var part1 = new MeshPart(new Vector<Vector3D>(), new Vector<Int>(), new Vector<Float>(), 'assets/images/breh.png');
		part1.vertices.push(new Vector3D(-50, -50, 0));
		part1.vertices.push(new Vector3D(50, -50, 0));
		part1.vertices.push(new Vector3D(0, 50, 0));

		part1.indices.push(0);
		part1.indices.push(1);
		part1.indices.push(2);

		part1.uvt.push(0);
		part1.uvt.push(0);
		part1.uvt.push(1);
		part1.uvt.push(0);
		part1.uvt.push(0.5);
		part1.uvt.push(1);

		mesh1 = new Mesh(0, 0, -200, [part1]);

		view.pushMesh(mesh1);
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

		view.pushMesh(mesh2);
		new JsonMeshSaver().saveMesh(mesh2, './mesh2.json');
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
