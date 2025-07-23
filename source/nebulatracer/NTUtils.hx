package nebulatracer;

import nebulatracer.NebulaTracer.Ray;
import nebulatracer.NebulaTracer.SimpleRay;

class NTUtils
{
	public static function simplifyRay(ray:Ray):SimpleRay {
		var simple = new SimpleRay();
		simple.posx = ray.pos.x;
		simple.posy = ray.pos.y;
		simple.posz = ray.pos.z;
		simple.dirx = ray.dir.x;
		simple.diry = ray.dir.y;
		simple.dirz = ray.dir.z;
		return simple;
	}
}
