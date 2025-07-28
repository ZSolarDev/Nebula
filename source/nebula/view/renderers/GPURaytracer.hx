package nebula.view.renderers;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxRuntimeShader;
import flixel.util.FlxColor;
import nebula.tonemapper.*;
import nebula.view.renderers.Raytracer.FloatColor;
import nebulatracer.ComputeShaders;
import sys.io.File;

using StringTools;

typedef GPUBufferData =
{
	var width:Int;
	var height:Int;
	var camX:Float;
	var camY:Float;
	var camZ:Float;
	var camPitch:Float;
	var camYaw:Float;
	var fov:Float;
	var giSamples:Int;
	var bounceLightRandomness:Float;
	var shadowsRandomness:Float;
}

typedef RGB =
{
	var red:Int;
	var green:Int;
	var blue:Int;
}

class GPURaytracer extends Raytracer
{
	public var tonemapper:Tonemapper = new ClampTonemapper();
	public var skyColor:FloatColor = new FloatColor(0, 0, 0);
	public var globalIllum:FlxSprite;
	public var giSamples:Int = 32;
	public var bounceLightRandomness = 0.1;
	public var shadowsRandomness = 0.1;
	public var gpuBuffer:GPUBufferData = null;

	var outSchema:Array<RGB> = [];

	override public function new(view:N3DView)
	{
		super(view);
		globalIllum = new FlxSprite();
		globalIllum.makeGraphic(view.width, view.height, 0x000000);
		ComputeShaders.initVulkan();
		ComputeShaders.createComputeShader(File.getContent("assets/gpu_raytracer.comp").replace('__PXWIDTH', '$width').replace('__PXHEIGHT', '$height'));

		for (i in 0...cast width * height)
			outSchema.push({red: 0, green: 0, blue: 0});
		FlxG.state.add(globalIllum);
		// globalIllum.shader = shader;
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);
		gpuBuffer = {
			width: width,
			height: height,
			camX: view.camX,
			camY: view.camY,
			camZ: view.camZ,
			camPitch: view.camPitch,
			camYaw: view.camYaw,
			fov: view.fov,
			giSamples: giSamples,
			bounceLightRandomness: bounceLightRandomness,
			shadowsRandomness: shadowsRandomness
		};

		var res = ComputeShaders.runComputeShaderDynInDeserialize(gpuBuffer, outSchema, cast width / 16, cast height / 16, 1);
		// trace(res);
		for (x in 0...width)
		{
			for (y in 0...height)
			{
				var idx = y * width + x;
				globalIllum.pixels.setPixel(x, y, FlxColor.fromRGB(res[idx].red, res[idx].green, res[idx].blue));
			}
		}
		rendering = false;
	}
}
