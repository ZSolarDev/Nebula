package;

import flixel.FlxG;
import flixel.FlxGame;
import nebulatracer.ComputeExt;
import openfl.display.Sprite;

class Main extends Sprite
{
	public function new()
	{
		// ComputeExt.testCompute();
		super();
		addChild(new FlxGame(0, 0, PlayState));
		FlxG.autoPause = false;
	}
}
