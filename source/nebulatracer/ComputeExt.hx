package nebulatracer;

import haxe.io.Bytes;
import nebulatracer.Global.ExtDynamic;
import nebulatracer.native.Compute;

class ComputeExt
{
	public static function buildInput():hl.Bytes
	{
		var numObjects = 3;
		var floatBytes = 4;
		var intBytes = 4;

		var totalBytes = numObjects * (intBytes + 4 * floatBytes) + floatBytes;
		var b = new hl.Bytes(totalBytes);

		var pos = 0;

		for (i in 0...3)
		{
			var id = i + 1;
			var floats = [1 + i * 4.0, 2 + i * 4.0, 3 + i * 4.0, 4 + i * 4.0];

			b.setI32(pos, id);
			pos += 4;

			for (f in floats)
			{
				b.setF32(pos, f);
				pos += 4;
			}
		}

		b.setF32(pos, 20.0);

		return b;
	}

	public static function testCompute()
	{
		Compute.init_vulkan();
		Compute.create_compute_shader("
#version 430

layout(local_size_x = 16, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) buffer InputBuffer {
    uint data[];
};

layout(std430, binding = 1) buffer OutputBuffer {
    float result[];
};

void main() {
    if (gl_GlobalInvocationID.x == 0) {
        result[0] = 70.0;
    }
}

");
		var input = buildInput();
		var output = Compute.run_compute_shader(input, 64, 4, 1, 1, 1);

		trace(output.getF32(0));
	}
}
