package nebulatracer;

abstract ExtDynamic<T>(Dynamic) from T to T {}

class Global
{
	@:allow(nebulatracer.NebulaTracer)
	static var EMBREEID:Int = -1;

	public static function padArrayInt(arr:Array<Int>, len:Int, value:Int = 0):Array<Int>
	{
		while (arr.length < len)
		{
			arr.push(value);
		}
		return arr;
	}

	public static function padArrayFloat(arr:Array<Float>, len:Float, value:Float = 0):Array<Float>
	{
		while (arr.length < len)
		{
			arr.push(value);
		}
		return arr;
	}
}
