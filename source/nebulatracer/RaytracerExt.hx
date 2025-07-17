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

	public function traceRays4(id:Int, rays:Array<ExtDynamic<SimpleRay>>):Array<Dynamic>
	{
		switch (engine)
		{
			case EMBREE:
				var res = Embree.trace_rays4_embree(id, rays[0], rays[1], rays[2], rays[3]);
				return [
					{hit: res.hit1, geomID: res.geomID1},
					{hit: res.hit2, geomID: res.geomID2},
					{hit: res.hit3, geomID: res.geomID3},
					{hit: res.hit4, geomID: res.geomID4}
				];
			default:
		}
		return null;
	}

	public function traceRays8(id:Int, rays:Array<ExtDynamic<SimpleRay>>):Array<Dynamic>
	{
		switch (engine)
		{
			case EMBREE:
				var res = Embree.trace_rays8_embree(id, rays[0], rays[1], rays[2], rays[3], rays[4], rays[5], rays[6], rays[7]);
				return [
					{hit: res.hit1, geomID: res.geomID1},
					{hit: res.hit2, geomID: res.geomID2},
					{hit: res.hit3, geomID: res.geomID3},
					{hit: res.hit4, geomID: res.geomID4},
					{hit: res.hit5, geomID: res.geomID5},
					{hit: res.hit6, geomID: res.geomID6},
					{hit: res.hit7, geomID: res.geomID7},
					{hit: res.hit8, geomID: res.geomID8}
				];
			default:
		}
		return null;
	}

	public function traceRays16(id:Int, rays:Array<ExtDynamic<SimpleRay>>, valid:Array<Int>):Array<Dynamic>
	{
		switch (engine)
		{
			case EMBREE:
				var res = Embree.trace_rays16_embree(id, rays[0], rays[1], rays[2], rays[3], rays[4], rays[5], rays[6], rays[7], rays[8], rays[9], rays[10],
					rays[11], rays[12], rays[13], rays[14], rays[15], valid[0], valid[1], valid[2], valid[3], valid[4], valid[5], valid[6], valid[7],
					valid[8], valid[9], valid[10], valid[11], valid[12], valid[13], valid[14], valid[15]);
				return [
					{hit: res.hit1, geomID: res.geomID1},
					{hit: res.hit2, geomID: res.geomID2},
					{hit: res.hit3, geomID: res.geomID3},
					{hit: res.hit4, geomID: res.geomID4},
					{hit: res.hit5, geomID: res.geomID5},
					{hit: res.hit6, geomID: res.geomID6},
					{hit: res.hit7, geomID: res.geomID7},
					{hit: res.hit8, geomID: res.geomID8},
					{hit: res.hit9, geomID: res.geomID9},
					{hit: res.hit10, geomID: res.geomID10},
					{hit: res.hit11, geomID: res.geomID11},
					{hit: res.hit12, geomID: res.geomID12},
					{hit: res.hit13, geomID: res.geomID13},
					{hit: res.hit14, geomID: res.geomID14},
					{hit: res.hit15, geomID: res.geomID15},
					{hit: res.hit16, geomID: res.geomID16}
				];
			default:
		}
		return null;
	}
}
