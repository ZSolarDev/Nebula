package nebulatracer;

import hl.NativeArray;
import nebulatracer.NebulaTracer.NTracerEngine;
import nebulatracer.NebulaTracer.SimpleRay;
import nebulatracer.native.Embree;

abstract ExtDynamic<T>(Dynamic) from T to T {}

class RaytracerExt
{
	public var engine:NTracerEngine;

	public function new(engine:NTracerEngine)
	{
		this.engine = engine;
	}

	public function newRaytracer()
	{
		switch (engine)
		{
			case EMBREE:
				Embree.new_embree();
			default:
		}
	}

	public function dispose(id:Int)
	{
		switch (engine)
		{
			case EMBREE:
				Embree.dispose_raytracer_embree(id);
			default:
		}
	}

	public function buildBVH(id:Int)
	{
		switch (engine)
		{
			case EMBREE:
				Embree.build_bvh_embree(id);
			default:
		}
	}

	public function refitBVH(id:Int)
	{
		switch (engine)
		{
			case EMBREE:
				Embree.refit_bvh_embree(id);
			default:
		}
	}

	public function rebuildBVH(id:Int)
	{
		switch (engine)
		{
			case EMBREE:
				Embree.rebuild_bvh_embree(id);
			default:
		}
	}

	public function loadGeometry(geometry:String, id:Int)
	{
		switch (engine)
		{
			case EMBREE:
				Embree.load_geometry_embree(geometry, id);
			default:
		}
	}

	public function traceRay(id:Int, ray:ExtDynamic<SimpleRay>):Dynamic
	{
		switch (engine)
		{
			case EMBREE:
				return Embree.trace_ray_embree(id, ray);
			default:
		}
		return null;
	}

	public function traceRays(id:Int, rays:Array<Dynamic>, traceRaysCallback:Dynamic->Void)
	{
		switch (engine)
		{
			case EMBREE:
				Embree.set_callback_embree(traceRaysCallback);
				Embree.trace_rays_embree(id, rays.length, arrayToNativeArray(rays));
			default:
		}
		return null;
	}

	function arrayToNativeArray(arr:Array<Dynamic>):NativeArray<Dynamic>
	{
		var nativeArr = new NativeArray<Dynamic>(arr.length);
		for (i in 0...arr.length)
		{
			nativeArr[i] = arr[i];
		}
		return nativeArr;
	}

	function nativeArrayToArray(nativeArr:hl.NativeArray<Dynamic>):Array<Dynamic>
	{
		var result = [];
		for (i in 0...nativeArr.length)
		{
			result.push(nativeArr[i]);
		}
		return result;
	}
}
