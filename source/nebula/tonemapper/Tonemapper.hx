package nebula.tonemapper;

import flixel.util.FlxColor;
import nebula.view.renderers.Raytracer.FloatColor;

interface Tonemapper
{
	public function map(color:FloatColor):FlxColor;
}
