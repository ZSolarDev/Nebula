package nebula.view.renderers;

import flixel.FlxG;
import flixel.FlxSprite;
import lime.utils.Log;
import nebula.mesh.MeshPart;
import nebula.tonemapper.*;
import nebula.utils.Vec3DHelper;
import nebula.view.renderers.Raytracer.FloatColor;
import nebulatracer.ComputeShaders;
import nebulatracer.Global;
import nebulatracer.NebulaTracer.Ray;
import nebulatracer.RaytracerExt.TraceResult;
import openfl.geom.Rectangle;
import openfl.geom.Vector3D;
import sys.io.File;

class GPURaytracer extends Raytracer
{
	public var tonemapper:Tonemapper = new ClampTonemapper();
	public var giRes:Int = 1;
	public var skyColor:FloatColor = new FloatColor(0, 0, 0);
	public var globalIllum:FlxSprite;
	public var clearFrame:Bool = true;
	public var numBounces:Int = 1;
	public var giSamples:Int = 32;
	public var bounceLightRandomness = 0.1;
	public var shadowsRandomness = 0.1;

	override public function new(view:N3DView)
	{
		super(view);
		globalIllum = new FlxSprite();
		globalIllum.makeGraphic(view.width, view.height, tonemapper.map(skyColor));
		globalIllum.pixels.fillRect(new Rectangle(0, 0, view.width, view.height), tonemapper.map(skyColor));
		FlxG.state.add(globalIllum);
		ComputeShaders.initVulkan();
		ComputeShaders.createComputeShader(File.getContent("assets/traceRay.comp"));
	}

	public function traceRay(ray:Ray):{hit:Bool, color:FloatColor}
	{
		var inputRay = {
			origin: [ray.pos.x, ray.pos.y, ray.pos.z],
			direction: [ray.dir.x, ray.dir.y, ray.dir.z]
		}
		// input, output schema, groupsx, y, and z
		var outSchema:Array<Float> = [];
		outSchema.resize(1280 * 720 * 3);
		var res:Array<Float> = cast ComputeShaders.runComputeShaderDynInDeserialize(inputRay, outSchema, 1280 * 720, 1, 1);
		return {hit: true, color: new FloatColor(res[0], res[1], res[2])};
	}

	public function pixelToWorld(x:Float, y:Float):Ray
	{
		final fov = view.fov;
		final aspectRatio = view.width / view.height;

		var ndcX = (2 * x) / view.width - 1;
		var ndcY = (2 * y) / view.height - 1;

		var fovRad = Math.PI * fov / 180;
		var tanFov = Math.tan(fovRad / 2);

		var camX = ndcX * aspectRatio * tanFov;
		var camY = ndcY * tanFov;
		var camZ = -1;

		var dir = new Vector3D(camX, camY, camZ);
		dir.normalize();

		var yaw = view.camYaw;
		var pitch = view.camPitch;

		// --- Apply Pitch (X axis) ---
		var cosPitch = Math.cos(pitch);
		var sinPitch = Math.sin(pitch);

		var y1 = dir.y * cosPitch - dir.z * sinPitch;
		var z1 = dir.y * sinPitch + dir.z * cosPitch;
		var x1 = dir.x;

		// --- Apply Yaw (Y axis) after pitch ---
		var cosYaw = Math.cos(yaw);
		var sinYaw = Math.sin(yaw);

		var x2 = x1 * cosYaw - z1 * sinYaw;
		var z2 = x1 * sinYaw + z1 * cosYaw;

		dir.setTo(x2, y1, z2);
		dir.normalize();

		var ray:Ray = {
			pos: new Vector3D(view.camX, view.camY, view.camZ),
			dir: dir
		};
		return ray;
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);
		if (clearFrame)
		{
			globalIllum.pixels.lock();
			globalIllum.pixels.fillRect(new Rectangle(0, 0, view.width, view.height), tonemapper.map(skyColor));
			globalIllum.pixels.unlock();
		}
		var colors = [];
		{
			for (y in 0...view.height)
			{
				if (y % giRes != 0)
					continue;

				for (x in 0...view.width)
				{
					if (x % giRes != 0)
						continue;

					var ray = pixelToWorld(x, y);
					var res:{hit:Bool, color:FloatColor} = {hit: false, color: skyColor};
					try
					{
						res = traceRay(ray);
					}
					catch (e)
					{
						Log.error('Error tracing ray at (x, y)[$x, $y]: ${e.message}${e.stack.toString()}');
					}
					var color = res.color;
					var finalColor = tonemapper.map(color);
					finalColor.alpha = 255;
					globalIllum.pixels.lock();
					globalIllum.pixels.fillRect(new Rectangle(x, y, giRes, giRes), finalColor);
					globalIllum.pixels.unlock();
					prog++;
				}
			}
		}
		rendering = false;
	}
}
