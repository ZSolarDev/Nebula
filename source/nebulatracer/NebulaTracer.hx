package nebulatracer;

import haxe.Timer;
import hl.F32;
import nebulatracer.RaytracerExt.TraceResult;
import openfl.geom.Vector3D;

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
class SimpleRay
{
	public var posx:F32;
	public var posy:F32;
	public var posz:F32;
	public var dirx:F32;
	public var diry:F32;
	public var dirz:F32;

	public function new() {}
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
	 */
	public function new()
	{
		_ID = Global.EMBREEID + 1;
		Global.EMBREEID = _ID;
		_raytracerExt = new RaytracerExt();
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
	 * Rebuilds the BVH.
	 */
	public function rebuildBVH()
	{
		_raytracerExt.rebuildBVH(_ID);
	}

	/**
	 * Traces a ray.
	 * @param ray The ray to trace with.
	 */
	public function traceRay(ray:Ray):TraceResult
	{
		var simpleRay = NTUtils.simplifyRay(ray);
		return _raytracerExt.traceRay(_ID, simpleRay);
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
