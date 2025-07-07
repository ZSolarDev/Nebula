package nebula.mesh.savers;

import haxe.Json;
import lime.utils.Log;
import nebula.mesh.datatypes.MeshJson;
import sys.io.File;

class JsonMeshSaver implements MeshSaver
{
	public function new() {}

	public function stringifyMesh(mesh:Mesh):String
	{
		var meshParts:Array<MeshPartJson> = [];
		for (meshPart in mesh.meshParts)
		{
			var vertices:Array<Vec3D> = [];
			for (vertex in meshPart.vertices)
				vertices.push({
					x: vertex.x,
					y: vertex.y,
					z: vertex.z,
					w: vertex.w
				});
			var indices:Array<Int> = [];
			for (index in meshPart.indices)
				indices.push(index);
			var uvt:Array<Float> = [];
			for (uv in meshPart.uvt)
				uvt.push(uv);

			meshParts.push({
				vertices: vertices,
				indices: indices,
				uvt: uvt,
				graphic: meshPart.graphic
			});
		}

		var json:MeshJson = {
			meshParts: meshParts
		};
		return Json.stringify(json, null, '    ');
	}

	public function saveMesh(mesh:Mesh, path:String, ?manageError:Bool = true)
	{
		try
		{
			File.saveContent(path, stringifyMesh(mesh));
		}
		catch (e)
		{
			if (manageError)
				Log.error('Error saving mesh to JSON at path ($path): ${e.message}\n${e.stack.toString()}');
		}
	}
}
