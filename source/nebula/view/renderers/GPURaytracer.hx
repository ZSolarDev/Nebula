package nebula.view.renderers;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxRuntimeShader;
import nebula.tonemapper.*;
import nebula.view.renderers.Raytracer.FloatColor;
import sys.io.File;

class GPURaytracer extends Raytracer
{
	public var tonemapper:Tonemapper = new ClampTonemapper();
	public var skyColor:FloatColor = new FloatColor(0, 0, 0);
	public var globalIllum:FlxSprite;
	public var giSamples:Int = 32;
	public var bounceLightRandomness = 0.1;
	public var shadowsRandomness = 0.1;
	public var shader:GPURaytracerShader = new GPURaytracerShader();

	override public function new(view:N3DView)
	{
		super(view);
		globalIllum = new FlxSprite();
		globalIllum.makeGraphic(view.width, view.height, 0x000000);
		FlxG.state.add(globalIllum);
		// globalIllum.shader = shader;
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);
		shader.setInt('width', view.width);
		shader.setInt('height', view.height);
		shader.setFloat('camX', view.camX);
		shader.setFloat('camY', view.camY);
		shader.setFloat('camZ', view.camZ);
		shader.setFloat('camPitch', view.camPitch);
		shader.setFloat('camYaw', view.camYaw);
		shader.setFloat('fov', view.fov);
		shader.setInt('giSamples', giSamples);
		shader.setFloat('bounceLightRandomness', bounceLightRandomness);
		shader.setFloat('shadowsRandomness', shadowsRandomness);
		/*
			uniform float vertices[1000];
			uniform float normals[1000];
			uniform float indices[1000];
			uniform int objectCount;
			uniform int objectSeparators[1000];
		 */
		shader.setFloatArray('vertices', [0.0]);
		shader.setFloatArray('normals', [0.0]);
		shader.setFloatArray('indices', [0.0]);
		shader.setInt('objectCount', 0);
		shader.setIntArray('objectSeparators', [0]);
		rendering = false;
	}
}

private class GPURaytracerShader extends FlxRuntimeShader
{
	override public function new()
	{
		super(File.getContent('assets/gpu_raytracer.frag'));
	}
}
