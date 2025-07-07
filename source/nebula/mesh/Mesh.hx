package nebula.mesh;

class Mesh
{
	public var x:Float = 0;
	public var y:Float = 0;
	public var z:Float = 0;
	public var pitch:Float = 0;
	public var yaw:Float = 0;
	public var roll:Float = 0;
	public var scaleX:Float = 1;
	public var scaleY:Float = 1;
	public var scaleZ:Float = 1;
	public var meshParts:Array<MeshPart> = [];

	public function new(x:Float, y:Float, z:Float, meshParts:Array<MeshPart>)
	{
		this.x = x;
		this.y = y;
		this.z = z;
		if (meshParts != null)
			this.meshParts = meshParts;
	}
}
