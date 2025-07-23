package nebulatracer;

import hl.F32;
import nebulatracer.Global.ExtDynamic;
import nebulatracer.NebulaTracer.SimpleRay;
import nebulatracer.native.Embree;

class TraceResult
{
	public var hit:Bool;
	public var distance:F32;
	public var geomID:Int;
	public var primID:Int;

	public function new() {}
}

class RaytracerExt
{
	public function new() {}

	public function newRaytracer()
	{
		Embree.new_embree();
	}

	public function dispose(id:Int)
	{
		Embree.dispose_raytracer_embree(id);
	}

	public function buildBVH(id:Int)
	{
		Embree.build_bvh_embree(id);
	}

	public function refitBVH(id:Int)
	{
		Embree.refit_bvh_embree(id);
	}

	public function rebuildBVH(id:Int)
	{
		Embree.rebuild_bvh_embree(id);
	}

	public function loadGeometry(geometry:String, id:Int)
	{
		Embree.load_geometry_embree(geometry, id);
	}

	public function traceRay(id:Int, ray:SimpleRay):TraceResult
	{
		var result = Embree.trace_ray_embree(id, ray);
		return result;
	}
}
