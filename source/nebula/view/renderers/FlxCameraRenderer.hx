package nebula.view.renderers;

import flixel.*;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxPoint;
import nebula.mesh.Mesh;
import nebula.mesh.ProjectionMesh;
import nebula.view.N3DView.ClippingVertex;
import openfl.display.Bitmap;
import openfl.display.BitmapData;

class FlxCameraRenderer extends FlxCamera implements ViewRenderer
{
	public var view:N3DView;
	public var bg:FlxSprite;

	public var buffers:Map<String, BitmapData> = new Map();

	public function new(view:N3DView)
	{
		super(0, 0, view.width, view.height);
		this.view = view;
		FlxG.cameras.reset(this);
		FlxG.state.add(this);
		bg = new FlxSprite(0, 0, FlxGraphic.fromBitmapData(new BitmapData(view.width, view.height, true, 0xFF000000)));
		bg.camera = this;
	}

	function processBuffers(screenSpaceMeshes:Array<ProjectionMesh>, camSpaceVerts:Array<Array<ClippingVertex>>, meshes:Array<Mesh>)
	{
		// ------- Depth buffer ------- //
		var depthBuffer = new BitmapData(view.width, view.height, true, 0xFF000000);
	}

	public var rendering = false;

	public function renderScene() {} // nothing draws when i put it in here, i have to overwrite draw myself.

	override public function draw()
	{
		super.draw();
		bg.draw();
		if (!view.render)
			return;
		var sortedMeshes = view.projectedMeshes.copy();
		for (i in 0...sortedMeshes.length - 1)
		{
			for (j in i + 1...sortedMeshes.length)
			{
				if (sortedMeshes[i].camZ > sortedMeshes[j].camZ)
				{
					var temp = sortedMeshes[i];
					sortedMeshes[i] = sortedMeshes[j];
					sortedMeshes[j] = temp;
				}
			}
		}
		processBuffers(sortedMeshes, view.camSpaceTris, view.meshes);
		for (projectedMesh in sortedMeshes)
		{
			var mesh = projectedMesh.mesh;
			var meshPos = projectedMesh.meshPos;
			drawTriangles(mesh._graphic, projectedMesh.verts, projectedMesh.indices, projectedMesh.uvt, null, new FlxPoint(meshPos.x, meshPos.y), mesh.blend,
				mesh.repeat, mesh.smooth);
		}
	}

	override public function destroy()
	{
		super.destroy();
		FlxG.cameras.remove(this);
	}
}
