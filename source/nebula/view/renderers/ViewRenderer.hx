package nebula.view.renderers;

interface ViewRenderer
{
	public var view:N3DView;
	public function update(elapsed:Float):Void;
	public function render():Void;
}
