package nebulatracer;

import openfl.geom.Vector3D;

/**
 * The type of raytracer to use.
 * @see `NebulaTracer.engine`
 */
enum abstract NTracerEngine(Int)
{
	var DXRAYTRACER = 0;
	var EMBREE = 1;
	var OPTIX = 2;
}

/**
 * The update mode of the BVH.
 * @see `NebulaTracer.bvhUpdateMode`
 */
enum abstract BVHUpdateMode(Int)
{
	var REFIT = 0;
	var REBUILD = 1;
}

/**
 * A ray. (duh..)
 */
typedef Ray =
{
	var pos:Vector3D;
	var dir:Vector3D;
}

/**
 * A simplified ray to interact directly with the externs.
 */
typedef SimpleRay =
{
	var posx:Float;
	var posy:Float;
	var posz:Float;
	var dirx:Float;
	var diry:Float;
	var dirz:Float;
}

/**
 * This is an abstraction layer for use with 3 different raytracing engines:
 * DXRAYTRACER(DirectX Raytracer), EMBREE(Embree), and OPTIX(OptiX).
 * See `NebulaTracer.engine` for a description of each engine.
 * 
 * Handles building(`buildBVH`), refitting(`refitBVH`), and rebuilding(`rebuildBVH`) the bounding volume hierarchy (BVH)
 * to optimize ray traversal depending on how the scene changes. **BVH Refitting is not supported on Embree.**
 * 
 * You can use `traceRay` to trace a ray through the scene and get the result,
 * or `traceRays` to trace multiple rays at once. (Much faster on Embree.)
 * 
 * You can run `dispose` to free up resources once this raytracer isn't needed.
 * 
 * TODO: When complete, make a simple tutorial here on how to use NebulaTracer.
 */
class NebulaTracer
{
	private var _ID:Int = 0;
	private var _raytracerExt:RaytracerExt;

	/**
	 * The engine this raytracer is using:
	 * 
	 * - **DXRAYTRACER (DirectX Raytracer)**:  
	 *   A GPU raytracer that is compatible with Windows systems with DirectX12 and above,  
	 *   as well as a compatible GPU (NVIDIA, AMD, Intel, etc).
	 * 
	 * - **EMBREE (Embree)**:  
	 *   A high-performance CPU raytracer that is compatible with most platforms.  
	 *   Slower than DXRAYTRACER and OPTIX but still reliable.
	 * 
	 * - **OPTIX (OptiX)**:  
	 *   A GPU raytracer meant specifically for NVIDIA GPUs using CUDA.
	 * 
	 * 
	 * This variable cannot be changed after initialization!
	 */
	public var engine:FinalOnce<NTracerEngine>;

	/**
	 * The geometry of the scene to be raytraced.  
	 * TODO: Define a JSON format for geometry that the externs can parse
	 * 
	 * You must call `rebuildBVH` or `refitBVH` after setting the geometry, if not it will lead to undefined behavior.
	 */
	public var geometry(default, set):String = '';

	function set_geometry(val:String)
	{
		geometry = val;
		_raytracerExt.loadGeometry(val, _ID);
		return val;
	}

	/**
	 * Creates a new NebulaTracer.
	 * @param engine The engine this raytracer should use.
	 * - **DXRAYTRACER (DirectX Raytracer)**:  
	 *   A GPU raytracer that is compatible with Windows systems with DirectX12 and above,  
	 *   as well as a compatible GPU (NVIDIA, AMD, Intel, etc).
	 * 
	 * - **EMBREE (Embree)**:  
	 *   A high-performance CPU raytracer that is compatible with most platforms.  
	 *   Slower than DXRAYTRACER and OPTIX but still reliable.
	 * 
	 * - **OPTIX (OptiX)**:  
	 *   A GPU raytracer meant specifically for NVIDIA GPUs using CUDA.
	 * 
	 * 
	 * This variable cannot be changed after initialization!
	 */
	public function new(engine:NTracerEngine)
	{
		switch (engine)
		{
			case DXRAYTRACER:
				_ID = Global.DXRID + 1;
				Global.DXRID = _ID;
			case EMBREE:
				_ID = Global.EMBREEID + 1;
				Global.EMBREEID = _ID;
			case OPTIX:
				_ID = Global.OPTIXID + 1;
				Global.OPTIXID = _ID;
		}

		this.engine = engine;
		_raytracerExt = new RaytracerExt(engine);
		_raytracerExt.newRaytracer();
	}

	/**
	 * This fucntion builds the bounding volume hierarchy (BVH) of the scene.
	 * You must call this function after setting the geometry, if not it will lead to undefined behavior.
	 */
	public function buildBVH()
	{
		_raytracerExt.buildBVH(_ID);
	}

	/**
	 * Refits the BVH. This function:
	 * - Quickly changes the existing BVH to fit the new geometry.
	 *   This is reccomended for small geometry changes for its speed. However,
	 *   if the geometry changes drastically, ray traversal may not be as
	 *   efficient. This in turn lowers performance. If you have to update the
	 *   BVH and your geometry changed drastically, use `rebuildBVH` instead.
	 *  **THIS OPTION IS NOT SUPPORTED ON EMBREE, IT WILL TO REBUILD INSTEAD!**
	 *  
	 *   TLDR: Use only if the scene geometry doesnt stray too far from the last rebuild.
	 */
	public function refitBVH()
	{
		_raytracerExt.refitBVH(_ID);
	}

	/**
	 * Rebuilds the BVH. This function:
	 * - Remakes the entire BVH from scratch.
	 *   Takes more time, but ensures that ray traversal is as efficient as
	 *   possible. This should be used when the geometry changes drastically.
	 *   If your geometry hasnt strayed too far from the last rebuild, use `refitBVH` instead.
	 * 
	 *   TLDR: Use only if the scene geometry changes drastically.
	 */
	public function rebuildBVH()
	{
		_raytracerExt.rebuildBVH(_ID);
	}

	/**
	 * Traces a ray.
	 * @param ray The ray to trace with.
	 * If you're using the Embree engine, you should use `traceRays` instead. It can actually be faster.
	 */
	public function traceRay(ray:Ray):{hit:Bool, geomID:Int}
	{
		var simpleRay = NTUtils.simplifyRay(ray);
		return cast _raytracerExt.traceRay(_ID, simpleRay);
	}

	/**
	 * Traces multiple rays. This can actually be faster than tracing a single ray, especially when using Embree.
	 * @param rays  A map of ray IDs to rays.
	 */
	public function traceRays(rays:Map<Int, Ray>, callback:{hit:Bool, geomID:Int, index:Int}->Void)
	{
		var simpleRays:Array<Dynamic> = [];

		for (k => ray in rays)
		{
			var dyn:Dynamic = {
				posx: ray.pos.x,
				posy: ray.pos.y,
				posz: ray.pos.z,
				dirx: ray.dir.x,
				diry: ray.dir.y,
				dirz: ray.dir.z
			};
			simpleRays.push(dyn);
		}

		_raytracerExt.traceRays(_ID, simpleRays, callback);
	}

	/**
	 * Disposes of this raytracer. This raytracer becomes unusable after running this.
	 * Running functions on this raytracer after calling dispose ***will*** result in undefined behavior.
	 */
	public function dispose()
	{
		_raytracerExt.dispose(_ID);
	}
}
