package;

import flixel.FlxG;
import flixel.FlxGame;
import nebulatracer.ComputeExt;
import openfl.display.Sprite;

class Main extends Sprite
{
	public function new()
	{
		super();
		ComputeExt.initCompute();
		ComputeExt.runCompute();
		addChild(new FlxGame(0, 0, PlayState));
		FlxG.autoPause = false;
	}
}
