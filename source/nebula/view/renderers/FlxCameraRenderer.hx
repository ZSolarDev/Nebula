package nebula.view.renderers;

import flixel.*;
import flixel.math.FlxPoint;

class FlxCameraRenderer extends FlxCamera implements ViewRenderer
{
	public var view:N3DView;

	public function new(view:N3DView)
	{
		super(0, 0, view.width, view.height);
		this.view = view;
		FlxG.cameras.add(this, false);
		FlxG.state.add(this);
	}

	override public function render()
	{
		super.render();
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
		super.draw(); // draw 2D elements after 3D for things like hud
	}

	override public function destroy()
	{
		super.destroy();
		FlxG.cameras.remove(this);
	}
}
