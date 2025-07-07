package nebula.mesh.loaders;

import haxe.Json;
import lime.utils.Log;
import nebula.mesh.MeshPart;
import nebula.mesh.datatypes.MeshJson;
import nebula.mesh.loaders.MeshLoader.MeshData;
import openfl.Vector;
import openfl.geom.Vector3D;
import sys.io.File;

class JsonMeshLoader implements MeshLoader
{
	public function new() {}

	public function loadMesh(meshData:MeshData, ?manageError:Bool = true):Mesh
	{
		inline function load()
		{
			var data:String = cast meshData;
			var json:MeshJson = cast Json.parse(data);
			var meshParts:Array<MeshPart> = [];
			for (meshPart in json.meshParts)
			{
				var vertices:Vector<Vector3D> = new Vector<Vector3D>();
				for (vertex in meshPart.vertices)
					vertices.push(new Vector3D(vertex.x, vertex.y, vertex.z, vertex.w));
				var indices:Vector<Int> = new Vector<Int>();
				for (index in meshPart.indices)
					indices.push(index);
				var uvt:Vector<Float> = new Vector<Float>();
				for (uv in meshPart.uvt)
					uvt.push(uv);

				meshParts.push(new MeshPart(vertices, indices, uvt, meshPart.graphic));
			}
			return new Mesh(0, 0, 0, meshParts);
		}
		if (!manageError)
			return load();
		else
		{
			try
			{
				return load();
			}
			catch (e)
			{
				Log.error('Error loading mesh from JSON: ${e.message}\n${e.stack.toString()}');
				return null;
			}
		}
	}

	public function loadMeshFromFile(path:String, ?manageError:Bool = true):Mesh
	{
		try
		{
			var res = loadMesh(File.getContent(path), false);
			return res;
		}
		catch (e)
		{
			if (manageError)
				Log.error('Error loading mesh from JSON at path ($path): ${e.message}\n${e.stack.toString()}');
			return null;
		}
	}
}
