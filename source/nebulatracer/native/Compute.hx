package nebulatracer.native;

import hl.Bytes;

@:hlNative("nebulatracer")
@:noCompletion
class Compute
{
	public static function init_opengl():Void {}

	public static function load_compute_shader(source:String):Void {}

	public static function run_compute_shader(dataIn:Bytes, groupsX:Int, groupsY:Int, groupsZ:Int, sizeBytesIn:Int, sizeBytesOut:Int):Bytes
		return null;
}
