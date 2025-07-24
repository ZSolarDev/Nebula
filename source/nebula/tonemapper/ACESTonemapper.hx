package nebula.tonemapper;

import flixel.math.FlxMath;
import flixel.util.FlxColor;
import nebula.view.renderers.Raytracer.FloatColor;

class ACESTonemapper implements Tonemapper
{
	public function new() {}

	// my brain melted
	inline function acesTonemap(x:Float):Float
	{
		var a = 2.51;
		var b = 0.03;
		var c = 2.43;
		var d = 0.59;
		var e = 0.14;
		return Math.min(1.0, Math.max(0.0, (x * (a * x + b)) / (x * (c * x + d) + e)));
	}

	public function map(color:FloatColor):FlxColor
	{
		var r = acesTonemap(color.red);
		var g = acesTonemap(color.green);
		var b = acesTonemap(color.blue);

		var finalColor:FlxColor = 0x000000;
		finalColor.red = Std.int(r * 255);
		finalColor.green = Std.int(g * 255);
		finalColor.blue = Std.int(b * 255);
		return finalColor;
	}
}
