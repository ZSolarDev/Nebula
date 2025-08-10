package nebula.view.renderers;

import flixel.FlxSprite;
import flixel.util.FlxColor;
import lime.math.Vector2;
import nebulatracer.Global;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import openfl.geom.Vector3D;

class CPURasterizer extends FlxSprite implements ViewRenderer
{
	public var view:N3DView;
	public var rendering:Bool;
	public var zBuffer:Array<Float> = [];

	override public function new(view:N3DView)
	{
		super();
		this.view = view;
		makeGraphic(view.width, view.height, 0x00000000);

		zBuffer = Global.padArrayFloat(zBuffer, view.width * view.height, 99999999);
	}

	public function renderScene()
	{
		rendering = true;
		zBuffer = [];
		zBuffer = Global.padArrayFloat(zBuffer, view.width * view.height, 99999999);
		pixels.lock();
		pixels.fillRect(new Rectangle(0, 0, view.width, view.height), 0x00000000);
		for (mesh in view.projectedMeshes)
		{
			var verts = mesh.verts3d;

			var indices:Array<Vector3D> = [];
			for (i in 0...cast mesh.indices.length / 3)
			{
				var idx0 = mesh.indices[i * 3];
				var idx1 = mesh.indices[i * 3 + 1];
				var idx2 = mesh.indices[i * 3 + 2];

				indices.push(new Vector3D(idx0, idx1, idx2));
			}

			var uvs:Array<Vector2> = [];
			for (i in 0...cast mesh.uvt.length / 2)
			{
				var u = mesh.uvt[i * 2];
				var v = mesh.uvt[i * 2 + 1];
				uvs.push(new Vector2(u, v));
			}

			for (idx in indices)
			{
				var p0 = verts[cast idx.x];
				var p1 = verts[cast idx.y];
				var p2 = verts[cast idx.z];
				var uv0 = uvs[cast idx.x];
				var uv1 = uvs[cast idx.y];
				var uv2 = uvs[cast idx.z];
				try
				{
					drawTriangle(p0, uv0, p1, uv1, p2, uv2, mesh.mesh._graphic.bitmap);
				}
				catch (e)
				{
					continue;
				}
			}
		}
		pixels.unlock();
		rendering = false;
	}

	public function drawTriangle(p0:Vector3D, uv0:Vector2, p1:Vector3D, uv1:Vector2, p2:Vector3D, uv2:Vector2, texture:BitmapData, opacity:Float = 1.0):Void
	{
		var minX = Math.floor(Math.min(p0.x, Math.min(p1.x, p2.x)));
		var maxX = Math.ceil(Math.max(p0.x, Math.max(p1.x, p2.x)));
		var minY = Math.floor(Math.min(p0.y, Math.min(p1.y, p2.y)));
		var maxY = Math.ceil(Math.max(p0.y, Math.max(p1.y, p2.y)));

		var iz0 = 1 / p0.z;
		var iz1 = 1 / p1.z;
		var iz2 = 1 / p2.z;

		var u0z = uv0.x * iz0;
		var u1z = uv1.x * iz1;
		var u2z = uv2.x * iz2;

		var v0z = uv0.y * iz0;
		var v1z = uv1.y * iz1;
		var v2z = uv2.y * iz2;

		for (y in minY...maxY)
		{
			for (x in minX...maxX)
			{
				if (x < 0 || y < 0 || x >= width || y >= height)
					continue;

				var bc = getBarycentric(new Vector2(p0.x, p0.y), new Vector2(p1.x, p1.y), new Vector2(p2.x, p2.y), x + 0.5, y + 0.5);

				if (bc.x >= 0 && bc.y >= 0 && bc.z >= 0)
				{
					var iz = bc.x * iz0 + bc.y * iz1 + bc.z * iz2;
					var depth = 1 / iz;

					var index:Int = cast x + y * width;
					if (depth < zBuffer[index])
					{
						zBuffer[index] = depth;

						var uz = bc.x * u0z + bc.y * u1z + bc.z * u2z;
						var vz = bc.x * v0z + bc.y * v1z + bc.z * v2z;

						var u = uz / iz;
						var v = vz / iz;

						var tx = Std.int(u * texture.width);
						var ty = Std.int(v * texture.height);

						if (tx >= 0 && tx < texture.width && ty >= 0 && ty < texture.height)
						{
							var src:FlxColor = texture.getPixel32(tx, ty);
							var dst:FlxColor = pixels.getPixel32(x, y);

							var finalAlpha = (src.alpha / 255) * opacity;

							var r = Std.int(src.red * finalAlpha + dst.red * (1 - finalAlpha));
							var g = Std.int(src.green * finalAlpha + dst.green * (1 - finalAlpha));
							var b = Std.int(src.blue * finalAlpha + dst.blue * (1 - finalAlpha));
							var a = Std.int((src.alpha / 255) * finalAlpha * 255 + (dst.alpha / 255) * (1 - finalAlpha) * 255);

							var blended = FlxColor.fromRGB(r, g, b, a);
							pixels.setPixel32(x, y, blended);
						}
					}
				}
			}
		}
	}

	function getBarycentric(p0:Vector2, p1:Vector2, p2:Vector2, px:Float, py:Float):Vector3D
	{
		var denom = (p1.y - p2.y) * (p0.x - p2.x) + (p2.x - p1.x) * (p0.y - p2.y);
		if (denom == 0)
			return new Vector3D(-1, -1, -1);
		var w1 = ((p1.y - p2.y) * (px - p2.x) + (p2.x - p1.x) * (py - p2.y)) / denom;
		var w2 = ((p2.y - p0.y) * (px - p2.x) + (p0.x - p2.x) * (py - p2.y)) / denom;
		var w3 = 1.0 - w1 - w2;
		return new Vector3D(w1, w2, w3);
	}
}
