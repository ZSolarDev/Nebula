package nebulatracer;

import flixel.util.typeLimit.OneOfThree;
import nebulatracer.NebulaTracer.NTracerEngine;
import nebulatracer.NebulaTracer.Ray;
import nebulatracer.NebulaTracer.SimpleRay;
import nebulatracer.native.*;

class NTUtils
{
	public static function simplifyRay(ray:Ray):SimpleRay
		return {
			posx: ray.pos.x,
			posy: ray.pos.y,
			posz: ray.pos.z,
			dirx: ray.dir.x,
			diry: ray.dir.y,
			dirz: ray.dir.z
		};
}
