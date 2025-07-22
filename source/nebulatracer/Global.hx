package nebulatracer;

abstract ExtDynamic<T>(Dynamic) from T to T {}

class Global
{
	@:allow(nebulatracer.NebulaTracer)
	static var EMBREEID:Int = -1;
	// @:allow(nebulatracer.ComputeShader)
	// static var SHADERID:Int = -1;
}
