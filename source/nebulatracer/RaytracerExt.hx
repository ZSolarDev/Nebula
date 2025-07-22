package nebulatracer;

import nebulatracer.Embree;
import nebulatracer.NebulaTracer.SimpleRay;

abstract ExtDynamic<T>(Dynamic) from T to T {}

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

	public function traceRay(id:Int, ray:ExtDynamic<SimpleRay>):Dynamic
		return Embree.trace_ray_embree(id, ray);
}
