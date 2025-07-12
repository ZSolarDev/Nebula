package nebula.view.renderers;

import flixel.*;
import flixel.math.FlxRandom;
import flixel.util.FlxColor;
import lime.utils.Log;
import nebula.utils.Vec3DHelper.*;
import nebula.view.N3DView.ClippingVertex;
import openfl.geom.Rectangle;
import openfl.geom.Vector3D;

typedef Triangle =
{
	var pos0:Vector3D;
	var pos1:Vector3D;
	var pos2:Vector3D;
	var color:Int;
}

class CPURaytracer extends FlxSprite implements ViewRenderer
{
	public var view:N3DView;
	public var rendering:Bool = false;
	public var numBounces:Int = 3;
	public var triangles:Array<Triangle>;

	override public function new(view:N3DView)
	{
		super();
		this.view = view;
		makeGraphic(view.width, view.height, 0x00D9FF);
		FlxG.state.add(this);
	}

	function intersectTriangle(orig:Vector3D, dir:Vector3D, a:Vector3D, b:Vector3D, c:Vector3D):Float
	{
		final EPSILON = 0.0000001;
		var edge1 = subtract(b, a);
		var edge2 = subtract(c, a);
		var h = cross(dir, edge2);
		var aDot = dot(edge1, h);

		if (aDot > -EPSILON && aDot < EPSILON)
			return -1;

		var f = 1.0 / aDot;
		var s = subtract(orig, a);
		var u = f * dot(s, h);
		if (u < 0.0 || u > 1.0)
			return -1;

		var q = cross(s, edge1);
		var v = f * dot(dir, q);
		if (v < 0.0 || u + v > 1.0)
			return -1;

		var t = f * dot(edge2, q);
		if (t > EPSILON)
			return t;
		else
			return -1;
	}

	function randomHemisphereDirection(normal:Vector3D):Vector3D
	{
		var u = Math.random();
		var v = Math.random();

		var theta = 2 * Math.PI * u;
		var phi = Math.acos(2 * v - 1);

		var x = Math.sin(phi) * Math.cos(theta);
		var y = Math.sin(phi) * Math.sin(theta);
		var z = Math.cos(phi);

		var randDir = new Vector3D(x, y, z);

		// Make sure it's in the same hemisphere as the normal
		if (dot(randDir, normal) < 0)
			randDir = multiplyScalar(randDir, -1);

		return randDir;
	}

	function traceRay(rayPos:Vector3D, rayDir:Vector3D):Int
	{
		var closestDist = 1e9;
		var bestTri:Triangle = null;

		for (tri in triangles)
		{
			var dist = intersectTriangle(rayPos, rayDir, tri.pos0, tri.pos1, tri.pos2);
			if (dist > 0 && dist < closestDist)
			{
				closestDist = dist;
				bestTri = tri;
			}
		}

		if (bestTri != null)
			return bestTri.color;
		else
			return 0xFF00D9FF; // sky color or fallback
	}

	public function render():Void
	{
		try
		{
			if (rendering)
				return;
			rendering = true;

			pixels.fillRect(new Rectangle(0, 0, view.width, view.height), 0x00000000); // fill black with full alpha

			var width = frameWidth;
			var height = frameHeight;

			triangles = [];
			for (tri in view.triangles)
			{
				triangles.push({
					pos0: tri[0].pos,
					pos1: tri[1].pos,
					pos2: tri[2].pos,
					color: tri[0].meshPart.color
				});
			}

			for (y in 0...height)
			{
				for (x in 0...width)
				{
					var uvx = (x / width) * 2.0 - 1.0;
					var uvy = (y / height) * 2.0 - 1.0;

					var aspect = width / height;
					uvx *= aspect;

					var z = -1.0 / Math.tan(Math.PI * 0.5 * view.fov / 180);

					var rayDir = normalize(new Vector3D(uvx, uvy, z));
					var rayPos = new Vector3D(0, 0, 0);

					var finalColor:Int = 0xFF0400FF; // darker blue so I know the difference between rasterized and raytraced
					var hitTri = null;
					var hitDist = 0.0;

					for (bounce in 0...numBounces)
					{
						var minDist = 1e9;
						hitTri = null;

						for (tri in triangles)
						{
							var dist = intersectTriangle(rayPos, rayDir, tri.pos0, tri.pos1, tri.pos2);
							if (dist > 0 && dist < minDist)
							{
								minDist = dist;
								hitTri = tri;
							}
						}

						if (hitTri == null)
						{
							// no hit this bounce, keep final color as blue if first bounce or last bounce
							if (bounce == 0)
								finalColor = 0xFF0400FF;
							break;
						}

						// hit, update final color to this triangle's color
						if (bounce == 0)
							finalColor = hitTri.color;
						else
							finalColor = FlxColor.interpolate(finalColor, hitTri.color, 0.3);
						hitDist = minDist;

						// calculate intersection point
						var hitPoint = add(rayPos, multiplyScalar(rayDir, hitDist));

						// calculate normal of hit triangle
						var edge1 = subtract(hitTri.pos1, hitTri.pos0);
						var edge2 = subtract(hitTri.pos2, hitTri.pos0);
						var normal = normalize(cross(edge1, edge2));

						// scatter secondary rays around the normal
						// var numScattered = 4;
						// var scatterColor = finalColor;
						//
						// for (_ in 0...numScattered)
						// {
						// var dir = normalize(randomHemisphereDirection(normal));
						// var origin = add(hitPoint, multiplyScalar(dir, 0.001)); // offset to avoid self-hit
						//
						// var colorHit = traceRay(origin, dir);
						// scatterColor = FlxColor.interpolate(scatterColor, colorHit, 1 / numScattered);
						// }
						//
						// blend in scattered color with final color
						// finalColor = FlxColor.interpolate(finalColor, scatterColor, 0.25);

						// reflect ray direction (I need to figure out how to make more rays scatter in random directions in a dome around the surface normal and once a ray hits something(if it does) it will slightly effect the color. chatgpt helppp)
						rayDir = normalize(subtract(rayDir, multiplyScalar(normal, 2 * dot(rayDir, normal))));

						// move ray origin slightly off the surface to avoid self-intersection
						rayPos = add(hitPoint, multiplyScalar(rayDir, 0.001));
					}

					pixels.setPixel32(x, y, finalColor);
				}
			}
			pixels.floodFill(0, 0, 0xFF00D9FF); // fill darker blue with sky blue
			rendering = false;
		}
		catch (e)
		{
			Log.error(e);
		}
	}
}
