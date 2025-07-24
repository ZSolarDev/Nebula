package nebula.tonemapper;

import flixel.util.FlxColor;
import nebula.view.renderers.Raytracer.FloatColor;

/**
 * This is the default tonemapper, this tonemapper isn't reccomended for use as it won't look the best in most cases.
 */
class ClampTonemapper implements Tonemapper
{
	public function new() {}

	public function map(color:FloatColor):FlxColor
	{
		var finalColor:FlxColor = 0x000000;
		finalColor.red = cast Math.min(255, Math.max(0, color.red * 255));
		finalColor.green = cast Math.min(255, Math.max(0, color.green * 255));
		finalColor.blue = cast Math.min(255, Math.max(0, color.blue * 255));
		return finalColor;
	}
}
