package nebula.utils;

import flixel.math.FlxAngle;
import openfl.geom.Vector3D;

class Vec3DHelper
{
	public static function add(a:Vector3D, b:Vector3D):Vector3D
		return new Vector3D(a.x + b.x, a.y + b.y, a.z + b.z);

	public static function subtract(a:Vector3D, b:Vector3D):Vector3D
		return new Vector3D(a.x - b.x, a.y - b.y, a.z - b.z);

	public static function multiply(a:Vector3D, b:Vector3D):Vector3D
		return new Vector3D(a.x * b.x, a.y * b.y, a.z * b.z);

	public static function multiplyScalar(v:Vector3D, s:Float):Vector3D
		return new Vector3D(v.x * s, v.y * s, v.z * s);

	public static function dot(a:Vector3D, b:Vector3D):Float
		return a.x * b.x + a.y * b.y + a.z * b.z;

	public static function cross(a:Vector3D, b:Vector3D):Vector3D
		return new Vector3D(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x);

	public static function length(v:Vector3D):Float
		return Math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);

	public static function normalize(v:Vector3D):Vector3D
		return length(v) == 0 ? new Vector3D(0, 0, 0) : multiplyScalar(v, 1 / length(v));

	public static function clamp(value:Float, min:Float, max:Float):Float
		return Math.max(min, Math.min(max, value));

	function interpolate(a:Vector3D, b:Vector3D, t:Float):Vector3D
		return new Vector3D(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t);

	// from Away3D
	public static function rotatePoint(aPoint:Vector3D, rotation:Vector3D):Vector3D
	{
		if (rotation.x != 0 || rotation.y != 0 || rotation.z != 0)
		{
			var x1:Float;
			var y1:Float;

			var rad:Float = FlxAngle.TO_RAD;
			var rotx:Float = rotation.x * rad;
			var roty:Float = rotation.y * rad;
			var rotz:Float = rotation.z * rad;

			var sinx:Float = Math.sin(rotx);
			var cosx:Float = Math.cos(rotx);
			var siny:Float = Math.sin(roty);
			var cosy:Float = Math.cos(roty);
			var sinz:Float = Math.sin(rotz);
			var cosz:Float = Math.cos(rotz);

			var x:Float = aPoint.x;
			var y:Float = aPoint.y;
			var z:Float = aPoint.z;

			y1 = y;
			y = y1 * cosx + z * -sinx;
			z = y1 * sinx + z * cosx;

			x1 = x;
			x = x1 * cosy + z * siny;
			z = x1 * -siny + z * cosy;

			x1 = x;
			x = x1 * cosz + y * -sinz;
			y = x1 * sinz + y * cosz;

			aPoint.x = x;
			aPoint.y = y;
			aPoint.z = z;
		}

		return aPoint;
	}
}
