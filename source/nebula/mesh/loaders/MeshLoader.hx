package nebula.mesh.loaders;

typedef MeshData = Dynamic;

interface MeshLoader
{
	public function loadMesh(meshData:MeshData, ?manageError:Bool = true):Mesh;
	public function loadMeshFromFile(path:String, ?manageError:Bool = true):Mesh;
}
