package nebulatracer;

import haxe.io.Bytes;
import haxe.io.BytesOutput;
import nebulatracer.native.Compute;

class ComputeShaders
{
	public static var initialized:Bool = false;

	public static function initVulkan():Void
	{
		if (!initialized)
			Compute.init_vulkan();
		initialized = true;
	}

	public static function createComputeShader(source:String):Void
	{
		if (!initialized)
			return;

		Compute.create_compute_shader(source);
	}

	public static function destroyComputeShader():Void
	{
		if (!initialized)
			return;
		Compute.destroy_compute_shader();
	}

	public static function destroyVulkan():Void
	{
		if (!initialized)
			return;
		initialized = false;
		Compute.destroy_vulkan();
	}

	public static function runComputeShader(dataIn:Bytes, sizeBytesOut:Int, groupsX:Int, groupsY:Int, groupsZ:Int):hl.Bytes
		@:privateAccess return Compute.run_compute_shader(dataIn.b, dataIn.length, sizeBytesOut, groupsX, groupsY, groupsZ);

	public static function runComputeShaderDynIn(dataIn:Any, dataOutInBytes:Int, groupsX:Int, groupsY:Int, groupsZ:Int):hl.Bytes
	{
		var serialized = Serializer.serialize(dataIn);
		return Compute.run_compute_shader(serialized, serialized.length, dataOutInBytes, groupsX, groupsY, groupsZ);
	}

	public static function runComputeShaderDynInDynOutFormat(dataIn:Any, dataOutFormat:Any, groupsX:Int, groupsY:Int, groupsZ:Int):hl.Bytes
	{
		var serialized = Serializer.serialize(dataIn);
		return Compute.run_compute_shader(serialized, serialized.length, new ByteLengthGetter().getLenBytes(dataOutFormat), groupsX, groupsY, groupsZ);
	}

	public static function runComputeShaderDynInDeserialize(dataIn:Any, dataOutFormat:Any, groupsX:Int, groupsY:Int, groupsZ:Int):Any
	{
		var serialized = Serializer.serialize(dataIn);
		return new Deserializer().deserialize(Compute.run_compute_shader(serialized, serialized.length, new ByteLengthGetter().getLenBytes(dataOutFormat),
			groupsX, groupsY, groupsZ),
			dataOutFormat);
	}
}

class HexDump
{
	public static function dump(bytes:hl.Bytes, length:Int):Void
	{
		var lineSize = 16;
		var line = "";
		for (i in 0...length)
		{
			if (i % lineSize == 0 && i != 0)
			{
				trace(line);
				line = "";
			}
			line += StringTools.hex(bytes.getUI8(i), 2) + " ";
		}
		if (line.length > 0)
			trace(line);
	}
}

private class Serializer
{
	public static function serialize(object:Any):Bytes
	{
		var output = new BytesOutput();
		writeValue(output, object);
		return output.getBytes();
	}

	static function writeValue(output:BytesOutput, value:Any)
	{
		if (value is Float)
			output.writeFloat(value);
		else if (value is Int)
			output.writeInt32(value);
		else if (value is Bool)
			output.writeInt32(value ? 1 : 0);
		else if (value is Array)
		{
			var arr:Array<Any> = cast value;
			for (v in arr)
				writeValue(output, v);
		}
		else if (value != null && Reflect.fields(value).length > 0)
		{
			var fields = Reflect.fields(value);
			for (field in fields)
				writeValue(output, Reflect.field(value, field));
		}
	}
}

class Deserializer
{
	var pos:Int = 0;

	public function new() {}

	public function deserialize(bytes:hl.Bytes, schema:Any):Any
	{
		pos = 0;
		return readValue(bytes, schema);
	}

