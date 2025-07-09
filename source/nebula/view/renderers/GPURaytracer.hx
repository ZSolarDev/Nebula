package nebula.view.renderers;

import flixel.*;
import flixel.addons.display.FlxRuntimeShader;
import openfl.display.BitmapData;
import openfl.geom.Vector3D;

class GPURaytracer extends FlxSprite implements ViewRenderer
{
	public var view:N3DView;

	public function new(view:N3DView)
	{
		super(0, 0);
		this.view = view;
		makeGraphic(view.width, view.height, 0x00D9FF);
		FlxG.state.add(this);
		// shader = new RayShader(); TODO: Actually make the raytracer(I have no idea how shaders work)
	}

	public function encodeFloatToRGBA(v:Float):Array<Int>
	{
		var scale = [1.0, 255.0, 65025.0, 16581375.0];
		var enc = [v * scale[0], v * scale[1], v * scale[2], v * scale[3]];

		for (i in 0...4)
			enc[i] = enc[i] - Math.floor(enc[i]);

		enc[0] -= enc[1] / 255.0;
		enc[1] -= enc[2] / 255.0;
		enc[2] -= enc[3] / 255.0;

		// convert 0.0–1.0 floats to 0–255 ints
		return [
			Std.int(enc[0] * 255.0),
			Std.int(enc[1] * 255.0),
			Std.int(enc[2] * 255.0),
			Std.int(enc[3] * 255.0)
		];
	}

	// Literally just turns triangles into an image to use with the frag shader
	public function render()
	{
		var allTris:Array<Array<Vector3D>> = [];

		for (projectedMesh in view.projectedMeshes)
		{
			var mesh = projectedMesh.mesh;
			var verts = mesh.vertices;
			var inds = mesh.indices;

			for (i in 0...cast inds.length / 3)
			{
				var i0 = inds[i * 3 + 0];
				var i1 = inds[i * 3 + 1];
				var i2 = inds[i * 3 + 2];
				allTris.push([verts[i0], verts[i1], verts[i2]]);
			}
		}

		// find bounding box
		var minPos = new Vector3D(Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY);
		var maxPos = new Vector3D(Math.NEGATIVE_INFINITY, Math.NEGATIVE_INFINITY, Math.NEGATIVE_INFINITY);

		for (tri in allTris)
		{
			for (v in tri)
			{
				minPos.x = Math.min(minPos.x, v.x);
				minPos.y = Math.min(minPos.y, v.y);
				minPos.z = Math.min(minPos.z, v.z);

				maxPos.x = Math.max(maxPos.x, v.x);
				maxPos.y = Math.max(maxPos.y, v.y);
				maxPos.z = Math.max(maxPos.z, v.z);
			}
		}

		// create bitmap to hold encoded data
		var triangleCount = allTris.length;
		var bmp = new BitmapData(9 * triangleCount, 1, true, 0);
		var px = 0;

		for (tri in allTris)
		{
			for (coord in tri)
			{
				for (axis in 0...3)
				{
					var scaled = switch (axis)
					{
						case 0: (coord.x - minPos.x) / (maxPos.x - minPos.x);
						case 1: (coord.y - minPos.y) / (maxPos.y - minPos.y);
						case 2: (coord.z - minPos.z) / (maxPos.z - minPos.z);
						default: 0.0;
					}
					var rgba = encodeFloatToRGBA(scaled);
					var color = (rgba[3] << 24) | (rgba[0] << 16) | (rgba[1] << 8) | rgba[2];
					bmp.setPixel32(px, 0, color);
					px++;
				}
			}
		}
	}
}
