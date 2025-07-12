package nebula.view.renderers;

import flixel.*;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxPoint;
import openfl.display.BitmapData;

class FlxCameraRenderer extends FlxCamera implements ViewRenderer
{
	public var view:N3DView;
	public var bg:FlxSprite;

	public function new(view:N3DView)
	{
		super(0, 0, view.width, view.height);
		this.view = view;
		FlxG.cameras.reset(this);
		FlxG.state.add(this);
		bg = new FlxSprite(0, 0, FlxGraphic.fromBitmapData(new BitmapData(view.width, view.height, true, 0xFF00D9FF)));
		bg.camera = this;
	}

	override public function render() // Doesnt work when I put drawing code in here, I have to overwrite draw.
	{
		super.render();
	}

	override public function draw()
	{
		super.draw();
		bg.draw();
		if (!view.render) // Manual check
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