	function getSize(schema:Any):Int
	{
		if (schema is Int || schema is Float || schema is Bool)
		{
			return 4;
		}
		else if (schema is Array)
		{
			var arr:Array<Any> = cast schema;
			if (arr.length == 0)
				return 0;
			var elemSize = getSize(arr[0]);
			var elemAlign = getAlignment(arr[0]);
			var stride = alignUp(elemSize, elemAlign);
			return stride * arr.length;
		}
		else if (schema != null && Reflect.fields(schema).length > 0)
		{
			var size = 0;
			var maxAlign = getAlignment(schema);
			for (field in Reflect.fields(schema))
			{
				var fieldSchema = Reflect.field(schema, field);
				var align = getAlignment(fieldSchema);
				size = alignUp(size, align);
				size += getSize(fieldSchema);
			}
			size = alignUp(size, maxAlign);
			return size;
		}
		return 4;
	}

	function alignUp(value:Int, align:Int):Int
	{
		var mis = value % align;
		return mis == 0 ? value : value + (align - mis);
	}

	function align(to:Int):Void
	{
		pos = alignUp(pos, to);
	}

	function readValue(bytes:hl.Bytes, schema:Any):Any
	{
		var alignTo = getAlignment(schema);
		align(alignTo);

		if (schema is Int)
		{
			var i = bytes.getI32(pos);
			pos += 4;
			return i;
		}
		else if (schema is Float)
		{
			var f = bytes.getF32(pos);
			pos += 4;
			return f;
		}
		else if (schema is Bool)
		{
			var b = bytes.getI32(pos) != 0;
			pos += 4;
			return b;
		}
		else if (schema is Array)
		{
			var arr:Array<Any> = cast schema;
			var result = [];
			if (arr.length == 0)
				return result;
			var elemSchema = arr[0];
			var elemSize = getSize(elemSchema);
			var elemAlign = getAlignment(elemSchema);
			var stride = alignUp(elemSize, elemAlign);

			var startPos = pos;
			for (i in 0...arr.length)
			{
				pos = startPos + i * stride;
				result.push(readValue(bytes, elemSchema));
			}
			pos = startPos + stride * arr.length;
			return result;
		}
		else if (Reflect.fields(schema).length > 0)
		{
			var obj = {};
			var maxAlign = getAlignment(schema);

			for (field in Reflect.fields(schema))
			{
				var fieldValue = Reflect.field(schema, field);
				var fieldAlign = getAlignment(fieldValue);
				align(fieldAlign);
				Reflect.setField(obj, field, readValue(bytes, fieldValue));
			}
			align(maxAlign);
			return obj;
		}

		return null;
	}

	function getAlignment(schema:Any):Int
	{
		if (schema == null)
			return 4;

		if (schema is Int)
			return 4;
		if (schema is Float)
			return 4;
		if (schema is Bool)
			return 4;

		if (schema is Array)
		{
			var arr:Array<Any> = cast schema;
			return arr.length > 0 ? getAlignment(arr[0]) : 4;
		}

		if (Reflect.fields(schema).length > 0)
		{
			var maxAlign = 1;
			for (field in Reflect.fields(schema))
			{
				var fieldValue = Reflect.field(schema, field);
				var align = getAlignment(fieldValue);
				if (align > maxAlign)
					maxAlign = align;
			}
			return maxAlign;
		}

		return 4;
	}
}

private class ByteLengthGetter
{
	var curAmt:Int = 0;

	public function new() {}

	public function getLenBytes(object:Any):Int
		return _getLenBytes(object);

	function _getLenBytes(value:Any):Int
	{
		if (value is Float)
			curAmt += 4;
		else if (value is Int)
			curAmt += 4;
		else if (value is Bool)
			curAmt += 4;
		else if (value is Array)
		{
			var arr:Array<Any> = cast value;
			for (v in arr)
				_getLenBytes(v);
		}
		else if (value != null && Reflect.fields(value).length > 0)
		{
			var fields = Reflect.fields(value);
			for (field in fields)
				_getLenBytes(Reflect.field(value, field));
		}
		return curAmt;
	}
}
