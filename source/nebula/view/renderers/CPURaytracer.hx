package nebula.view.renderers;

import flixel.FlxG;
import flixel.FlxSprite;
import lime.utils.Log;
import nebula.mesh.MeshPart;
import nebula.tonemapper.*;
import nebula.utils.Vec3DHelper;
import nebula.view.renderers.Raytracer.FloatColor;
import nebulatracer.NebulaTracer.Ray;
import nebulatracer.RaytracerExt.TraceResult;
import openfl.geom.Rectangle;
import openfl.geom.Vector3D;

class CPURaytracer extends Raytracer
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
	}

	public function traceRay(ray:Ray):{hit:Bool, color:FloatColor}
	{
		var color:FloatColor = new FloatColor(0, 0, 0);
		var res:TraceResult = raytracer.traceRay(ray);
		if (res.hit)
		{
			var part = geom[res.geomID];
			var hitPos = Vec3DHelper.add(ray.pos, Vec3DHelper.multiplyScalar(ray.dir, res.distance));
			if (part.raytracingProperties.isEmitter)
				color = part._color;
			else
			{
				for (light in lights)
				{
					var toLight = Vec3DHelper.subtract(light.pos, hitPos);
					var dirToLight = Vec3DHelper.normalize(toLight);
					var coneAngle = 0.13;
					var shadowSamples = 16;
					var litCount = 0;

					var coneSampleDirs = generateConeSamples(dirToLight, coneAngle, shadowSamples);

					for (sampleDir in coneSampleDirs)
					{
						var shadowRay:Ray = {
							pos: Vec3DHelper.add(hitPos, Vec3DHelper.multiplyScalar(sampleDir, 0.001)),
							dir: sampleDir
						};

						var shadowRes = raytracer.traceRay(shadowRay);
						if (shadowRes.hit)
							if (geom[shadowRes.geomID] == light.meshPart)
								litCount++;
					}

					var shadowStrength = litCount / shadowSamples; // between 0 and 1

					var diff = Vec3DHelper.subtract(light.pos, hitPos);
					var distFalloff = 1.0 - (diff.length / light.power);
					distFalloff = Math.max(0, distFalloff);
					var darkenedSkyColor = FloatColor.multiplyFloat(skyColor, (1 - shadowStrength) * 0.1);
					var finalPartColor = FloatColor.lerpColor(part._color, darkenedSkyColor, (1 - shadowStrength) * 0.9);
					var baseDarkened = FloatColor.multiplyFloat(finalPartColor, distFalloff + 0.001);
					var lightIntensity = distFalloff * shadowStrength;
					var lightSaturation = rgbToSaturation(light.color.red, light.color.green, light.color.blue);
					var lightDivisor = 15 * (1 - lightSaturation) + 1 * lightSaturation;
					lightIntensity = Math.min(1, lightIntensity / lightDivisor);
					color = FloatColor.addColor(color, FloatColor.lerpColor(baseDarkened, light.color, lightIntensity));
				}
			}
			var hemisphereSamples = generateHemisphereSamples(32);

			var colors = [];
			for (sample in hemisphereSamples)
			{
				var normal = getTriangleNormal(part, res.primID);
				var sampleDir = alignSampleToNormal(sample, normal);

				var bounceRay:Ray = {
					pos: Vec3DHelper.add(hitPos, Vec3DHelper.multiplyScalar(sampleDir, 0.001)),
					dir: sampleDir
				};

				var bounceRes = raytracer.traceRay(bounceRay);
				if (bounceRes.hit)
				{
					var bouncePart = geom[bounceRes.geomID];
					colors.push(bouncePart._color);
				}
				else
				{
					var ndotl = Math.max(0, Vec3DHelper.dot(sampleDir, normal));
					var envLight = FloatColor.multiplyFloat(skyColor, ndotl * 0.3);
					colors.push(envLight);
				}
			}

			var bounceLight = averageColors(colors);
			color = FloatColor.addColor(color, bounceLight);

			return {hit: true, color: color};
		}
		else
		{
			return {hit: false, color: skyColor};
		}
	}

	function generateHemisphereSamples(num:Int):Array<Vector3D>
	{
		var samples = new Array<Vector3D>();
		var offset = 2.0 / num;
		var increment = Math.PI * (3.0 - Math.sqrt(5.0));

		for (i in 0...num)
		{
			var y_base = 1.0 - (i * offset);
			var r_base = Math.sqrt(1.0 - y_base * y_base);
			var phi_base = i * increment;
			var x_base = Math.cos(phi_base) * r_base;
			var z_base = Math.sin(phi_base) * r_base;

			var u = Math.random();
			var v = Math.random();
			var theta = 2.0 * Math.PI * u;
			var y_rand = v;
			var r_rand = Math.sqrt(1.0 - y_rand * y_rand);
			var x_rand = Math.cos(theta) * r_rand;
			var z_rand = Math.sin(theta) * r_rand;

			var x = x_base * (1.0 - bounceLightRandomness) + x_rand * bounceLightRandomness;
			var y = y_base * (1.0 - bounceLightRandomness) + y_rand * bounceLightRandomness;
			var z = z_base * (1.0 - bounceLightRandomness) + z_rand * bounceLightRandomness;

			var len = Math.sqrt(x * x + y * y + z * z);
			samples.push(new Vector3D(x / len, y / len, z / len));
		}

		return samples;
	}

	public function getTriangleNormal(part:MeshPart, primID:Int):Vector3D
	{
		var i0 = part.indices[primID * 3];
		var i1 = part.indices[primID * 3 + 1];
		var i2 = part.indices[primID * 3 + 2];

		var v0 = part.vertices[i0];
		var v1 = part.vertices[i1];
		var v2 = part.vertices[i2];

		var edge1 = Vec3DHelper.subtract(v1, v0);
		var edge2 = Vec3DHelper.subtract(v2, v0);

		var normal = Vec3DHelper.cross(edge1, edge2);
		return Vec3DHelper.normalize(normal);
	}

	function generateConeSamples(dirToLight:Vector3D, coneAngle:Float, sampleCount:Int):Array<Vector3D>
	{
		var samples = new Array<Vector3D>();

		var up = Math.abs(dirToLight.y) < 0.999 ? new Vector3D(0, 1, 0) : new Vector3D(1, 0, 0);
		var tangent = Vec3DHelper.normalize(Vec3DHelper.cross(dirToLight, up));
		var bitangent = Vec3DHelper.normalize(Vec3DHelper.cross(tangent, dirToLight));

		for (i in 0...sampleCount)
		{
			var detPhi = (i + 0.5) / sampleCount * Math.PI * 2;
			var detCosTheta = 1 - (i + 0.5) / sampleCount * (1 - Math.cos(coneAngle));

			var randPhi = Math.random() * Math.PI * 2;
			var randCosTheta = 1 - Math.random() * (1 - Math.cos(coneAngle));

			var phi = detPhi * (1 - shadowsRandomness) + randPhi * shadowsRandomness;
			var cosTheta = detCosTheta * (1 - shadowsRandomness) + randCosTheta * shadowsRandomness;
			var sinTheta = Math.sqrt(1 - cosTheta * cosTheta);

			var sampleDir = new Vector3D(Math.cos(phi) * sinTheta, cosTheta, Math.sin(phi) * sinTheta);

			var worldDir = new Vector3D(tangent.x * sampleDir.x
				+ dirToLight.x * sampleDir.y
				+ bitangent.x * sampleDir.z,
				tangent.y * sampleDir.x
				+ dirToLight.y * sampleDir.y
				+ bitangent.y * sampleDir.z,
				tangent.z * sampleDir.x
				+ dirToLight.z * sampleDir.y
				+ bitangent.z * sampleDir.z);

			samples.push(Vec3DHelper.normalize(worldDir));
		}

		return samples;
	}

	function rgbToSaturation(r:Float, g:Float, b:Float):Float
	{
		var max = Math.max(r, Math.max(g, b));
		var min = Math.min(r, Math.min(g, b));
		var delta = max - min;

		if (max == 0)
			return 0;

		return delta / max;
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

	public function alignSampleToNormal(sample:Vector3D, normal:Vector3D):Vector3D
	{
		var up = Math.abs(normal.y) < 0.999 ? new Vector3D(0, 1, 0) : new Vector3D(1, 0, 0);
		var tangent = Vec3DHelper.normalize(Vec3DHelper.cross(normal, up));
		var bitangent = Vec3DHelper.normalize(Vec3DHelper.cross(normal, tangent));

		var worldSample = new Vector3D(tangent.x * sample.x
			+ bitangent.x * sample.z
			+ normal.x * sample.y,
			tangent.y * sample.x
			+ bitangent.y * sample.z
			+ normal.y * sample.y, tangent.z * sample.x
			+ bitangent.z * sample.z
			+ normal.z * sample.y);

		return Vec3DHelper.normalize(worldSample);
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
						Log.throwErrors = false;
						Log.error('Error tracing ray at (x, y)[$x, $y]: ${e.toString()}');
						Log.throwErrors = true;
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
