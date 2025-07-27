package nebulatracer.native;

import hl.Bytes;

@:hlNative("nebulatracer")
@:noCompletion
class Compute
{
	public static function init_vulkan():Void {}

	public static function create_compute_shader(source:String):Void {}

	public static function destroy_compute_shader():Void {}

	public static function destroy_vulkan():Void {}

	public static function run_compute_shader(dataIn:Bytes, sizeBytesIn:Int, sizeBytesOut:Int, groupsX:Int, groupsY:Int, groupsZ:Int):Bytes
		return null;
}
