package nebula.mesh;

import nebula.mesh.MeshPart;
import openfl.Vector;
import openfl.geom.Vector3D;

typedef ProjectionMesh =
{
	var mesh:MeshPart;
	var meshPos:Vector3D;
	var verts:Vector<Float>;
	var uvt:Vector<Float>;
	var indices:Vector<Int>;
	var camZ:Float;
}
