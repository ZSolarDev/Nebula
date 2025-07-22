package nebulatracer.native;

import hl.Bytes;

@:hlNative("nebulatracer")
@:noCompletion
class Compute
{
	public static function init_opengl():Void {}

	public static function create_compute_shader(source:String):Void {}

	public static function remove_compute_shader(id:Int):Void {}

	public static function run_compute_shader(id:Int, dataIn:Bytes, groupsX:Int, groupsY:Int, groupsZ:Int, sizeBytesIn:Int, sizeBytesOut:Int):Bytes
		return null;

	public static function run_compute_shader_from_src(source:String, dataIn:Bytes, groupsX:Int, groupsY:Int, groupsZ:Int, sizeBytesIn:Int,
			sizeBytesOut:Int):Bytes
		return null;
}
