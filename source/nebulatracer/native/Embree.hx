package nebulatracer.native;

import hl.NativeArray;
import nebulatracer.NebulaTracer.SimpleRay;
import nebulatracer.RaytracerExt.ExtDynamic;

@:hlNative("nebulatracer")
class Embree
{
	public static function new_embree():Void {}

	public static function dispose_raytracer_embree(id:Int):Void {}

	public static function build_bvh_embree(id:Int):Void {}

	public static function refit_bvh_embree(id:Int):Void {}

	public static function rebuild_bvh_embree(id:Int):Void {}

	public static function load_geometry_embree(string:String, id:Int):Void {}

	public static function trace_ray_embree(id:Int, ray:Dynamic):Dynamic
		return null;

	public static function trace_rays4_embree(id:Int, ray1:Dynamic, ray2:Dynamic, ray3:Dynamic, ray4:Dynamic):Dynamic
		return null;

	public static function trace_rays8_embree(id:Int, ray1:Dynamic, ray2:Dynamic, ray3:Dynamic, ray4:Dynamic, ray5:Dynamic, ray6:Dynamic, ray7:Dynamic,
			ray8:Dynamic):Dynamic
		return null;

	public static function trace_rays16_embree(id:Int, ray1:Dynamic, ray2:Dynamic, ray3:Dynamic, ray4:Dynamic, ray5:Dynamic, ray6:Dynamic, ray7:Dynamic,
			ray8:Dynamic, ray9:Dynamic, ray10:Dynamic, ray11:Dynamic, ray12:Dynamic, ray13:Dynamic, ray14:Dynamic, ray15:Dynamic, ray16:Dynamic, valid1:Int,
			valid2:Int, valid3:Int, valid4:Int, valid5:Int, valid6:Int, valid7:Int, valid8:Int, valid9:Int, valid10:Int, valid11:Int, valid12:Int,
			valid13:Int, valid14:Int, valid15:Int, valid16:Int):Dynamic
		return null;
}
