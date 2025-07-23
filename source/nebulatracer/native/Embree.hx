package nebulatracer.native;

import nebulatracer.RaytracerExt.TraceResult;
import nebulatracer.NebulaTracer.SimpleRay;
import nebulatracer.Global.ExtDynamic;

@:hlNative("nebulatracer")
@:noCompletion
class Embree
{
	public static function new_embree():Void {}

	public static function dispose_raytracer_embree(id:Int):Void {}

	public static function build_bvh_embree(id:Int):Void {}

	public static function refit_bvh_embree(id:Int):Void {}

	public static function rebuild_bvh_embree(id:Int):Void {}

	public static function dummy_func():Void {}

	public static function load_geometry_embree(string:String, id:Int):Void {}

	public static function trace_ray_embree(id:Int, ray:SimpleRay):TraceResult
		return null;
}
