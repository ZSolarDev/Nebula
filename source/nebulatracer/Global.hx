package nebulatracer;

abstract ExtDynamic<T>(Dynamic) from T to T {}

class Global
{
	@:allow(nebulatracer.NebulaTracer)
	static var EMBREEID:Int = -1;

	public function padArrayInt(arr:Array<Int>, len:Int):Array<Int>
	{
		while (arr.length < len)
		{
			arr.push(0);
		}
		return arr;
	}

	public function padArrayFloat(arr:Array<Float>, len:Float):Array<Float>
	{
		while (arr.length < len)
		{
			arr.push(0.0);
		}
		return arr;
	}
}
