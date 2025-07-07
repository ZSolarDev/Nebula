package nebula.mesh.loaders;

import haxe.io.Path;
import lime.utils.Log;
import nebula.mesh.loaders.MeshLoader.MeshData;
import nebula.mesh.savers.JsonMeshSaver;
import openfl.Vector;
import openfl.geom.Vector3D;
import sys.io.File;

using StringTools;

// TODO: Fix this
class OBJMeshLoader implements MeshLoader
{
	public function new() {}

	public function loadMesh(meshData:MeshData, ?manageError:Bool = true):Mesh
	{
		try
		{
			var objPath:String = cast meshData.objPath;

			//---------Load MTL---------//
			var mtlData:String = cast meshData.mtlData;
			var mtlLines = mtlData.replace('\r', '').split('\n');
			var mtlMaterials:Array<{name:String, texture:String}> = [];
			var curMaterialIdx = -1;

			for (lineID in 0...mtlLines.length)
			{
				var line = mtlLines[lineID].trim();
				if (line == '' || line.charAt(0) == '#')
					continue;
				var parts = line.split(' ');
				switch (parts[0])
				{
					case 'newmtl':
						mtlMaterials.push({name: parts[1], texture: ''});
						curMaterialIdx++;
					case 'map_Kd':
						mtlMaterials[curMaterialIdx].texture = '$objPath/${parts[1]}';
					case unknown:
						Log.warn('Unknown MTL attribute at line ${lineID + 1}: $unknown');
				}
			}
			var matMap:Map<String, {texture:String}> = new Map();
			for (material in mtlMaterials)
				matMap.set(material.name, {texture: material.texture});

			//---------Load OBJ---------//
			var objData:String = cast meshData.objData;
			var objLines = objData.replace('\r', '').split('\n');

			var globalVerts = new Vector<Vector3D>();
			var globalUVs = new Vector<Float>();

			var meshParts:Array<MeshPart> = [];
			var curPart:MeshPart = null;
			var curMaterial:String = '';
			var partFaces:Array<{vi:Int, vti:Int}> = [];

			inline function newPart()
			{
				curPart = new MeshPart(new Vector<Vector3D>(), new Vector<Int>(), new Vector<Float>(), '', false);
				meshParts.push(curPart);
				if (matMap.exists(curMaterial))
					curPart.graphic = matMap.get(curMaterial).texture;
			}

			if (meshParts.length == 0)
				newPart();

			for (lineID in 0...objLines.length)
			{
				var line = objLines[lineID].trim();
				if (line == '' || line.charAt(0) == '#')
					continue;

				var parts = line.split(' ');
				switch (parts[0])
				{
					case 'v':
						globalVerts.push(new Vector3D(Std.parseFloat(parts[1]), Std.parseFloat(parts[2]), Std.parseFloat(parts[3])));
					case 'vt':
						globalUVs.push(Std.parseFloat(parts[1]));
						globalUVs.push(Std.parseFloat(parts[2]));
					case 'vn':
						// Not used yet
					case 'usemtl':
						curMaterial = parts[1];
						newPart();
					case 'o':
						newPart();
					case 'f':
						for (i in 1...parts.length)
						{
							var token = parts[i].split('/');
							var vi = Std.parseInt(token[0]) - 1;
							var vti = (token.length > 1 && token[1] != '') ? Std.parseInt(token[1]) - 1 : -1;
							partFaces.push({vi: vi, vti: vti});
						}
					case unknown:
						Log.warn('Unknown OBJ attribute at line ${lineID + 1}: $unknown');
				}
			}

			//---------Remap---------//
			for (part in meshParts)
			{
				var indexMap:Map<String, Int> = new Map();
				var verts = new Vector<Vector3D>();
				var uvt = new Vector<Float>();
				var indices = new Vector<Int>();

				for (f in partFaces)
				{
					var key = '${f.vi}_${f.vti}';
					if (!indexMap.exists(key))
					{
						var newIndex = verts.length;
						indexMap.set(key, newIndex);
						verts.push(globalVerts[f.vi]);

						if (f.vti >= 0)
						{
							uvt.push(globalUVs[f.vti * 2]);
							uvt.push(globalUVs[f.vti * 2 + 1]);
						}
						else
						{
							uvt.push(0);
							uvt.push(0);
						}
					}
					indices.push(indexMap.get(key));
				}

				part.vertices = verts;
				part.indices = indices;
				part.uvt = uvt;
			}

			var res = new Mesh(0, 0, 0, meshParts);
			// trace(meshParts);
			return res;
		}
		catch (e)
		{
			if (manageError)
				Log.error('Error loading mesh from OBJ: ${e.message}\n${e.stack.toString()}');
			return null;
		}
	}

	public function getMtlFromObj(dir:String, objData:String):String
	{
		var lines = objData.replace('\r', '');
		var finalLines = lines.split('\n');
		for (line in finalLines)
		{
			if (line.startsWith('mtllib'))
			{
				var mtlName = line.split(' ')[1];
				return '$dir/$mtlName';
			}
		}
		return '';
	}

	public function loadMeshFromFile(path:String, ?manageError:Bool = true):Mesh
	{
		try
		{
			var dir = Path.normalize(path.substring(0, path.lastIndexOf("/")));
			var result:Mesh = loadMesh({objPath: dir, objData: File.getContent(path), mtlData: File.getContent(getMtlFromObj(dir, File.getContent(path)))},
				false);
			return result;
		}
		catch (e)
		{
			if (manageError)
				Log.error('Error loading mesh from OBJ at path ($path): ${e.message}\n${e.stack.toString()}');
			return null;
		}
	}
}
