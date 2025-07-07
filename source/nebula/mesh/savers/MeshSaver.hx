package nebula.mesh.savers;

interface MeshSaver
{
	public function saveMesh(mesh:Mesh, path:String, ?manageError:Bool = true):Void;
}
