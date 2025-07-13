package nebula.mesh;

import flixel.graphics.FlxGraphic;
import lime.utils.Log;
import openfl.Vector;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.geom.Vector3D;
import sys.FileSystem;

class MeshPart
{
	public var vertices:Vector<Vector3D> = new Vector<Vector3D>();
	public var indices:Vector<Int> = new Vector<Int>();
	public var uvt:Vector<Float> = new Vector<Float>();
	public var useColor:Bool = false;
	public var color(default, set):Int = 0xFFFFFFFF;
	public var graphic(default, set):String = '';
	public var raytracingProperties:{reflectiveness:Float, lightness:Float};

	function set_color(val:Int):Int
	{
		this.color = val;
		_graphic = FlxGraphic.fromBitmapData(new BitmapData(1, 1, true, val));
		return val;
	}

	function set_graphic(val:String):String
	{
		this.graphic = val;
		if (!FileSystem.exists(val))
		{
			Log.warn('Failed to load mesh graphic from path: ${val}');
			_graphic = FlxGraphic.fromBitmapData(FlixelIcon.getIcon());
		}
		else
			_graphic = FlxGraphic.fromBitmapData(BitmapData.fromFile(val));

		return val;
	}

	public function toString():String
		return 'MeshPart: vertices: $vertices || indices: $indices || uvt: $uvt || graphic: $graphic';

	public var smooth:Bool = true;
	public var repeat:Bool = true;
	public var blend:BlendMode = BlendMode.NORMAL;

	@:allow(nebula.view.renderers.ViewRenderer)
	private var _graphic:FlxGraphic;

	public function new(vertices:Vector<Vector3D>, indices:Vector<Int>, uvt:Vector<Float>, graphic:String, ?setGraphic:Bool = true)
	{
		this.vertices = vertices;
		this.indices = indices;
		this.uvt = uvt;
		if (setGraphic)
			this.graphic = graphic;
	}
}
