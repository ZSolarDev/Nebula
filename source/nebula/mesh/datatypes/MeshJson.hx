package nebula.mesh.datatypes;

typedef Vec3D =
{
	var x:Float;
	var y:Float;
	var z:Float;
	var w:Float;
}

typedef MeshJson =
{
	var meshParts:Array<MeshPartJson>;
}

typedef MeshPartJson =
{
	var vertices:Array<Vec3D>;
	var indices:Array<Int>;
	var uvt:Array<Float>;
	var graphic:String;
}
